#!/usr/bin/env bash
# Unzip an APK's raw contents and print a structural summary (top-level dirs by
# size, file extensions by size/count). Output goes to workdir/<apk-name>/extracted/.
#
# Usage: scripts/extract-apk.sh apks/foo.apk
set -euo pipefail
source "$(dirname "$0")/env.sh"

apk="${1:?usage: extract-apk.sh <path-to.apk>}"
require_file "$apk"

out="$(apk_workdir "$apk")/extracted"
mkdir -p "$out"
echo "Extracting $apk -> $out"
unzip -oq "$apk" -d "$out"

if command -v python >/dev/null 2>&1; then
  python - "$out" <<'PY'
import os, sys, collections
root = sys.argv[1]
top_stats = collections.defaultdict(lambda: [0, 0])
ext_stats = collections.defaultdict(lambda: [0, 0])
total_files = total_size = 0
for dirpath, _, filenames in os.walk(root):
    for f in filenames:
        p = os.path.join(dirpath, f)
        try:
            size = os.path.getsize(p)
        except OSError:
            continue
        total_files += 1
        total_size += size
        rel = os.path.relpath(p, root)
        top = rel.split(os.sep)[0]
        top_stats[top][0] += 1
        top_stats[top][1] += size
        ext = os.path.splitext(f)[1].lower() or "(none)"
        ext_stats[ext][0] += 1
        ext_stats[ext][1] += size

print(f"\nTOTAL: {total_files} files, {total_size/1024/1024:.1f} MB\n")
print("=== Top-level dirs/files by size ===")
for k, (cnt, size) in sorted(top_stats.items(), key=lambda x: -x[1][1])[:25]:
    print(f"{size/1024/1024:8.2f} MB  {cnt:6d} files  {k}")
print("\n=== By extension ===")
for k, (cnt, size) in sorted(ext_stats.items(), key=lambda x: -x[1][1])[:20]:
    print(f"{size/1024/1024:8.2f} MB  {cnt:6d} files  {k}")
PY
else
  echo "(python not found - skipping structural summary; raw files are in $out)"
fi
