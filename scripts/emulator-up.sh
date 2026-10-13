#!/usr/bin/env bash
# Boot an AVD in the background and block until it reports sys.boot_completed=1.
#
# Usage: scripts/emulator-up.sh [avd-name]
#   avd-name defaults to $AVD_NAME (see env.sh), currently Medium_Phone_API_36.0
set -euo pipefail
source "$(dirname "$0")/env.sh"

avd="${1:-$AVD_NAME}"

if adb devices | grep -q "^emulator-"; then
  echo "An emulator is already running:"
  adb devices -l | grep emulator
  exit 0
fi

echo "Available AVDs: $(emulator -list-avds | tr '\n' ' ')"
echo "Booting $avd ..."
nohup emulator -avd "$avd" -no-snapshot-load > "${TMPDIR:-/tmp}/emulator_boot.log" 2>&1 &
disown

adb wait-for-device
echo "Device visible, waiting for boot to finish..."
for _ in $(seq 1 60); do
  boot="$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
  [ "$boot" = "1" ] && { echo "Boot complete."; break; }
  sleep 5
done
adb devices -l
