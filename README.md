# APK Workbench

A local toolbench for pulling an APK apart, reading its code, and instrumenting
it at runtime on an Android emulator. Plain shell scripts over standard CLIs
(adb, java, python, git) - no dependency on any particular AI agent or IDE;
run it by hand or drive it from any tool that can call a shell script.

![Android Forge Workbench](assets/Android%20Forge_Workbench.png)

## AI agent instructions

Repository-wide agent guidance is maintained in [`AGENTS.md`](AGENTS.md). Before
performing a task, agents should inspect [`skills/`](skills/), read the relevant
`SKILL.md`, use [`tools/`](tools/) and [`scripts/`](scripts/) according to that
skill's workflow, and verify results before reporting success. `SKILL.md` is the
authoritative definition for each reusable skill and is intended to remain
portable across AI providers, models, IDEs, and agent APIs.

## Layout

| Path | What it is |
|---|---|
| `apks/` | Raw `.apk` samples under analysis. |
| `tools/` | Third-party analysis tools (binaries/jars) pinned into this project. See `tools/README.md` for what each one does. |
| `scripts/` | The actual workbench actions - thin, parameterized wrappers around the tools. See `scripts/README.md` for usage. |
| `frida/` | Frida instrumentation scripts: `frida/FridaScripts` (cloned reference library) and `frida/custom` (ours). See `frida/README.md`. |
| `workdir/<apk-name>/` | Generated output per APK: extracted files, decoded manifest, decompiled source, patched APKs. Safe to delete and regenerate at any time. |

## Prerequisites

- Android SDK with `platform-tools`, `emulator`, and a `build-tools` version (this project defaults to `36.0.0`) - set `ANDROID_HOME` if it's not at the default `%LOCALAPPDATA%\Android\Sdk`.
- Java 8+ (for jadx/apktool/bundletool).
- Python 3 (optional - only used for the extraction size/extension summary).
- `pip install frida frida-tools objection` for runtime instrumentation.
- An AVD created in Android Studio (or `avdmanager`). Set `AVD_NAME` if it isn't `Medium_Phone_API_36.0`.

All of the above are read from environment variables in `scripts/env.sh`, so nothing here is hardcoded to one machine - override any of `ANDROID_HOME`, `AVD_NAME`, `AAPT2_VERSION` before calling a script if your setup differs.

## Quick start

```sh
# static analysis: unzip, decode the manifest, decompile to Java - all at once
scripts/apk-report.sh apks/your-app.apk

# boot an emulator and install the app
scripts/emulator-up.sh
scripts/install-apk.sh apks/your-app.apk

# runtime instrumentation (see frida/README.md for why gadget-injection is
# needed on a non-rooted Play-image emulator, and how to pick a script)
scripts/frida-patch-apk.sh apks/your-app.apk
scripts/install-apk.sh workdir/your-app/patched/your-app.objection.apk
scripts/frida-trace.sh com.your.package frida/FridaScripts/<some-script>.js
```

Every generated artifact lands under `workdir/<apk-name>/` - nothing is written back into `apks/` or `tools/`.
