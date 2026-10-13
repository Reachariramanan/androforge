#!/usr/bin/env python3
"""Read-only Android ZIP/APK inventory. Never extracts or executes archive members."""

from __future__ import annotations
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import sys
import zipfile

DEX_RE = re.compile(r"^classes(?:[0-9]+)?\.dex$")
NATIVE_RE = re.compile(r"^lib/([^/]+)/([^/]+\.so)$")
SPLIT_SUFFIXES = {".apks": "apk-set", ".apkm": "apk-set-third-party",
                  ".xapk": "apk-set-third-party", ".aab": "app-bundle"}


def hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def analyze(path: Path) -> dict:
    if not path.is_file():
        raise ValueError(f"Not a file: {path}")
    if not zipfile.is_zipfile(path):
        raise ValueError("Input is not a valid ZIP container (APK is ZIP-based)")

    fmt = SPLIT_SUFFIXES.get(path.suffix.lower(), "apk-or-zip")
    dex: set[str] = set()
    native: set[str] = set()
    abis: set[str] = set()
    payload_apks: list[str] = []
    legacy_signatures: list[str] = []
    counts = Counter()
    warnings: list[str] = []
    seen: set[str] = set()
    total_uncompressed = 0
    total_compressed = 0
    has_manifest = False
    has_resources_arsc = False
    with zipfile.ZipFile(path, "r") as archive:
        entries = archive.infolist()
        for entry in entries:
            name = entry.filename
            if name in seen:
                warnings.append(f"Duplicate ZIP member: {name[:160]}")
            seen.add(name)
            if (name.startswith("/") or "\\" in name or
                any(part == ".." for part in PurePosixPath(name).parts)):
                warnings.append(f"Unsafe ZIP path: {name[:160]}")
            if entry.flag_bits & 0x1:
                warnings.append(f"Encrypted ZIP entry: {name[:160]}")
            if entry.is_dir():
                continue
            total_uncompressed += entry.file_size
            total_compressed += entry.compress_size
            if entry.compress_size > 0 and entry.file_size > 100 * 1024 * 1024 and entry.file_size / entry.compress_size > 500:
                warnings.append(f"High compression ratio: {name[:160]}")
            if name == "AndroidManifest.xml":
                has_manifest = True
            elif name == "resources.arsc":
                has_resources_arsc = True
            if DEX_RE.fullmatch(name):
                dex.add(name)
                counts["dex"] += 1
            elif (match := NATIVE_RE.fullmatch(name)):
                abis.add(match.group(1))
                native.add(name)
                counts["native_libraries"] += 1
            elif name.startswith("res/"):
                counts["resource_files"] += 1
            elif name.startswith("assets/"):
                counts["asset_files"] += 1
            elif name.startswith("META-INF/"):
                counts["meta_inf_files"] += 1
                if name.lower().endswith((".rsa", ".dsa", ".ec", ".sf")):
                    legacy_signatures.append(name)
            elif name.lower().endswith(".apk"):
                payload_apks.append(name)
                counts["embedded_apks"] += 1
            else:
                counts["other_files"] += 1
        total_entries = len(entries)
    if total_uncompressed > 4 * 1024**3:
        warnings.append("Large advertised uncompressed size (>4 GiB); review before extraction")
    if fmt != "apk-or-zip":
        warnings.append("Container is not an ordinary standalone APK; identify constituent APKs first")
    elif not has_manifest:
        warnings.append("No root AndroidManifest.xml: may be a non-APK ZIP or nested container")
    # No META-INF signatures does not establish unsigned status (APK signing block).
    return {
        "schema_version": 1,
        "original_filename": path.name,
        "file_bytes": path.stat().st_size,
        "sha256": hash_file(path),
        "container_kind": fmt,
        "zip_members": total_entries,
        "uncompressed_total_bytes": total_uncompressed,
        "compressed_total_bytes": total_compressed,
        "android_manifest_at_root": has_manifest,
        "resources_arsc_at_root": has_resources_arsc,
        "dex_files": sorted(dex),
        "abi_names": sorted(abis),
        "native_library_files": sorted(native),
        "embedded_apk_names": sorted(payload_apks),
        "legacy_signature_zip_entries": sorted(legacy_signatures),
        "category_counts": dict(sorted(counts.items())),
        "warnings": warnings[:150],
        "warnings_truncated": len(warnings) > 150,
        "notes": [
            "Inventory uses ZIP entries only: no binary AndroidManifest or resources.arsc decode.",
            "ZIP signature entries do not show APK v2/v3/v4 Signing Block status; use apksigner.",
            "An APK/ZIP list alone cannot prove a complete installed split set.",
        ],
    }


def markdown(report: dict) -> str:
    counts = report["category_counts"]
    lines = ["# APK ZIP inventory", "", f"- Original: `{report['original_filename']}`",
             f"- SHA-256: `{report['sha256']}`", f"- Bytes: {report['file_bytes']:,}",
             f"- Container: `{report['container_kind']}`", f"- ZIP members: {report['zip_members']:,}",
             f"- Manifest at root: {report['android_manifest_at_root']}",
             f"- resources.arsc at root: {report['resources_arsc_at_root']}", "",
             "## DEX", "", ", ".join(report["dex_files"]) or "(none)", "",
             "## Native ABI", "", ", ".join(report["abi_names"]) or "(none)", "",
             "## Counts", ""]
    lines.extend(f"- {key}: {value:,}" for key, value in sorted(counts.items()))
    lines += ["", "## Warnings", ""]
    lines.extend(f"- {warning}" for warning in report["warnings"] or ["None detected by inventory checks"])
    lines += ["", "## Limitations", ""]
    lines.extend(f"- {note}" for note in report["notes"])
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("apk", type=Path, help="APK/ZIP-based container to inspect")
    p.add_argument("--json", type=Path, help="Write machine-readable summary")
    p.add_argument("--markdown", type=Path, help="Write Markdown summary")
    args = p.parse_args(argv)
    try:
        report = analyze(args.apk)
    except (ValueError, OSError, zipfile.BadZipFile) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if args.markdown:
        args.markdown.parent.mkdir(parents=True, exist_ok=True)
        args.markdown.write_text(markdown(report), encoding="utf-8")
    if not args.json and not args.markdown:
        print(json.dumps(report, indent=2))
    else:
        print(f"Inventory complete: {report['sha256']} | {report['zip_members']} entries | {len(report['warnings'])} warnings")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
