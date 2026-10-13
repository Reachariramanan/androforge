# Optional rebuild/sign branch and common failures

## Contents
1. Before touching bytecode
2. Rebuild and sign sequence
3. Android install/signature/split limitations
4. Error matrix
5. Rollback and evidence

## 1. Keep a checkpoint and separate analysis from changes

Read-only decode requires **no signing or device installation**. When the user explicitly requests a modification to an authorized APK, copy the decoded baseline to a versioned patch workspace, initialize Git locally, commit the untouched decoded output (where practical), and record every changed Smali/XML/resource file. Require a tiny change and one baseline smoke test before complex hooks. Inspect control flow, register aliases, labels, exception handlers, argument and return descriptors. Do not patch a production or unrelated app without authorization.

## 2. Tool-assisted build workflow

```bash
apktool b decoded/app -o build/unsigned.apk
# Android SDK build-tools: prefer a version supporting 16 KiB alignment when appropriate
zipalign -P 16 -f -v 4 build/unsigned.apk build/aligned.apk
zipalign -c -P 16 -v 4 build/aligned.apk
apksigner sign --ks /path/to/test-only-keystore.jks \
  --out build/signed.apk build/aligned.apk
apksigner verify --verbose --print-certs build/signed.apk
```

Use the installed `zipalign --help` to confirm `-P 16` support; on older tools where this option is missing, use the appropriate SDK version (and carefully document fallback). `zipalign` **precedes** `apksigner`. Changes after signing invalidate the signature. Prefer your own test keystore; don't request or share production signing keys. If using a freshly generated test keystore, protect it locally and never bundle it into a skill or report.

Official Android references: https://developer.android.com/tools/zipalign and https://developer.android.com/tools/apksigner . For most modern SDK workflows use `apksigner` rather than ad-hoc JAR signing.

## 3. Installation limitations

A rebuild signed by a different key is **not** a valid in-place update to an already-installed package signed by its original developer. If Android reports `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, stop and explain the difference. Uninstalling often deletes app data and may impact active accounts or backups: obtain explicit authorization before any uninstall/clear-data. Multi-split installations may require all compatible splits with matching package/signatures; a rebuilt base APK by itself may fail. Integrity/self-consistency mechanisms might reject altered APKs; do not attempt to silently bypass them.

For a dedicated test device only:

```bash
adb devices -l
adb install -r build/signed.apk
adb shell am force-stop com.example.ownedapp
# Launch through UI, or with a verified main activity on a lab device.
```

Use `adb logcat` with limited non-sensitive filters and never print or share tokens/account IDs from app logs.

## 4. Failure diagnosis

| Symptom | Likely interpretation and resolution |
|---|---|
| Apktool resource decode fails | Unsupported resource chunks/API/tool version, missing OEM framework; update tool, use correct framework, document code-only fallback |
| Apktool build says invalid register | Recompute `.locals` / `.registers`, `p` alias offsets and specific invoke register encoding; refactor rather than increase blindly |
| `aapt2` errors | Malformed decoded XML/resources or unsupported build-tool resources; compare pristine decode/build baseline |
| `Class not found` after install | Wrong multi-dex location, class descriptor/package typo, incomplete splits, DEX failure |
| Device rejects signature | Wrong key/lineage, original installed package, insufficient splits; report, don't uninstall automatically |
| App launches but feature fails | Hook changed control flow, type, exception handling, startup order or native interaction; revert incremental changes |
| Crash in callback | Return/param corruption, reentrancy, `ByteBuffer` consumption, concurrency or IO on main/native callback thread |
| Static report says code present but no runtime effect | Feature gate, dead code, wrong process or callback; runtime observation needed |

## 5. Rollback and evidence

Keep `original.apk`, `decoded-baseline` and all diffs. For a Smali patch use `git diff --check`, inspect the unified diff, and prove new Smali compiles before attempting installation. Compare modified and original behavior on the same controlled test inputs and record both results. Revert by restoring original decoded files or reinstalling an **authorized and properly signed** baseline with informed handling of data/signature constraints.
