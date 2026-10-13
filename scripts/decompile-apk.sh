#!/usr/bin/env bash
# Decompile an APK's DEX bytecode back to readable Java-ish source with jadx.
# Output: workdir/<apk-name>/decompiled/{sources,resources}
#
# Usage: scripts/decompile-apk.sh apks/foo.apk
set -euo pipefail
source "$(dirname "$0")/env.sh"

apk="${1:?usage: decompile-apk.sh <path-to.apk>}"
require_file "$apk"
require_file "$JADX_BIN"

out="$(apk_workdir "$apk")/decompiled"
mkdir -p "$out"
echo "Decompiling $apk -> $out (this can take several minutes for large apps)"
"$JADX_BIN" -d "$out" --show-bad-code -q "$apk"
echo "Done. Browse $out/sources for Java, $out/resources for decoded XML/assets."
