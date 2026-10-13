# Frida instrumentation

| Path | What it is |
|---|---|
| `FridaScripts/` | Cloned from https://github.com/apkunpacker/FridaScripts - a library of ready-made hook scripts (SSL pinning bypass, anti-debug bypass, DEX/SO dumping, etc). Treat it as a reference library, not something to edit; pull to update. |
| `custom/` | Our own hook scripts, written for a specific app/finding. Empty until we write one. |

## Why gadget injection instead of a normal frida-server

Both AVDs in this project (`Medium_Phone_API_36.0`, `flutter_emulator`) use
**Google Play** system images (`google_apis_playstore`), which are production
builds. `adb root` is refused on them (`adbd cannot run as root in production
builds`), and Instagram's manifest has `android:debuggable` unset (false), so
there's no `run-as` shortcut either.

A standalone `frida-server` needs to `ptrace` into the target app's process,
which on Android requires either root or same-UID access - neither is
available here. The standard workaround, and what `scripts/frida-patch-apk.sh`
automates via `objection patchapk`, is to:

1. Decode the APK with `apktool`.
2. Drop `libfrida-gadget.so` into `lib/<abi>/` and add a `System.loadLibrary`
   call early in app startup (smali patch).
3. Repack and re-sign the APK with a debug key.

The gadget then runs **in-process** as part of the app itself, so no
cross-process ptrace/root is needed - `frida -U -f <package> -l script.js`
attaches to it like a normal frida-server target.

If you later create a non-Play AVD (`google_apis` or AOSP, not
`google_apis_playstore`), those images are `userdebug` builds and support
`adb root` + a normal `frida-server` push - no gadget patching needed. That's
the faster path when Play Services isn't required by the app under test.

## Picking a script

See `FridaScripts/README.md` for the full table. The ones most relevant to a
typical release APK like Instagram:

| Script | Use it for |
|---|---|
| `FridaScripts/SSLUnpinning.js` | Get past certificate pinning to see plaintext HTTPS traffic in a proxy (Burp/mitmproxy). |
| `FridaScripts/AntiDebug.js` | Bypass root/Frida/VPN/debugger detection that would otherwise crash or block the app once it notices instrumentation. |
| `FridaScripts/Logcat.js` | Capture all logging calls the app makes at runtime. |
| `FridaScripts/DumpDex.js` / `DumpSo.js` | Pull dynamically-loaded/decrypted code out of memory if the app unpacks itself at runtime. |
| `FridaScripts/EarlyJava.js` | Hook classes that get loaded before Frida normally attaches. |

Run via `scripts/frida-trace.sh <package> <path-to-script.js>` once the
gadget-patched APK is installed and launched.
