#!/usr/bin/env bash
# Inject a frida-gadget into an APK so it can be instrumented WITHOUT root.
#
# Why this is needed here: the project's AVDs use "Google Play" system images
# (google_apis_playstore), which are production builds - `adb root` is refused
# on them, so a normal frida-server (which needs root to ptrace another app's
# process) cannot attach to a release APK. The standard workaround is to embed
# frida's gadget shared library directly into the APK and have it auto-start
# in-process; objection automates the apktool decode -> smali patch -> repack
# -> sign steps. See frida/README.md for the full explanation.
#
# Usage: scripts/frida-patch-apk.sh apks/foo.apk [arch]
#   arch: gadget architecture to embed, defaults to the APK's own native ABI
#         (auto-detected from lib/<abi> in the extracted tree; falls back to arm64).
# Output: workdir/<apk-name>/patched/<name>.objection.apk
set -euo pipefail
source "$(dirname "$0")/env.sh"

apk="${1:?usage: frida-patch-apk.sh <path-to.apk> [arch]}"
require_file "$apk"
command -v objection >/dev/null 2>&1 || { echo "error: objection not installed (pip install objection)" >&2; exit 1; }
command -v apktool >/dev/null 2>&1 || { echo "error: apktool wrapper not on PATH - check tools/apktool" >&2; exit 1; }

out="$(apk_workdir "$apk")/patched"
mkdir -p "$out"
cp "$apk" "$out/"
local_apk="$out/$(basename "$apk")"

echo "Patching $local_apk with frida-gadget via objection (this rebuilds+resigns the APK)..."
( cd "$out" && objection patchapk --source "$(basename "$local_apk")" )

echo "Done. Patched APK: $out/$(basename "${local_apk%.apk}").objection.apk"
echo "Install it with: scripts/install-apk.sh <that path>"
echo "Then launch the app once, and objection/frida will find the gadget waiting to attach."
