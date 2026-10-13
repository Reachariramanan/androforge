#!/usr/bin/env python3
"""Compare two apk_inventory.py JSON reports without reading original APKs."""

from __future__ import annotations
import argparse
import json
from pathlib import Path
import sys

SCALARS = ("container_kind", "android_manifest_at_root", "resources_arsc_at_root",
           "zip_members", "file_bytes", "uncompressed_total_bytes")
SETS = ("dex_files", "abi_names", "native_library_files", "embedded_apk_names")


def compare(old: dict, new: dict) -> dict:
    for label, value in (("old", old), ("new", new)):
        if value.get("schema_version") != 1 or "sha256" not in value:
            raise ValueError(f"{label} is not a supported inventory JSON")
    scalar_changes = {name: {"old": old.get(name), "new": new.get(name)}
                      for name in SCALARS if old.get(name) != new.get(name)}
    for category in sorted(set(old.get("category_counts", {})) | set(new.get("category_counts", {}))):
        a = old.get("category_counts", {}).get(category, 0)
        b = new.get("category_counts", {}).get(category, 0)
        if a != b:
            scalar_changes[f"category_counts.{category}"] = {"old": a, "new": b}
    set_changes = {}
    for name in SETS:
        before, after = set(old.get(name, [])), set(new.get(name, []))
        if before != after:
            set_changes[name] = {"added": sorted(after - before), "removed": sorted(before - after)}
    return {"schema_version": 1, "old_sha256": old["sha256"], "new_sha256": new["sha256"],
            "hash_changed": old["sha256"] != new["sha256"],
            "scalar_changes": scalar_changes, "list_changes": set_changes,
            "notice": "ZIP structure diff only: equal file lists do not imply identical code/behavior."}


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("old_inventory", type=Path)
    p.add_argument("new_inventory", type=Path)
    p.add_argument("--json", type=Path, help="Optional output path for structural diff")
    args = p.parse_args()
    try:
        report = compare(json.loads(args.old_inventory.read_text(encoding="utf-8")),
                         json.loads(args.new_inventory.read_text(encoding="utf-8")))
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    text = json.dumps(report, indent=2) + "\n"
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(text, encoding="utf-8")
        print(f"Saved structural diff to {args.json}")
    else:
        print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
