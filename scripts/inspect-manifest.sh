#!/usr/bin/env bash
# Decode an APK's binary AndroidManifest.xml and dump permissions/components
# via aapt2 (bundletool's `dump manifest` only works on .aab bundles, not a
# plain .apk - see tools/README.md).
# Output: workdir/<apk-name>/manifest_badging.txt and manifest_xmltree.txt
#
# Usage: scripts/inspect-manifest.sh apks/foo.apk
set -euo pipefail
source "$(dirname "$0")/env.sh"

apk="${1:?usage: inspect-manifest.sh <path-to.apk>}"
require_file "$apk"
require_file "$AAPT2_BIN"

out="$(apk_workdir "$apk")"
"$AAPT2_BIN" dump badging "$apk" > "$out/manifest_badging.txt"
"$AAPT2_BIN" dump xmltree "$apk" --file AndroidManifest.xml > "$out/manifest_xmltree.txt"

echo "Wrote:"
echo "  $out/manifest_badging.txt   (package, permissions, sdk versions, abis, locales)"
echo "  $out/manifest_xmltree.txt   (full decoded manifest tree)"
echo
grep -E "^package:|^application-debuggable|^native-code" "$out/manifest_badging.txt" || true
