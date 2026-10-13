# Identify APK container types and split installations before decoding

## Contents
1. Container taxonomy
2. Safe ZIP inventory
3. Package and manifest metadata
4. Split APK constraints
5. Evidence checklist

## 1. Not all `.apk`-looking files are a base APK

- `.apk`: ordinary Android package container with compiled manifest/resources, one or more `classes*.dex` (possibly absent in native/resource-only splits), libs and assets.
- `.apks`: often a bundletool-generated APK set archive containing a manifest and constituent `.apk` entries; enumerate first and choose relevant splits for the target device.
- `.apkm` and `.xapk`: third-party packaging containers; file layout/metadata vary. Do not assume one contained APK is independently installable.
- `.aab`: Android App Bundle, not a standalone installable APK. Use Google's bundletool or official build tools to generate appropriate APKs where authorized.
- `.jar`, `.dex`, `.odex`, `.vdex`: related artifacts with distinct layouts; inspect type before passing to Apktool.

Do not assert that decoding only a `base.apk` yields all code/resources when config splits, dynamic feature modules or additional native libraries are involved. The installed app may combine feature code and resources across splits.

## 2. Safe inventory before extraction

Use `python scripts/apk_inventory.py file.apk --json report.json --markdown report.md`. It reads the ZIP central directory and hashes the original file, **without extracting archive members**. Treat zip-slip names (`../`, absolute paths), duplicates, surprisingly high compression ratios and enormous advertised uncompressed sizes as red flags for manual handling. Never blindly extract an untrusted archive into a valuable directory.

For a normal base APK expect `AndroidManifest.xml`, `resources.arsc` in many but not all APKs, `classes.dex` or higher numbered DEX as appropriate, `res/`, `assets/`, `lib/<abi>/*.so`, and `META-INF/` legacy signature entries in some signing schemes. **Absence of `META-INF/*.RSA` does not prove unsigned**: modern APK signature schemes live in the APK Signing Block, outside the ZIP entry list. Use `apksigner verify --verbose --print-certs` to inspect signatures if Build Tools are present. Do not treat signature inspection as permission to modify.

## 3. Obtain metadata with Android tools

Raw manifest XML inside a ZIP is commonly in binary AXML form and cannot be read with a normal text editor. Decode with Apktool or use official SDK tools:

```bash
apkanalyzer manifest print input.apk
# or, if supported by installed SDK:
aapt2 dump badging input.apk
apksigner verify --verbose --print-certs input.apk
```

A failed manifest decode can result from malformed or unsupported compiled resources; avoid guessing the package/version from archive filename. Read installed tool help before assuming every tool supports a particular output flag.

## 4. Split-specific research questions

Document which split contributes: `base` manifest and DEX, ABI-specific native code, language densities, dynamic feature code and resources. Library names across ABIs may differ. When a requested class isn't in a base APK, search the other authorized splits before concluding it is absent. For on-device behavior, record the installed split list rather than pretending a single APK is complete.

Never instruct an APK-set extraction to a single untrusted directory without zip safety checks. For install workflows, use supported `adb install-multiple`/bundletool methods with matched version/signers/required splits; avoid automatically uninstalling the app to overcome split/signing issues.

## 5. Baseline record

```text
File path / SHA-256 / bytes: ...
Container classification and signatures: ...
Is this a complete app delivery artifact? yes / no / unknown
Base/config/dynamic splits: ...
Package/version: verified from manifest / not available
DEX and ABI sets: ...
Tools and versions: ...
Archive safety warnings: ...
What cannot be inferred from this file alone: ...
```
