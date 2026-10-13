# Tools

Third-party analysis tools pinned into this project so results are
reproducible. Each is a plain jar/binary invoked by a script in `../scripts/`
- nothing here is specific to any AI agent.

| Tool | Version | What it does | Invoked by | Source |
|---|---|---|---|---|
| `jadx/` | 1.5.6 | Decompiles DEX bytecode back into readable Java source (plus decoded XML resources). This is how you read "what code is actually in the APK." | `scripts/decompile-apk.sh` | https://github.com/skylot/jadx |
| `apktool/apktool.jar` (+ `apktool` wrapper script) | 3.0.3 | Decodes an APK to smali + resources and rebuilds it. Used indirectly: `objection patchapk` shells out to `apktool` on `PATH` to inject the frida-gadget native library and repack/sign the APK. | `objection` (via `scripts/frida-patch-apk.sh`) | https://github.com/iBotPeaches/Apktool |
| `bundletool.jar` | 1.18.3 | Google's official tool for `.aab` App Bundles (building APK sets, extracting device-specific APKs, dumping manifest/resources). **Only works on `.aab` bundles, not plain `.apk` files** - its `dump manifest --bundle` refuses `--apk`. Kept here for when an `.aab` shows up; for a standalone `.apk` use `aapt2` instead (below). | not currently wrapped by a script - run directly: `java -jar tools/bundletool.jar <cmd>` | https://github.com/google/bundletool |

## Tools used from the Android SDK (not vendored here)

These come from your `ANDROID_HOME` install and are referenced by path in `scripts/env.sh`:

| Tool | What it does |
|---|---|
| `platform-tools/adb` | Device/emulator control: install APKs, shell access, screenshots, logcat. |
| `emulator/emulator` | Boots an AVD. |
| `build-tools/<ver>/aapt2` | Decodes a **plain APK's** binary `AndroidManifest.xml` and dumps permissions/components/native ABIs/locales (`dump badging`, `dump xmltree`). This is the correct tool for `.apk` manifest inspection - use it instead of bundletool. |

## Python-installed tools (not vendored here)

Installed via `pip install frida frida-tools objection` - see `frida/README.md` for why and how they're used together.
