---
name: instagram-tigon-ondevice-capture
description: >-
  Reproduce and version-port the specific authorized Instagram APK modification demonstrated on 448.0.0.18.84: direct Smali instrumentation of Meta Tigon's per-request callbacks to record on-device request metadata, response metadata, decrypted response ByteBuffer bytes, JSON bodies, and media segments without Frida, a proxy, or a CA certificate. Use for reverse engineering, adapting, debugging, rebuilding, signing, and evidence-based validating this local-only network capture modification on a new Instagram APK version. Distinguish proven response capture from unimplemented request-body interception and require app stability, privacy controls, and test-account authorization.
---

# Instagram Tigon On-Device Capture — Version-Adaptive Port

## Mission and boundaries

Implement **one specific transformation** on an Instagram Android APK that the user is authorized to modify for testing: capture selected Tigon network lifecycle data and, where supported, the actual decrypted response bytes **inside the app process** and retain them locally. Do **not** assume old obfuscated names survive a version upgrade. Do **not** represent the original experiment as an entirely completed, stable, full-duplex recorder.

For every new APK version, aim for (a) unmodified app functionality; (b) metadata capture; (c) verified, read-only response body capture; (d) optional safe media retention; (e) accurate completeness/privacy reports. Treat outgoing request bodies as a **separate, currently unproven extension** unless newly implemented and tested.

Operate only on a provided/authorized APK, a personal or consented test device and a test account. Do not add remote collection, stealth behavior, credential harvesting, account access bypass, anti-detection features, or silent uploads. Do not include secrets, session cookies, raw account identifiers, or confidential bodies in generated reports. Prefer app-private files and explicit user-controlled export; do not create broad world-readable logs. A signed rebuild may be incompatible with the original app's signing identity, app integrity services, or installation requirements.

## Source-of-truth status

The provided Oct 2026 JSONL case study concerned Instagram **448.0.0.18.84**, using apktool **3.0.3**, jadx **1.5.6**, Android SDK build-tools **36.0.0**, an **Android 10 arm64 physical device**, and a Git Bash/Windows workbench.

| Milestone | Evidence / status |
|---|---|
| Original `TigonObservable` lifecycle hooks | **Validated** metadata, HTTP status and headers; body callbacks not seen |
| `LX/02gB` (extends `TigonCallbacks`) `onBody(ByteBuffer)` hook | **Validated** actual response JSON in a saved `.bin` file |
| Downloaded images | **Validated** one stored JPEG as a real 240×426 JPEG |
| Videos | **Validated** genuine fMP4 `moof` fragments; **not** complete playable videos |
| JSON race repair | **Validated** improvement from 3 malformed / 66 to 0 malformed / 54 lines in a later run |
| Asset-name fix | **Validated** `<sha256>.<ext>` output rather than `numeric-id/ext` directory |
| Replacing per-chunk OS threads | **Validated** thread count plateau; fixed pool still has unbounded queue and ordering risk |
| Final `.locals 6` → `.locals 8` crash fix | **Built, signed, installed**; full UI/feed recovery **not verified** after install |
| Outgoing request-body bytes | **Not achieved**; likely future hook at `TigonXplatBodyStream`, correlation unresolved |
| Full media reassembly, safe recording UI toggle, trustworthy completeness states | **Not implemented/validated** in the export |

Read [references/session-reconstruction.md](references/session-reconstruction.md) for the precise chronology, exact commands and verified measurements. Read [references/historical-448-code-edits.md](references/historical-448-code-edits.md) for the original Smali edits, including the register bug and fix. Reference files are **historical examples**, not patches guaranteed safe on a new APK.

## Inputs, outputs, acceptance

Require or discover:

1. An original Instagram APK or complete base/config split set, plus version, version code, package ID and ABI. If input is an `.apks` archive or AAB, handle the actual format with compatible tooling rather than feeding it to apktool as a base APK.
2. An authorized Android test device (Android/API level, ABI, package-install constraints), available JDK, apktool, Android SDK `adb`, `zipalign`, `apksigner` (optional jadx).
3. A privacy-conscious test account and an agreed recording scope (metadata only, redacted API JSON, or explicitly enabled sensitive raw-body retention). Prefer a private on-device capture folder.
4. An immutable baseline backup and a known-working original-install test whenever practical.

Produce a version-specific patch manifest: APK SHA-256, discovered class names and method descriptors, original/new Smali diffs, helper classes, build/signer facts, smoke-test evidence, counts of metadata/body/media captures, explicit blockers, rollback instructions, and a sanitized on-device/off-device capture report. Do not claim success until **functionality and saved-byte evidence** both pass.

## Primary workflow (perform in order)

### 0. Create an isolated worktree

- Copy the untouched APK and compute SHA-256.
- Use a new folder for each version/build attempt: `workdir/<version>/decoded`, `build/`, `logs/`, `reports/`.
- Decode with `apktool d -f --no-res -o decoded original.apk` if appropriate for fast Smali-only work; if manifest/resources or full rebuild needs resource decoding, use the full decode and verify resulting build. `--no-res` is not universally suitable for rebuilding every APK; do not force it.
- Preserve the exact original method bodies of all to-be-edited files and record a diff. Use Git locally even if the original 448 workbench lacked it.

### 1. Discover behavior, not old filenames

Run:

```bash
python scripts/scan_tigon.py --decoded /path/to/decoded \
  --json /path/to/reports/tigon-discovery.json \
  --markdown /path/to/reports/tigon-discovery.md
```

Inspect the output and [references/version-porting.md](references/version-porting.md). Locate:

- `Lcom/facebook/tigon/TigonCallbacks;` (or its renamed equivalent), class hierarchy, implementers, `onBody(Ljava/nio/ByteBuffer;)V` and lifecycle callbacks.
- Where the concrete per-request callback is constructed and passed through `TigonServiceLayer.makeTigonCallbacks(...)` or equivalent into `TigonXplatService.sendRequest(...)`.
- The request type (`TigonRequest`), response type/status/header fields (historically `LX/00MW`), error type and callback signatures.
- Optional debug observer (`TigonObservable`) and `TigonXplatBodyStream` for future outgoing upload work.

**Stop and report uncertainty** if the canonical callback is absent, method semantics are changed, or only guessed call sites are available. Re-evaluate jadx and call graph, then test one metadata hook first. Never claim a class by a coincidental name alone.

### 2. Patch only the minimal required behavior

Perform **separate checkpointed increments**:

1. Add a capture-engine/helper class copied and adapted from [assets/historical-smali/](assets/historical-smali/) only as a **non-production starting reference**. Verify every method, register, directory, and class descriptor. Harden executor, privacy and storage before use (see [references/hardening.md](references/hardening.md)). Never blindly copy the 448 reference wholesale.
2. Hook the current concrete per-request callback `onStarted`, `onResponse`, `onEOM`, `onError`, and confirm these hooks yield correlated metadata.
3. Hook `onBody(ByteBuffer)` using a **duplicate** of the incoming buffer, never consuming the original. Copy minimally in the callback; schedule bounded, ordered background writing. Install only after buffer safety and register audit.
4. Write decoded body files incrementally, with a limited preview (JSON only when safe), correct request-response association, MIME, byte count, SHA-256 and segment status. Store raw bodies only when the agreed privacy mode permits it.
5. Evaluate outgoing request interception at the `TigonBodyStream.transferBytes(...)` family **as a future independent experiment**; prove source, correlation, full length, and absence of original-stream mutation before saying it works.

Keep the app's own callback logic intact. Wrap optional logger calls in a narrow catch that avoids changing return/exception behavior, but do not hide app regressions behind `catch Throwable`. Preserve exception handlers and existing control flow. Do not reuse the historical `LX/02gB`, `LX/00MW`, `LX/05Ue` identifiers without rediscovery.

### 3. Audit register allocation and hot-path safety

Run, at minimum:

```bash
python scripts/audit_smali.py --file /path/to/current/callback.smali --method onBody --strict
python scripts/audit_smali.py --file /path/to/current/TigonCapture.smali
```

Manually inspect any finding, plus each inserted invoke. `.locals L` in an **instance** method places `p0` at physical `vL`; `p1` is `vL+1`. In the 448 experiment `.locals 6` and `move-result-object v6` overwrote `p0`, breaking feed/media; moving to `.locals 8` stopped this exact alias. Wide `J`/`D` params consume two slots; short-form invoke operands must be in v0–v15. See [references/hardening.md](references/hardening.md).

### 4. Build, align, sign and install

Read [references/build-install-validation.md](references/build-install-validation.md). Use current SDK paths, a **test-only keystore you control**, and the exact order:

```bash
java -jar /path/to/apktool.jar b /path/to/decoded -o /path/to/build/unsigned.apk
zipalign -f -p 4 /path/to/build/unsigned.apk /path/to/build/aligned.apk
apksigner sign --ks /path/to/keystore.jks --out /path/to/build/signed.apk /path/to/build/aligned.apk
apksigner verify --verbose /path/to/build/signed.apk
adb -s YOUR_DEVICE_SERIAL install -r /path/to/build/signed.apk
```

A freshly re-signed APK cannot normally upgrade an installation signed by another certificate. Obtain informed user approval before uninstalling (which may delete app data). On Git Bash with Windows `adb.exe`, use `//sdcard/...` paths if MSYS rewrites `/sdcard/...` unexpectedly; this is **tool-environment-specific**, not a general ADB requirement.

### 5. Validate actual app and actual saved bytes

Do not equate install/build success, background file creation, or thread plateau with functioning Instagram. Test login/session validity, feed refresh, posts, images, videos, reels, navigation, network requests, cancellation/retry, and UI responsiveness. Capture `logcat` Java crashes, native crashes, ANRs and resource stats. Repeat with **capture disabled** to separate instrumentation regressions from base-APK/environment regressions.

Pull private/exported captures only with authorization. Analyze locally:

```bash
python scripts/analyze_capture.py --root /path/to/exported/InstagramCaptures \
  --manifest /path/to/reports/manifest.json --strict
```

Compare exact on-disk payload bytes, record lengths, SHA-256 and media magic. Check JSON parsing. Treat `moof` as a **video fragment**, not a whole MP4. Distinguish `observed callback never fired` from `native layer blocks everything`. See [references/evidence-and-tests.md](references/evidence-and-tests.md).

### 6. Gate, release or roll back

A release-ready iteration requires all: valid APK signature, predictable install, normal feed/media/UI for a representative test, no crashes/ANRs added versus baseline, sustained bounded resource usage, valid JSONL, matching payload SHA/size, correct response correlation, zero accidental sensitive exports, and clear coverage limits. If the app fails any gate, **revert the latest patch or disable recording** and present the diagnostic evidence. Do not ship a broken build as successful.

## Resource map

- **Version-port instructions:** [references/version-porting.md](references/version-porting.md). Read for every newly supplied Instagram version.
- **Actual history, commands, failures and successful milestones:** [references/session-reconstruction.md](references/session-reconstruction.md). Read when reproducing the 448 procedure or diagnosing familiar regressions.
- **Exact past Smali edits:** [references/historical-448-code-edits.md](references/historical-448-code-edits.md). Read only when comparing injection snippets.
- **Build and device instructions:** [references/build-install-validation.md](references/build-install-validation.md). Read when preparing or testing an APK.
- **Concurrency/privacy/Smali hardening:** [references/hardening.md](references/hardening.md). Read **before any production-like capture**.
- **Verification and reporting:** [references/evidence-and-tests.md](references/evidence-and-tests.md). Read when evaluating capture accuracy and stability.
- **Recovered experimental helpers:** `assets/historical-smali/TigonCapture.smali`, `TigonBodyWorker.smali`, `TigonWriteWorker.smali`; useful provenance, **known not final production quality**.
- **Reusable commands:** `scripts/scan_tigon.py`, `audit_smali.py`, `analyze_capture.py`, `reconstruct_history.py` (optional original-session replay). Scripts must be run/tested, not assumed correct on unseen versions.

## Explain results precisely

Always communicate separately: **observed**, **implemented but not verified**, **not implemented**, and **failed/rolled back**. Especially do not claim the October 12 final `instagram_bugfix_signed.apk` had a proven working UI after installation: the session ends before the user re-tested it. A new AI can make this implementation work on another version only by discovering and validating that version's actual callback architecture, not by blindly replaying an obfuscated 448 patch.
