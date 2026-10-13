#!/usr/bin/env bash
# One-shot: run extract + manifest inspection + decompile for an APK and leave
# everything under workdir/<apk-name>/. This is the "give me everything about
# this APK" entry point; run the individual scripts directly for just one step.
#
# Usage: scripts/apk-report.sh apks/foo.apk
set -euo pipefail
here="$(dirname "$0")"

apk="${1:?usage: apk-report.sh <path-to.apk>}"

echo "== 1/3 extract =="
"$here/extract-apk.sh" "$apk"
echo
echo "== 2/3 manifest =="
"$here/inspect-manifest.sh" "$apk"
echo
echo "== 3/3 decompile =="
"$here/decompile-apk.sh" "$apk"
