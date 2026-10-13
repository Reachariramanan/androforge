#!/usr/bin/env bash
# Install (or reinstall) an APK onto whichever device/emulator adb currently sees.
#
# Usage: scripts/install-apk.sh apks/foo.apk
set -euo pipefail
source "$(dirname "$0")/env.sh"

apk="${1:?usage: install-apk.sh <path-to.apk>}"
require_file "$apk"

adb install -r "$apk"
