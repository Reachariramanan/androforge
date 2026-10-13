# Scripts

Every script is POSIX `bash`, takes an APK path (or package name) as its
first argument, and writes generated output under `../workdir/<apk-name>/`.
None of them assume a particular caller - run them from a terminal, a CI job,
or any agent that can execute a shell command.

`env.sh` is not a script you run - every other script starts with
`source "$(dirname "$0")/env.sh"`, which resolves the workbench root, sets
`ANDROID_HOME`/`AVD_NAME`/tool paths (overridable via env vars), and puts
`platform-tools`, `emulator`, `tools/jadx/bin`, and `tools/apktool` on `PATH`.

| Script | Purpose |
|---|---|
| `extract-apk.sh <apk>` | Unzip the APK's raw contents and print a size/extension breakdown. Output: `workdir/<name>/extracted/`. |
| `inspect-manifest.sh <apk>` | Decode the binary manifest via `aapt2` - permissions, components, target/min SDK, native ABIs, locales. Output: `workdir/<name>/manifest_badging.txt`, `manifest_xmltree.txt`. |
| `decompile-apk.sh <apk>` | Decompile DEX to Java source via `jadx`. Output: `workdir/<name>/decompiled/{sources,resources}`. |
| `apk-report.sh <apk>` | Runs the three static-analysis scripts above in sequence - the "just tell me everything" entry point. |
| `emulator-up.sh [avd]` | Boot an AVD in the background and block until `sys.boot_completed=1`. No-ops if a device is already attached. |
| `install-apk.sh <apk>` | `adb install -r` wrapper. |
| `frida-patch-apk.sh <apk>` | Inject a frida-gadget into the APK via `objection patchapk` so it can be instrumented without root (needed on this project's Google Play emulator images - see `../frida/README.md`). Output: `workdir/<name>/patched/*.objection.apk`. |
| `frida-trace.sh <package> <script.js>` | Attach frida to a launched, gadget-patched app and run a `.js` hook script against it (e.g. from `frida/FridaScripts`). |

## Typical flows

**Just want to read the code:**
```sh
scripts/apk-report.sh apks/foo.apk
# then browse workdir/foo/decompiled/sources
```

**Want to instrument it at runtime:**
```sh
scripts/emulator-up.sh
scripts/frida-patch-apk.sh apks/foo.apk
scripts/install-apk.sh workdir/foo/patched/foo.objection.apk
# launch the app on the emulator, then:
scripts/frida-trace.sh com.foo.app frida/FridaScripts/<script>.js
```
