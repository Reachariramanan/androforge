#!/usr/bin/env bash
# Attach frida to a running (gadget-patched) app and run a script from
# frida/FridaScripts or frida/custom against it.
#
# Usage: scripts/frida-trace.sh com.instagram.android frida/FridaScripts/AndroidBypassAll/android-ssl-pinning-bypass.js
#   (see frida/README.md for how to find script paths in the cloned repo)
set -euo pipefail
source "$(dirname "$0")/env.sh"

package="${1:?usage: frida-trace.sh <package.name> <path/to/script.js>}"
script="${2:?usage: frida-trace.sh <package.name> <path/to/script.js>}"
require_file "$script"

echo "Attaching frida to $package with $script"
echo "(app must already be launched on the device/emulator with the gadget loaded)"
frida -U -l "$script" -f "$package" --no-pause
