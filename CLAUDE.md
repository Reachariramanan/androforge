# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A local **APK Workbench** for authorized Android app analysis: pull an APK apart statically, read its decompiled code, and instrument it at runtime on an emulator. It is plain POSIX `bash` over standard CLIs (`adb`, `java`, `python`, `objection`, `frida`) — no build system, no package manifest, no test suite. "Working on the code" here means editing the shell scripts in `scripts/` or writing Frida hooks in `frida/custom/`.

Intended for authorized use only: APKs/devices you own or are explicitly permitted to assess, intentionally vulnerable training apps, CTFs, coursework, and local emulators with synthetic data. See `README.md` and the per-directory READMEs for the full scope statement. The IIT Madras references describe the author's academic context only and imply no institutional authorization.

## Common commands

All scripts take an APK path (or package name) as `$1` and write output under `workdir/<apk-name>/`. Run them from the repo root.

```sh
# Full static analysis (extract + manifest + decompile) in one shot
scripts/apk-report.sh apks/foo.apk

# Individual static steps
scripts/extract-apk.sh apks/foo.apk      # unzip + size/extension summary -> workdir/foo/extracted/
scripts/inspect-manifest.sh apks/foo.apk # aapt2 badging + xmltree -> workdir/foo/manifest_*.txt
scripts/decompile-apk.sh apks/foo.apk    # jadx -> workdir/foo/decompiled/{sources,resources}

# Runtime instrumentation flow (non-rooted Play-image emulator)
scripts/emulator-up.sh [avd-name]                               # boot AVD, block until sys.boot_completed=1
scripts/frida-patch-apk.sh apks/foo.apk [arch]                 # objection patchapk -> workdir/foo/patched/foo.objection.apk
scripts/install-apk.sh workdir/foo/patched/foo.objection.apk   # adb install -r
scripts/frida-trace.sh com.foo.app frida/FridaScripts/<script>.js  # frida -U -f <pkg> -l <script> --no-pause
```

There are no tests or linters. Validate a script change by running it against a sample APK in `apks/` and checking the regenerated `workdir/` output.

## Architecture

**Three-layer design, decoupled on purpose** (so any shell-capable caller — terminal, CI, or an AI agent — can drive it):

1. `scripts/` — thin, parameterized wrappers. Each is the unit of work.
2. `tools/` — vendored, version-pinned third-party binaries/jars (jadx, apktool, bundletool) for reproducibility.
3. `workdir/<apk-name>/` — all generated output. Never written back into `apks/` or `tools/`; safe to delete and regenerate.

**`scripts/env.sh` is the backbone.** It is sourced (not executed) by every script via `source "$(dirname "$0")/env.sh"`. It resolves `WB_ROOT` regardless of caller cwd, sets overridable config (`ANDROID_HOME`, `AVD_NAME`, `AAPT2_VERSION`), puts `platform-tools`/`emulator`/`jadx`/`apktool` on `PATH`, and exposes the shared helpers `apk_slug`, `apk_workdir` (derives the per-APK slug and mkdirs it), and `require_file`. When adding a script, follow this same pattern: source env.sh, use `apk_workdir` for output paths, use `require_file` for preconditions, and keep all config overridable via environment variables rather than hardcoding.

**Tool selection gotcha (`.apk` vs `.aab`):** use `aapt2` (from the SDK) for plain-APK manifest inspection. `bundletool.jar` only works on `.aab` App Bundles and refuses `.apk` — it is kept for when a bundle appears, not for routine use.

**Why gadget injection, not frida-server:** the project's AVDs use Google Play (`google_apis_playstore`) system images, which are production builds — `adb root` is refused, so a normal `frida-server` cannot ptrace into a release app. `frida-patch-apk.sh` works around this by having `objection patchapk` embed `libfrida-gadget.so` in-process (apktool decode → smali patch → repack → re-sign with a debug key). This changes and re-signs the APK; only patch copies you are permitted to modify. A non-Play (`google_apis`/AOSP) `userdebug` AVD would support `adb root` + a pushed frida-server and skip patching entirely. Full rationale in `frida/README.md`.

## Conventions

- Every script starts with `#!/usr/bin/env bash` and `set -euo pipefail`, a comment block documenting purpose + `Usage:`, and uses `${1:?usage: ...}` for required args.
- `frida/FridaScripts/` is a cloned reference library (from apkunpacker/FridaScripts) — treat it as read-only and `git pull` to update; write project-specific hooks in `frida/custom/`.
- Generated `workdir/` contents may include app code, manifests, and logs — treat as potentially sensitive and do not commit.
