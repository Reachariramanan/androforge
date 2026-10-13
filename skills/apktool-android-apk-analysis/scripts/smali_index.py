#!/usr/bin/env python3
"""Bounded, evidence-oriented discovery of classes, methods and Smali xrefs.

Searches use case-insensitive substrings for discovery. Follow candidates manually
and distinguish a textual match from proven control flow or runtime execution.
"""

from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import re
import sys

CLASS_RE = re.compile(r"L[^;\s]+;")


def smali_paths(root: Path):
    for basedir, dirs, files in os.walk(root):
        dirs.sort()
        for filename in sorted(files):
            if filename.endswith(".smali"):
                yield Path(basedir) / filename


def scan(root: Path, *, class_substr: str | None = None,
         method_substr: str | None = None, invoke_substr: str | None = None,
         type_ref: str | None = None, limit: int = 100) -> dict:
    if not root.is_dir():
        raise ValueError(f"Not a Smali decoded directory: {root}")
    if limit < 1 or limit > 10000:
        raise ValueError("limit must be between 1 and 10000")
    queries = {"class": class_substr, "method": method_substr,
               "invoke": invoke_substr, "type-ref": type_ref}
    active = {name: value.casefold() for name, value in queries.items() if value}
    hits: list[dict] = []
    totals = {"smali_files": 0, "declared_classes": 0, "declared_methods": 0,
              "matches": 0, "unreadable_files": 0}

    for path in smali_paths(root):
        totals["smali_files"] += 1
        owner = "(unknown class)"
        method = "(outside method)"
        try:
            with path.open("r", encoding="utf-8", errors="replace") as stream:
                for lineno, line in enumerate(stream, 1):
                    stripped = line.strip()
                    lowered = stripped.casefold()
                    kind = ""
                    if stripped.startswith(".class "):
                        totals["declared_classes"] += 1
                        descriptor = CLASS_RE.search(stripped)
                        owner = descriptor.group(0) if descriptor else "(unparsed class)"
                        method = "(outside method)"
                        if "class" in active and active["class"] in lowered:
                            kind = "class"
                    elif stripped.startswith(".method "):
                        totals["declared_methods"] += 1
                        method = stripped
                        if "method" in active and active["method"] in lowered:
                            kind = "method"
                    elif stripped.startswith(".end method"):
                        method = "(outside method)"
                    elif stripped.startswith("invoke-"):
                        if "invoke" in active and active["invoke"] in lowered:
                            kind = "invoke"
                    if not kind and "type-ref" in active and active["type-ref"] in lowered:
                        # Literal match; includes declarations and fields, not just method callers.
                        kind = "type-ref"
                    if kind:
                        totals["matches"] += 1
                        if len(hits) < limit:
                            hits.append({"kind": kind, "file": str(path.relative_to(root)).replace(os.sep, "/"),
                                         "line": lineno, "owner": owner, "method_context": method[:280],
                                         "text": stripped[:400]})
        except (OSError, UnicodeError):
            totals["unreadable_files"] += 1
    return {"schema_version": 1, "root": str(root), "queries": queries,
            "totals": totals, "hits_shown": len(hits),
            "truncated": totals["matches"] > len(hits), "hits": hits,
            "notice": "Static textual cross-reference only; not runtime execution evidence."}


def markdown(report: dict) -> str:
    totals = report["totals"]
    lines = ["# Smali search report", "", f"- Root: `{report['root']}`",
             f"- Files: {totals['smali_files']:,}; classes: {totals['declared_classes']:,}; methods: {totals['declared_methods']:,}",
             f"- Matching lines: {totals['matches']:,}; shown: {report['hits_shown']:,}; truncated: {report['truncated']}",
             "", "## Queries", ""]
    lines.extend(f"- {name}: `{value}`" for name, value in report["queries"].items() if value)
    lines += ["", "## Hits", ""]
    if not report["hits"]:
        lines.append("No matches in supplied scope.")
    for hit in report["hits"]:
        # Escape vertical bar and backtick to avoid breaking plain markdown output.
        value = hit["text"].replace("`", "'").replace("|", "\\|")
        lines += [f"- **{hit['kind']}** `{hit['file']}:{hit['line']}` — `{value}`",
                  f"  - Owner: `{hit['owner']}`; method: `{hit['method_context'][:140].replace('`', chr(39))}`"]
    lines += ["", report["notice"], ""]
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("decoded_dir", type=Path)
    p.add_argument("--class-substr")
    p.add_argument("--method-substr")
    p.add_argument("--invoke-substr")
    p.add_argument("--type-ref")
    p.add_argument("--limit", type=int, default=100)
    p.add_argument("--json", type=Path)
    p.add_argument("--markdown", type=Path)
    args = p.parse_args(argv)
    try:
        report = scan(args.decoded_dir, class_substr=args.class_substr,
                      method_substr=args.method_substr, invoke_substr=args.invoke_substr,
                      type_ref=args.type_ref, limit=args.limit)
    except (ValueError, OSError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if args.markdown:
        args.markdown.parent.mkdir(parents=True, exist_ok=True)
        args.markdown.write_text(markdown(report), encoding="utf-8")
    if not args.json and not args.markdown:
        print(markdown(report))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
