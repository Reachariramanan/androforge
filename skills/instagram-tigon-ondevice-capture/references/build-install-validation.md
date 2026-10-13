# Build, sign, install and device validation runbook

**Scope:** Authorized test builds of an Instagram APK with a version-ported direct-Smali Tigon capture hook. This documents the tools/commands successfully used in the source session and the extra release checks that were missing there. Use current paths and keep the original APK intact.

## 1. Workbench layout and preflight

Recommended:

```text
android-workbench/
  original/instagram-<version>.apk
  workdir/<version>/
    decoded/                      apktool editable source
    original-smali-backup/        pristine changed methods/classes
    build/
      unsigned.apk
      aligned.apk
      signed.apk
    reports/
      discovery.json
      port.md
      logcat.txt
      manifest.json
    exported-captures/           only safe test data, not in public repos
```

Check available tooling:

```bash
java -version
adb version
apktool --version                 # or java -jar /path/to/apktool.jar --version
zipalign -h
apksigner --version
adb devices -l
```

Record `java -version`, apktool version, build-tools path, platform-tools path, OS/API/ABI and original APK SHA-256. Verify available host memory; apktool can require substantial heap with Instagram's multiple dex files.

### Clean baseline

Install/test the **unmodified** source APK or a known-functional control build on a *separate test profile/device* where possible. Record feed/media performance. Don't confuse the original-signed APK with a newly signed APK when attributing crashes. Have a recovery plan for package-signature incompatibility.

### Windows Git Bash example (paths are placeholders)

```bash
WB="/c/path/to/android-workbench"
BT="/c/Users/USER/AppData/Local/Android/Sdk/build-tools/36.0.0"
PT="/c/Users/USER/AppData/Local/Android/Sdk/platform-tools"
APK="$WB/original/instagram-VERSION.apk"
DEC="$WB/workdir/VERSION/decoded"
OUT="$WB/workdir/VERSION/build"
SERIAL="YOUR_DEVICE_SERIAL"
mkdir -p "$OUT"
"$PT/adb.exe" devices -l
```

PATH changes applied with `[Environment]::SetEnvironmentVariable(..., "User")` in PowerShell require new terminal sessions, and non-interactive Git Bash may not source `~/.bashrc`. Explicit paths can be more predictable.

**MSYS2 path conversion trap:** in the 448 environment, `adb.exe` converted a device path like `/sdcard/Download/...` into a Windows host path. Passing `//sdcard/Download/...` avoided this. This is a **Windows/Git Bash compatibility quirk**, not a rule for Linux/macOS or PowerShell. For robust automation, consider `MSYS_NO_PATHCONV=1` or shell-specific escaping and verify manually.

## 2. Decode and start a local patch history

```bash
sha256sum "$APK" > "$OUT/original.sha256"
java -jar "$WB/tools/apktool/apktool.jar" d -f "$APK" -o "$DEC"
python scripts/scan_tigon.py --decoded "$DEC" \
  --json "$WB/workdir/VERSION/reports/discovery.json" \
  --markdown "$WB/workdir/VERSION/reports/discovery.md"
```

Use `git init` inside a local source-only checkout and commit the pristine `decoded/` before editing, or make a selective secure copy of every `.smali` file to be changed. Exclude keystores, raw capture bodies, signing passwords and personal data with `.gitignore`. Check `git diff` after each individual callback patch, not only once at the end.

If the APK is split, identify base/config splits first and use split-aware installation; never assume the single base APK is sufficient. If apktool hits resources decoding errors, inspect its version and choose an appropriate decode mode, then test a rebuild **without** functional changes to ensure a baseline round-trip.

## 3. Compile in small stages

```bash
java -jar "$WB/tools/apktool/apktool.jar" b "$DEC" -o "$OUT/unsigned.apk" \
  > "$OUT/build.log" 2>&1

tail -60 "$OUT/build.log"
unzip -t "$OUT/unsigned.apk" | tail -5
```

Build failures can be deterministic (`Register v16 out of range`, duplicate label, unknown class/method, resource compile error) or environmental (memory exhaustion, silently truncated archive). **Never** skip checking the exit code and ZIP integrity. Do not repeatedly change source when the host is simply out of memory; free RAM, validate the output and rerun after reviewing logs. The source session found apktool incremental Smali recompilation (only changed dex directories) useful to reduce rebuild cost.

Stage builds:

1. clean decoded original (round-trip control);
2. new helper class only (load/link control);
3. metadata lifecycle callbacks;
4. `onBody` byte capture only;
5. optional file/media processing;
6. concurrency/privacy improvement.

When any stage breaks the UI, revert just that stage and test again.

## 4. Align, sign and verify

Do not embed keystore passwords in scripts, Markdown or command-line history. Create and store a **test keystore** securely, or use a keystore already controlled by the authorized tester. A signer changes the APK certificate; that change can affect installation, Android signature permissions, native/Play integrity checks and app login.

```bash
"$BT/zipalign.exe" -f -p 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"
"$BT/zipalign.exe" -c -v 4 "$OUT/aligned.apk"

# Separate command: use secure interactive passphrase handling.
"$BT/apksigner.bat" sign \
    --ks /secure/path/to/test-key.jks \
    --out "$OUT/signed.apk" "$OUT/aligned.apk"

"$BT/apksigner.bat" verify --verbose --print-certs "$OUT/signed.apk"
unzip -t "$OUT/signed.apk" | tail -5
```

On Linux/macOS, use `zipalign` and `apksigner` without `.exe`/`.bat`. Use a signing configuration compatible with target Android API and any split-package scenario.

## 5. Install without data loss surprises

```bash
"$PT/adb.exe" -s "$SERIAL" devices -l
"$PT/adb.exe" -s "$SERIAL" shell getprop ro.build.version.sdk
"$PT/adb.exe" -s "$SERIAL" shell getprop ro.product.cpu.abi
"$PT/adb.exe" -s "$SERIAL" install -r "$OUT/signed.apk"
```

**Verify `Success`.** Some 448 installs printed `Unknown command: install-incremental` first, then used a streamed install successfully. `INSTALL_FAILED_UPDATE_INCOMPATIBLE` means signing mismatch: don't automatically uninstall and destroy account/app data. Back up and ask the user to approve a clean test-device uninstall/profile reset, or use a separate test environment. If split APKs are required, use `adb install-multiple` appropriately.

Launch using the package's current launcher activity (may change across versions):

```bash
"$PT/adb.exe" -s "$SERIAL" shell monkey -p com.instagram.android 1
# Historical 448 also supported explicit:
"$PT/adb.exe" -s "$SERIAL" shell am start -n com.instagram.android/.activity.MainTabActivity
```

An installed process or `pidof` response proves only that the process runs, not that login/feed/network behavior is correct.

## 6. Verify app function and capture behavior together

### Crash and resource monitoring

```bash
"$PT/adb.exe" -s "$SERIAL" shell pidof com.instagram.android
"$PT/adb.exe" -s "$SERIAL" logcat -c
# Generate representative authorized test traffic; later:
"$PT/adb.exe" -s "$SERIAL" logcat -d -v threadtime \
    > "$OUT/logcat-after-test.txt"
"$PT/adb.exe" -s "$SERIAL" shell dumpsys meminfo com.instagram.android
"$PT/adb.exe" -s "$SERIAL" shell dumpsys activity anr
```

Some command options differ by Android version. Do not include sensitive logcat chunks or unredacted network lines in reports. Monitor threads with `/proc/<pid>/task` only if permissions allow; `run-as` works only when allowed by Android debuggable/uid policy. Consider `adb shell top` and `dumpsys meminfo` otherwise.

### Functional manual matrix

A tester must actually confirm *each* of these with capture OFF **and** ON: app launch, login/test account, home feed loads, pull to refresh, photos visible, videos/playback, reels, profile navigation, basic post, requests completed, no repeated ANR/crash, normal background/foreground resume. In the 448 experiment the file/thread checks passed and the user then found an empty feed—this check is not optional.

### Verify saved bytes

For the historical public Download format:

```bash
# Use //sdcard only for the specific Git Bash MSYS path-conversion environment.
"$PT/adb.exe" -s "$SERIAL" shell ls -l //sdcard/Download/InstagramCaptures/
"$PT/adb.exe" -s "$SERIAL" pull //sdcard/Download/InstagramCaptures \
   "$OUT/exported-captures"
python scripts/analyze_capture.py \
  --root "$OUT/exported-captures/InstagramCaptures" \
  --manifest "$OUT/capture-manifest.json" \
  --endpoint-stats --strict
```

For app-private storage on newer Android, provide an explicit in-app export (SAF/share), or use an authorized debug/profile export mechanism; do not turn on general device-wide storage access just to retain a capture folder. Avoid ever deleting old files until after the user approves and backups exist.

The validator checks the JSONL structure, declared body file lengths, SHA-256 and known media signatures, without dumping contents. It is only a **file-evidence** check. Follow it with app functional testing, and do not claim “complete HTTP capture” from file presence alone.

## 7. Rollback/recovery

Keep a manifest of before/after paths, hashes and original class blocks. If APK verifier errors, feed/media regression, increasing memory, unexpected sensitive data, or new crash/ANR appears:

1. Stop or disable capture using an explicit safe control. Do not clear files before backup.
2. Revert the *latest* callback/worker change from original Smali, not blindly replace a whole dex.
3. Rebuild, sign, install and retest the baseline/capture OFF.
4. Identify which exact instruction changed runtime behavior (e.g. `.locals`/`p0` alias, blocking file I/O, callback signature mismatch).
5. Record failure evidence and report **not working** until a new build passes the entire functional matrix.

If signature mismatch makes reverting impossible without app-data loss, explain the situation before any uninstall/reset.

## 8. Deliverable record

For each build record: input SHA, version and ABI, discovery output, changed paths and diff, helper fingerprints, run commands/exit codes, aligned/signed APK SHA, signer certificate fingerprint, ADB install outcome, test account privacy mode, capture counts, malformed count, valid body/file/asset checks, app UI results OFF/ON, crashes/ANRs, dropped bytes and remaining limitations. Redact identifiable device serial and credentials in any public-facing report.
