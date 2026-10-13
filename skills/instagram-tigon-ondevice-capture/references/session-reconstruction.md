# Source-session reconstruction: 448.0.0.18.84 direct Tigon capture

This document is the **human-readable event-by-event reconstruction** from the user-provided 36 MB / 4,798-line JSONL session export, covering September 19 to October 12, 2026 (timestamps shown in UTC where available). It differentiates demonstrated results, failed experiments, recorded edits, and unverified last-stage work. Do not treat past assistant interpretations as runtime evidence unless matching commands/output support them.

## Contents

1. Initial scope and workbench
2. Early paths later abandoned
3. TigonObservable recorder: first genuine success
4. Debug body callbacks: negative result
5. Helper-engine implementation and race repairs
6. Per-request callback discovery: crucial breakthrough
7. Assets, throughput and media verification
8. Regression and final one-line change
9. What actually worked vs remains incomplete
10. Reproduction commands and code references
11. Environment pitfalls and troubleshooting

## 1. Initial scope and environment

**User's stated Oct 12 target:** Modify their authorized Instagram test APK so that the installed app writes method/URL/headers/status plus actual outgoing/incoming body bytes where feasible, to local Android storage while the phone operates without a computer, desktop proxy, VPN, CA or Frida. Prefer an on/off button or indicator, safe file rotation, and local redaction of credentials. Keep app feed/media working.

Observed project configuration:

```text
Windows host + Git Bash + PowerShell
  workbench/
    apks/instagram-448-0-0-18-84.apk          original downloaded APK
    tools/apktool/apktool.jar                 apktool 3.0.3
    tools/jadx/                                jadx 1.5.6
    scripts/                                   workbench helpers
    research/Reqable_Android_HTTPS_Inspection_Complete_Guide.md
    workdir/instagram-448.0.0.18.84/
      extracted/                               APK archive-unpacked contents
      apktool_decoded/                         editable Smali source used for builds
      reqable_patched/                         output directory (historical name only)
        debug-test.jks                          local test signing keystore; NOT bundled here
        instagram_*_signed.apk                 multiple dated experiments
```

The raw APK unzip was reported at approximately **241 MB, 17,486 files**. A non-rootable x86_64 API 36 Google Play emulator repeatedly suffered severe low-RAM pressure and ANRs even with an unmodified Instagram build. A **physical Android 10/API 29 arm64 test phone** was used for most meaningful verification. This matters: a frozen emulator was *not* evidence that the Smali patch was broken, while a user-reported broken feed on the physical device *was* a regression.

The original workbench **was not a Git repository**; reconstructed instructions recommend version control and clean rollback.

## 2. Routes attempted and then abandoned

### September: extraction, JADX and workbench preparation

The session started with Android SDK/emulator setup, unpacking the archive, decompiling Smali/resources, and adding shell wrappers (`extract-apk.sh`, `decompile-apk.sh`, `apk-report.sh`, `install-apk.sh`, `emulator-up.sh`, `env.sh`). The user also explored Frida scripts and DexSploitX as potential research tools. Some old workbench helpers are stale; they are not relied on by this skill.

### October 10: Reqable HTTPS MITM

A patched `AndroidManifest.xml` set `android:debuggable="true"` to trigger debug trust settings in `fb_network_security_config.xml`, allowing Reqable to observe selected Instagram traffic using an installed CA/proxy on an emulator. This was **not the final requested design**. The user explicitly required CA-free, proxy-free capture in the APK itself, so that path was abandoned. The modified manifest/network-config could potentially still exist in older worktrees: a new port must inspect and remove unnecessary debug trust changes before any release-like artifact. Do **not** describe the original shipped test build as definitely free of leftover manifest changes without inspecting its final APK.

### October 12: Frida Gadget inside a re-signed APK

The prior assistant had edited `InstagramAppShell.smali`, added a `GadgetLoaderRunnable.smali`, copied Frida `.so`/configuration files into native assets and built a JavaScript logger/REC overlay. Loading the library into the process was observable, but the Frida runtime/JS script did not start: no `gum-js-loop` threads, no functional service. The cause (potential anti-instrumentation defenses) was **suspected, not proven**. The approach was removed: gadget libraries, loader and altered app constructor were reversed. The Frida JS overlay remained dead code and the **record button was not reimplemented** in the direct-Smali build.

## 3. Oct 12: first genuine on-device lifecycle capture

The assistant created the raw-Smali helper `smali_classes3/com/instagram/app/TigonCapture.smali` and injected static calls into **six** JNI-facing methods of `smali/com/facebook/tigon/tigonobserver/TigonObservable.smali`:

| Hook | Recorded purpose | Runtime observation |
|---|---|---|
| `onStarted(TigonObserverData)` | Extract numeric requestId, `submittedRequest()`, method/URL/headers | Fired |
| `onResponse(TigonObserverData)` | Extract status and response headers | Fired |
| `onEOM(TigonObserverData)` | Finish record | Fired |
| `onError(TigonObserverData)` | Record failure | Fired |
| `onDownloadBody(TigonBodyObservation)` | Attempt body bytes from native observer | No invocations observed |
| `onUploadBody(TigonBodyObservation)` | Attempt outgoing bytes from native observer | No invocations observed |

All inserts were guarded so exceptions in the instrumentation would not intentionally break the existing callback body. Apktool rebuilt successfully, the APK was aligned, signed and installed on the physical device. After Wi-Fi/login and permissions were confirmed, the session collected approximately **892 KB** in `Download/InstagramCaptures/traffic.jsonl`. A run reported:

- **182 requests** in parseable JSONL and **77 distinct endpoint URLs**.
- **141** with response status/headers, according to the user's summary.
- Correct method/URL/status and redacted headers (including sensitive header keys).
- **Zero actual request/response payload bytes**.

This was a real **metadata capture success**, not HTTPS body capture.

## 4. Oct 12: native observer body flags — hypothesis did not hold

After confirming the body callbacks were silent, the assistant examined the two known `TigonObservable` constructor invocations:

```smali
# Historical first call site: IGTigonService.smali
move v7, v4             # prior false literal
move v8, v4             # prior false literal
# changed to
const/4 v7, 0x1
const/4 v8, 0x1
```

```smali
# Historical second call site: TigonServiceLayer.smali
# prior true/false values sourced from other registers
# changed to explicit 1 immediately before the constructor:
const/4 v5, 0x1
const/4 v6, 0x1
invoke-direct/range {v3 .. v9}, Lcom/facebook/tigon/tigonobserver/TigonObservable;-><init>(...)V
```

The team initially theorized that these booleans enabled native body-observation callbacks. Despite rebuilding, and later adding diagnostic `Log.i`, there were **no observed upload/download callback invocations** on the user's test requests. The only sound conclusion is **this observer route did not deliver body bytes in the tested APK/run**. It does **not** establish that all native/network approaches are blocked or explain precisely why JNI did not call those methods. The skill therefore prioritizes the regular `TigonCallbacks` path instead of toggling debug-observer options again.

## 5. Oct 12: the capture helper grew into a file writer

`TigonCapture.smali` was expanded well beyond original JSONL metadata into these Java-compatible Smali entry points:

```smali
onStarted(JLjava/lang/String;Ljava/lang/String;Ljava/util/Map;)V
onResponse(JILjava/util/Map;)V
onBody(JZLjava/nio/ByteBuffer;Z)V
onEOM(J)V
onError(JLjava/lang/String;)V
```

New helper files were written in the same dex/Smali folder:

```text
TigonBodyWorker.smali      implements Runnable; calls processBody(id, upload, byte[])
TigonWriteWorker.smali     implements Runnable; calls writeAndRemove(id)
TigonCapture.smali         maps, JSONL, body files, SHA-256, MIME, assets
```

Key path fields used inside `TigonCapture`:

```text
/storage/emulated/0/Download/InstagramCaptures/
  traffic.jsonl
  requests/<id>/request_body.bin
  responses/<id>/response_body.bin
  assets/images/<sha256>.<ext>
  assets/videos/<sha256>.<ext>
  assets/audio/<sha256>.<ext>
```

A `DISABLED` marker file at the root was designed to pause recording. **It was not a visible in-app REC/OFF button**, and exact runtime toggle behavior was not thoroughly verified. The planned `manifest.json` and reliable HTTP completeness calculation were not built on-device; this new skill provides a separate off-device manifest generator.

### ByteBuffer handling

The public `onBody` copied bytes from a **duplicate** of the passed ByteBuffer to avoid altering Instagram's original buffer position; the immutable `byte[]` was then passed to a background worker. Helpers wrote chunks incrementally, produced short previews, counted bytes and later computed SHA-256. This was architecturally safer than doing heavy string decode/file I/O synchronously inside a native callback. However, body handling in the historical engine still has queue, lifecycle, lock and privacy gaps; it is not a final hardened implementation.

### Actual problems fixed while developing the engine

1. **Register encoding overflow.** A `.locals 16` finalization method needed parameter registers in short-form calls above v15; apktool rejected the output. The assistant refactored the oversized method into `appendBodyFields` and `appendResponseExtras`, reducing register pressure. Takeaway: keep complex Smali methods small and calculate full physical registers after changing locals.
2. **Wrong boolean/object register.** One intermediate `keyFor` call accidentally used an object reference where a boolean was expected; patched before final build.
3. **Racy JSON mutation.** With background finalization, `onStarted`/`onResponse` and `writeAndRemove` mutated the same `StringBuilder` concurrently. A check reported **3 malformed JSON records in 66**. The assistant added synchronized regions (`monitor-enter`/`monitor-exit`) around shared JSON mutations; next run reported **0 malformed in 54**. Later tests also reported zero corruption. This was a real correctness fix, though lock scope needed further refinement.
4. **Heavy global lock.** The final historical `writeAndRemove` called `appendResponseExtras` while holding `sPending` monitor. That helper can hash/copy large media files, potentially blocking unrelated callbacks. The session **did not** implement the proposed fix of moving expensive work outside the global lock. Treat as a release blocker.

## 6. Oct 12: per-request `TigonCallbacks` — breakthrough

A later GraphQL/response investigation traced the *mandatory* request path through `TigonXplatService.sendRequest(TigonRequest, TigonBodyProvider, TigonCallbacks, Executor)`. That required a per-request `TigonCallbacks` instance, unlike the optional debug observer.

The concrete override class in the historical APK was `smali_classes2/X/02gB.smali` (`LX/02gB;`). It was constructed by `TigonServiceLayer.makeTigonCallbacks(...)` and implemented:

```smali
onStarted(Lcom/facebook/tigon/iface/TigonRequest;)V
onResponse(LX/00MW;)V
onBody(Ljava/nio/ByteBuffer;)V
onEOM(LX/00PO;)V
onError(Lcom/facebook/tigon/TigonError;LX/00PO;)V
```

The assistant injected calls to `TigonCapture` in these five methods, with a long correlation key created from `System.identityHashCode(p0)` (historically adequate to link observed events, **not** guaranteed globally unique). The `onBody` injection used a duplicate buffer and the engine's response-path flag. Original callback logic then continued.

This produced **real in-process response bytes**, verified by an on-device pull and inspection:

- `responses/<numeric-id>/response_body.bin` was **694 bytes** and parsed as complete JSON for `/api/v1/feed/reels_tray/`.
- A capture run contained **41 JSONL lines**, **28** with method/URL, **8** with actual response body files and **zero malformed lines**.
- A subsequent run reported **15 actual response bodies**, including tens-of-kilobytes examples.

This is the point at which the project moved from metadata-only to demonstrably reading decrypted response content with **no required proxy, CA, or Frida runtime**.

### Why this generalizes across releases

The **contract** (a per-request callback receives a ByteBuffer and related lifecycle events) is more important than the historical obfuscated name `LX/02gB`. On a different Instagram version, the class may be renamed, the response wrapper may differ, or callback topology may change. The new skill provides `scan_tigon.py` to find this behavior and a worksheet requiring proof before insertion.

### Request construction investigation did not finish

Another path was identified: `smali/com/facebook/tigon/TigonXplatBodyStream.smali`, implementing `TigonBodyStream` with `transferBytes(byte[], int)`, `transferBytes(byte[], int, int)`, `transferBytes(ByteBuffer, int)`, plus `writeEOM`. This is a plausible **upload** interception point, but no functional upload hook, cross-direction requestId mapping or saved POST/GraphQL outgoing body was demonstrated. **Do not claim outgoing payload capture is solved.** Followers/following response content was also not verified: the dedicated user-navigation test was requested, then interrupted by later bugs.

## 7. Oct 12: asset paths, bounded threads, and real media files

### Filenames

The user observed the output had numeric subdirectories containing files named `jpg`, with no extension; the code had actually used `/` between id and extension, e.g. `assets/images/217788832/jpg`. This was fixed by using:

```text
assets/images/<sha256>.jpg
assets/videos/<sha256>.mp4
```

Specifically `appendResponseExtras` preserved its calculated hash in `v6` instead of transient `v0`, appended `<hash>` (fallback numeric id), then used `const-string v5, "."` before the extension. The fix was rebuilt and installed; a later sample was pulled and verified as a **valid JPEG 240×426**.

### Growing OS thread count

The first worker implementation made a **new Java Thread per body chunk and a new Thread per finished request**. Under active feed traffic, the observed process thread count climbed **139 → 157 in 24 s**, indicating avoidable thread creation. The assistant added a static `ExecutorService`, initialized by `Executors.newFixedThreadPool(2)`, and replaced both `new Thread(...).start()` sites with `executor.execute(...)`.

After rebuilding/installing, thread counts during a 30-second sample were approximately **124, 136, 139, 147, 149, 147, 147, 147, 148, 147**, clearly plateauing. This verifies bounded **worker thread count** and continued file creation, but **not** bounded queue memory or ordering, since Java `newFixedThreadPool()` uses an unbounded task queue.

### JPEG and fragmented MP4

With the same sample, paths such as `<sha256>.jpg` and `<sha256>.mp4` existed under assets. Pulled JPEG was recognized as a genuine JPEG, dimensions 240×426. Video fragments were not recognized as standalone MP4 by `file`; a hex dump started at an MP4 `moof` atom and contained `traf`, `tfhd`, `tfdt`, consistent with **fragmented-MP4 media segments**, not necessarily corruption. **Not** proof of a complete independently playable video; the init segment (`ftyp`/`moov`) and possibly range assembly would be needed.

## 8. Oct 12 end-state: feed regression and last edit

**Critical caution:** after the pool/asset build, the user reported the app stopped showing **posts, images, videos and reels**. The earlier assistant had checked threads and disk output, but had not verified actual UI content: file capture success did not imply app functionality.

Inspection found an error in the code previously injected into `LX/02gB.onBody(ByteBuffer)`:

```smali
# In the FIRST injected version:
.method public final onBody(Ljava/nio/ByteBuffer;)V
    .locals 6
    ...
    move-result-object v6   # BAD: v6 == p0 (this), on an instance method with .locals 6
    ...
    iget v1, p0, LX/02gB;->A01:I
```

Overwriting the `p0` alias breaks original behavior on every response chunk. The last recorded code change was:

```diff
 .method public final onBody(Ljava/nio/ByteBuffer;)V
-    .locals 6
+    .locals 8
```

The output named `instagram_bugfix_signed.apk` was **successfully rebuilt, zipaligned, signed, installed** via `adb install -r`, and relaunched. The recorded response ended with the assistant asking the user whether feeds/videos/reels now worked. The next user action was to **export the session**. **There is no subsequent device/UI verification in the provided source.** Therefore label the final bugfix **installed but feed recovery unverified**, not fully successful.

Additional possible but **not proven** stability issue: expensive media SHA-256 and `copyFile` happened under the shared `sPending` lock in the reconstructed helper. The session hypothesis was to move I/O outside the lock, but did not implement or test that change. Add this to any new version's pre-release hardening checklist.

## 9. Verified vs incomplete matrix

| Feature | Historical result | Confidence |
|---|---|---|
| On-device JSONL method/URL/status/headers | 182 lines in a run; redacted known headers | Observed |
| Actual response JSON bytes via regular callback | 694-byte parseable reels-tray response; 8/41 bodies | Observed |
| Additional response bytes | 15 response bodies in later run, some large | Observed |
| Real JPEG capture | Pulled and recognized by `file` | Observed |
| fMP4 chunk capture | Hex `moof`/`traf` etc. | Observed fragments only |
| Request body bytes incl. GraphQL payload | No successful captured samples | Not implemented |
| Matching all incoming/outgoing body streams | Not demonstrated | Not established |
| Complete video reassembly | `moof` fragments only | Not implemented |
| Visible in-app REC button | Frida-only implementation abandoned | Not implemented in final Smali |
| Last APK UI works after register fix | Installed/started, no user confirmation | Unverified |
| Files are safely redacted | Headers partially redacted; raw bytes in shared storage | **Not safe enough for production** |

## 10. Commands from the successful workflow (sanitized)

The original used Git Bash on Windows, full paths to Android SDK binaries, and device paths prefixed `//sdcard/` because native `adb.exe` arguments otherwise underwent MSYS conversion. Replace these with actual paths/serial:

```bash
WB="/c/path/to/android-workbench"
DEC="$WB/workdir/instagram-448.0.0.18.84/apktool_decoded"
OUT="$WB/workdir/instagram-448.0.0.18.84/build"
BT="/c/path/to/Android/Sdk/build-tools/36.0.0"
ADB="/c/path/to/Android/Sdk/platform-tools/adb.exe"
SERIAL="YOUR_AUTHORIZED_DEVICE"
mkdir -p "$OUT"

# No Frida or proxy step is necessary for the callback capture mechanism.
java -jar "$WB/tools/apktool/apktool.jar" b "$DEC" -o "$OUT/unsigned.apk"
"$BT/zipalign.exe" -f -p 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"
"$BT/apksigner.bat" sign --ks "$OUT/local-test-key.jks" \
  --out "$OUT/signed.apk" "$OUT/aligned.apk"    # provide test-key password securely
"$BT/apksigner.bat" verify --verbose "$OUT/signed.apk"
"$ADB" -s "$SERIAL" install -r "$OUT/signed.apk"
"$ADB" -s "$SERIAL" shell am force-stop com.instagram.android
"$ADB" -s "$SERIAL" shell monkey -p com.instagram.android 1

# Run functional tests in the app, then inspect local output:
"$ADB" -s "$SERIAL" shell ls -l //sdcard/Download/InstagramCaptures
"$ADB" -s "$SERIAL" pull //sdcard/Download/InstagramCaptures "$OUT/exported-captures"
python scripts/analyze_capture.py --root "$OUT/exported-captures/InstagramCaptures" \
  --manifest "$OUT/manifest.json"
```

**Warnings:** Do not clear/delete existing captures before backing them up or obtaining explicit approval. For new Android versions, use app-private storage instead of shared Download. Do not hardcode keystore passwords into shell commands or logs. Freshly re-signed APKs may not be upgradable over original-signed installs. In the historical session `adb install -r` sometimes printed `Unknown command: install-incremental`, then fell back to streamed install and eventually said `Success`; the final `Success` was the meaningful result.

## 11. Troubleshooting lessons

| Symptom | Actual session lesson |
|---|---|
| ADB not found/connected | SDK PATH changes from PowerShell may not apply to existing Git Bash shell; use full path and `adb devices -l` |
| `/sdcard` becomes Windows host path | Git Bash/MSYS rewriting; `//sdcard/...` device-side in that environment |
| Frida `.so` mapped but nothing captured | `loadLibrary` success is not proof that gadget JS runtime started; Frida abandoned |
| `traffic.jsonl` has no body fields | A lifecycle hook alone cannot prove body callbacks ran; instrument actual per-request callback |
| Boolean flags enabled, still no `onDownloadBody` | Observe actual invocation; do not infer success from flags |
| `JSONDecodeError: Unterminated string` | Race between metadata mutation and finalize worker; implement coherent per-request locking/writer actor |
| Apktool reports high register/index error | Verify `.locals` plus parameter physical mapping and invoke encoding |
| File saved under `number/jpg` | Path builder used `/` instead of `.`, append hash + dot extension |
| App initially responsive, later slow | Per-event `new Thread` generated thread growth; use bounded workers **and queue** |
| Media file begins `moof` but won't open | fMP4 chunk, needs init/reference segments; not necessarily corrupt |
| APK builds/installs but feed empty | Do UI regression and inspect overwritten `p0` alias in onBody injection |
| Build fails silently/corrupt ZIP | Host low-RAM pressure; inspect log and ZIP, free RAM, retry after understanding failure |

## Provenance and reproducibility

The Skill bundles three Smali helper sources **reconstructed** from this JSONL's `Write` and subsequent `Edit` tool inputs (20 helper-file Write/Edit events, no mismatched text substitutions). They preserve the historical experiment's actual code, including known shortcomings, instead of inventing a revised helper that was never tested. To reproduce the reconstruction from the same exported JSONL:

```bash
python scripts/reconstruct_history.py --session-jsonl session-export.jsonl --out /tmp/reconstructed
```

Then compare these files to `assets/historical-smali/`. The callback-class source `LX/02gB` was **not** included in full in the transcript, only the precise old/new `Edit` segments. Those are preserved in [historical-448-code-edits.md](historical-448-code-edits.md). This honest boundary matters: one cannot reconstruct the entire obfuscated APK or working signed APK solely from the session-export JSONL.
