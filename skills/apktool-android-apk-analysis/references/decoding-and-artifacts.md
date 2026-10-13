# Decode workflow and how to read Apktool output

## Contents
1. Immutable workspace
2. Decoding modes
3. File tree tour
4. Manifest deep dive
5. Resources and native libraries
6. JADX cross-check and uncertainty

## 1. Workspace discipline

Use a separate directory per APK version:

```text
project/
  originals/<version>/app.apk           # immutable copy
  decoded/<version>/                    # apktool output
  jadx/<version>/                       # optional readable pseudocode
  reports/<version>/                    # inventory, method map, notes
  diffs/                                # optional patches
```

Calculate SHA-256 before modifying anything; preserve a pristine original and a decoded baseline. Never decode with `-f` over a folder containing custom edits unless a versioned backup exists. Keep tool output logs and exact arguments.

## 2. Practical decode commands

```bash
apktool d input.apk -o decoded/app
# If rerunning after saving/recreating the baseline directory:
apktool d -f input.apk -o decoded/app
# For help and current flags:
apktool d --help
apktool --help
```

Some versions offer flags to skip decoding source or resource files, or disassemble additional dex entries; check the installed version's help instead of hardcoding options. **Code-only decode** can aid triage of a problematic resource table but is incomplete for UI, manifest/resource reasoning. For framework-dependent resources, a matching OEM framework APK may need to be installed via an official Apktool `if`/framework flow if one is authorized and available; record the framework hash/version and use a dedicated framework cache to avoid cross-project contamination.

## 3. Top-level decoded file meaning

| Path | Interpretation and caveats |
|---|---|
| `apktool.yml` | Decode/build metadata, SDK fields, original info as determined by Apktool |
| `AndroidManifest.xml` | Decoded manifest; application components, intent filters and security declarations |
| `smali/` | Disassembled classes from primary classes.dex |
| `smali_classes2/`, `smali_classes3/`, ... | Additional DEX partitions, not unique Java package namespaces |
| `res/` | Decoded resource types/layouts/strings/styles/drawables, qualifier directories |
| `assets/` | Raw developer assets that may include JSON/config/JS/binary files; inspect only in scope |
| `lib/<abi>/` | Prebuilt native `.so` libraries; Java decompilation doesn't reveal their code |
| `unknown/`, `original/` | Apktool-managed uninterpreted/original metadata/artifacts depending on version/settings |
| `META-INF/` | ZIP legacy signing metadata, not a complete description of APK Signing Block schemes |

Not every APK has every folder, and some apps have dynamic features, packed DEX or code generated/loaded at runtime that a static decode cannot reveal.

## 4. Manifest walk-through

Read `manifest` element: package and version where present. Check `uses-sdk` (minSdk, targetSdk), `uses-permission`, `uses-feature`, application name/label/icon, `android:debuggable`, `android:usesCleartextTraffic`, `android:networkSecurityConfig` references. Enumerate activity/activity-alias, service, receiver and provider elements, `android:exported`, `android:permission`, authorities, process affinity and intent filters (MAIN/LAUNCHER, BROWSABLE/deep links).

Do not interpret `exported=true` alone as an exploitable vulnerability; evaluate required permissions/intent filters and runtime checks under an authorized security audit. `networkSecurityConfig` is declarative policy, not proof of actual TLS traffic or a patch target.

Trace manifest `android:name=".MyApplication"` to Smali `L<package>/MyApplication;`, account for fully-qualified names and obfuscation. Trace resource refs like `@xml/network_security_config` to `res/xml/network_security_config.xml` and `@string/app_name` to appropriate `res/values-*/strings.xml` overlays.

## 5. Resource semantics

- Qualifier suffixes (`-v31`, `-night`, `-land`, language, density) affect runtime selection; multiple XML files may implement different variants of a screen.
- `R$id`, integer IDs and `resources.arsc` refer to resource table entries; IDs may shift between builds. Prefer names plus contextual call sites, not numeric IDs alone.
- XML layouts can locate view IDs/listeners but Compose UI may use generated classes and limited layout XML. Search navigation graphs and manifest/activity code before assuming all screens are XML-driven.
- Java/Kotlin annotations and debug symbols may be removed; decompiled source is frequently less exact than bytecode.

## 6. JADX pairing

```bash
jadx -d jadx/app input.apk
# Or use JADX GUI on the original APK.
```

Use JADX for high-level control flow, references and string/resource navigation, then verify the key `invoke-*`, return paths, exception handlers, signatures and register instructions in Smali. Decompilation may invent variable names, reconstruct loops differently, collapse synthetic/bridge methods or fail for optimized/obfuscated code. Report contradictions rather than silently choosing the more readable representation.
