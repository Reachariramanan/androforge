#!/usr/bin/env bash
# Shared environment for all workbench scripts. Source this, don't execute it:
#   source "$(dirname "$0")/env.sh"
#
# Every path can be overridden by exporting the same variable before calling
# a script, e.g.  ANDROID_HOME=/opt/android-sdk scripts/emulator-up.sh
set -euo pipefail

# Root of the workbench (parent of this scripts/ dir), resolved regardless of caller's cwd.
WB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

: "${ANDROID_HOME:=$HOME/AppData/Local/Android/Sdk}"
: "${AVD_NAME:=Medium_Phone_API_36.0}"
: "${AAPT2_VERSION:=36.0.0}"

APKS_DIR="$WB_ROOT/apks"
TOOLS_DIR="$WB_ROOT/tools"
WORKDIR="$WB_ROOT/workdir"
FRIDA_DIR="$WB_ROOT/frida"

JADX_BIN="$TOOLS_DIR/jadx/bin/jadx"
APKTOOL_JAR="$TOOLS_DIR/apktool/apktool.jar"
BUNDLETOOL_JAR="$TOOLS_DIR/bundletool.jar"
AAPT2_BIN="$ANDROID_HOME/build-tools/$AAPT2_VERSION/aapt2"

export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
export PATH="$PATH:$HOME/AppData/Roaming/Python/Python313/Scripts"
export PATH="$PATH:$TOOLS_DIR/apktool:$TOOLS_DIR/jadx/bin"
export PATH="$PATH:$ANDROID_HOME/build-tools/$AAPT2_VERSION"

# Derive a stable workdir slug from an APK's filename (strip .apk, keep the rest as-is).
apk_slug() {
  local apk="$1"
  basename "$apk" .apk
}

# Ensure the per-APK workdir subfolders exist and print the base path.
apk_workdir() {
  local slug
  slug="$(apk_slug "$1")"
  mkdir -p "$WORKDIR/$slug"
  echo "$WORKDIR/$slug"
}

require_file() {
  if [ ! -e "$1" ]; then
    echo "error: required file not found: $1" >&2
    echo "  (see tools/README.md to fetch missing tools)" >&2
    exit 1
  fi
}
