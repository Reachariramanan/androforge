# Porting the Tigon hook to a different Instagram APK version

This guide turns the **observed 448.0.0.18.84 implementation strategy** into a semantic search workflow. A working patch on one version provides *search landmarks*, not durable obfuscated filenames. This guide must be used with the `SKILL.md` acceptance gates.

## Contents

1. Version intake and fingerprinting
2. Decoding and graph discovery
3. Selecting a callback class by behavior
4. Porting callbacks in checkpoints
5. Handling changes in response structures
6. Request body path — not yet solved
7. Native/architectural variants
8. Version-specific adaptation worksheet
9. Decision table

## 1. Version intake and fingerprinting

**Collect** (do not assume): full APK path, whether base APK or split APKs, SHA-256, package ID, `versionName`, `versionCode`, min/target SDK, Android OS API, ABI, manifest permissions and shared/native libraries. Do not overwrite the pristine source.

```bash
# macOS/Linux/Git Bash (use paths appropriate to the current machine)
sha256sum original-instagram.apk
unzip -l original-instagram.apk | head -40
java -jar tools/apktool/apktool.jar d -f original-instagram.apk -o decoded
python scripts/scan_tigon.py --decoded decoded --json discovery.json --markdown discovery.md
```

If Android SDK tools exist:

```bash
aapt dump badging original-instagram.apk
apkanalyzer manifest application-id original-instagram.apk
apkanalyzer manifest version-name original-instagram.apk
apkanalyzer manifest version-code original-instagram.apk
```

Tool versions in the historical case (apktool 3.0.3, jadx 1.5.6, Android build-tools 36) are evidence, not dependencies to pin for every future APK. Use compatible current versions. For AAB, use bundletool to produce a device-compatible APK set; split packages require correct base/split installation, not a single-base shortcut. A Play-delivered APK may contain anti-tamper checks that must be reported rather than silently disabled.

### Decode strategy

Preserve two trees if convenient: `decoded/` for editable apktool Smali and `jadx/` for conceptual Java/Kotlin/navigation. `jadx` output is not the source to recompile with apktool. The 448 original was about 241 MB unzipped with 17,486 files, so plan disk and memory accordingly. Use `jadx --no-res ...` to reduce load if tools support it. Read only the relevant Smali folders first.

## 2. Discover anchors, not filenames

The 448 investigation established these *semantic* relationships:

```text
TigonServiceLayer / service wrapper
  |
  +-- makeTigonCallbacks(...)
  |       -> obfuscated concrete class: historical LX/02gB
  |       -> extends com.facebook.tigon.TigonCallbacks
  |       -> onStarted(TigonRequest)
  |       -> onResponse(ResponseType)
  |       -> onBody(ByteBuffer)         <--- proven usable for decrypted response bytes
  |       -> onEOM(...), onError(...)
  |
  +-- sendRequest(TigonRequest, TigonBodyProvider,
                  TigonCallbacks, Executor)
                  |
                  +-- network I/O inside Tigon/native stack
```

Also present historically:

```text
TigonObservable
  -> onStarted / onResponse / onEOM / onError [observed]
  -> onDownloadBody / onUploadBody [present, NOT observed]

TigonXplatBodyStream (implements TigonBodyStream)
  -> transferBytes(byte[], int)
  -> transferBytes(byte[], int, int)
  -> transferBytes(ByteBuffer, int)
  -> writeEOM / reportBodyLength / reportError
  -> potential outgoing request payload boundary [UNPROVEN]
```

Run `scan_tigon.py`; inspect all reported callback candidates and instantiation sites. Manual quick probes:

```bash
rg -n '\.super Lcom/facebook/tigon/TigonCallbacks;' decoded/smali*
rg -n 'onBody\(Ljava/nio/ByteBuffer;\)V' decoded/smali*
rg -n 'TigonXplatService;->sendRequest' decoded/smali*
rg -n 'makeTigonCallbacks|TigonBodyProvider|TigonBodyStream|transferBytes' decoded/smali*
rg -n 'TigonObservable;-><init>' decoded/smali*
```

If using stock `grep`, replace `rg` with `grep -R -n`. Some grep shells expand `decoded/smali*` to directories; adjust accordingly. For huge worktrees, restrict to relevant package directories once identified.

Search by `.super` and **method descriptor**, not class basename. In a new build, the concrete class may be `LX/abcdef;`, a different dex partition, a subclass of a subclass, or a different callback implementation. Method names may also differ. Inspect call graphs to confirm the request submission API passes this object for real traffic.

### Evidence to collect per hook

Create a note for each new candidate:

| Item | Record |
|---|---|
| Concrete class | Full descriptor and Smali path |
| Parent | Superclass chain leading to TigonCallbacks |
| Instantiator | Constructor/new-instance and the surrounding owning service |
| Request submission | `sendRequest` target, actual argument order/types |
| `onStarted` | Descriptor, request URL/method/header accessors |
| `onResponse` | Response class, status field/accessor and header map field/accessor |
| `onBody` | Signature and whether incoming `ByteBuffer` is passed on to app queue |
| `onEOM`/`onError` | Full descriptors, lifecycle semantics and cancellation/retry behavior |
| Original register layout | `.locals`/`.registers`, total parameters, current `v`/`p` usage |

Require at least one runtime proof (metadata event on test account) before escalating to capturing body data.

## 3. Select a callback using behavior

`TigonCallbacks` is an abstract/base callback with a no-op surface in the historical APK. Look for actual **overrides**, especially an `onBody(Ljava/nio/ByteBuffer;)V` that retains/queues the `ByteBuffer`. In the 448 build, the obfuscated class `LX/02gB` called an internal queue `LX/02gC` with a `ReentrantLock`, `Condition` and `Queue`, so instrumenting it **before** the app's original buffer handling was a high-risk hot path. Do not assume every request in all versions uses the same concrete class or that the callback receives all bytes for all traffic families (image cache, QUIC, video, other transport etc.).

Read raw Smali for method entry/exit, existing `try` regions and locals. Use a decompiler only to reason about types and control flow. Prefer a small metadata-only insertion for first runtime proof. Never replace the original method body.

### Register math: mandatory

For `.method public final onBody(Ljava/nio/ByteBuffer;)V` with `.locals L`:

```text
parameter count = 2 words (this + ByteBuffer)
p0 -> physical vL
p1 -> physical v(L+1)
```

The October regression was exactly `.locals 6`, `p0=v6`, and then `move-result-object v6`. That overwrote `this` while original code still needed `iget ..., p0, ...`. Merely wrapping the hook in `try/catch` did **not** protect this logic corruption. Later `.locals 8` reserved v6 as a true local. This fixes that particular overlap; it does not prove all other register hazards are gone.

With `.registers R`, physical locals = R − parameter words. A `long` parameter takes two adjacent slots. Short-form `invoke-* {}` generally cannot address a parameter mapped above v15; use valid `/range` encodings or restructure code into helpers. Keep original `move-result` adjacent to its related invoke. Verify no introduced branch falls into or past original handlers incorrectly.

## 4. Port callbacks in checkpoints

**Checkpoint 1: lifecycle only.** Identify the app's current request type and response type. Historical signatures:

```smali
.method public final onStarted(Lcom/facebook/tigon/iface/TigonRequest;)V
.method public final onResponse(LX/00MW;)V
.method public final onBody(Ljava/nio/ByteBuffer;)V
.method public final onEOM(LX/00PO;)V
.method public final onError(Lcom/facebook/tigon/TigonError;LX/00PO;)V
```

Look up the current descriptors; they can change. For each method, inject a guarded `invoke-static` to the equivalent capture-engine entry point, then retain its original instructions. Prefer an app-owned read-only recording interface that can be disabled. For metadata correlate events on the **actual per-request callback object**. Historical code used `System.identityHashCode(p0)` converted to long; it worked for sampled data but is not collision-proof across concurrently or sequentially living objects. Harden with an identity-map plus atomic monotonic request ID, or carry a real native request ID if truly available. Do not mix the ID spaces of `TigonObservable` and a concrete `TigonCallbacks` instance without a declared mapping.

**Checkpoint 2: response bytes.** Make a duplicate of the callback's `ByteBuffer` and capture only the duplicate's `remaining()` bytes. Preserve the original buffer's `position`, `limit`, and any mark. Be alert to the `ByteBuffer` being reused: make an immutable byte copy while valid; don't retain the native/direct ByteBuffer for delayed processing. Avoid expensive SHA/disk writes synchronously inside the onBody callback. To prevent unbounded queue growth, use an explicit **bounded** queue (fixed thread count alone is insufficient), admission/backpressure policy that does not stall the app, and missing-data counters.

**Checkpoint 3: file capture.** Associate response-body chunks with a per-request record; open a new body file on first chunk. On event completion, flush and close only **after** all body chunks are processed. One workable design is a single writer/actor per request or a global ordered event queue ensuring `BODY_1, BODY_2, ... END` order. Race-free mapping and lock scope matter at high feed/media concurrency. Generate SHA-256, content classification and asset copies **after** releasing any global per-request metadata lock.

**Checkpoint 4: redaction/privacy.** Keep sensitive raw bodies off by default; metadata URLs must have query parameters masked. If explicitly enabled for controlled test-account payloads, encrypt files at rest or store app-private, with explicit export. The historical `redactBody` and `isSensitiveHeader` cover only some keys and do not make unredacted shared-storage bodies safe.

**Checkpoint 5: UI regression.** Test **feed/posts/reels/video** on the actual target device with recording both enabled and disabled. A file appearing in `Download/InstagramCaptures` does not prove that the app still renders content. Never skip this after a single-register edit.

The raw historical injection snippets (including the corrected `onBody` `.locals 8`) are recorded in `historical-448-code-edits.md`, and the recovered engine is under `assets/historical-smali/`. Treat them as demonstrations of mechanics, not automatic template patches.

## 5. Response type/accessor changes

In 448, response status was read from `LX/00MW;->A00:I` and headers from `LX/00MW;->A01:Ljava/util/Map;`. A future version may use methods, different field order, a wrapper or a different map type. Derive the meaning by tracing where the app itself extracts HTTP status and headers, examining class constructor and field assignments. Do not assume `A00` means status everywhere. Incorrect `iget` types will fail verifier or crash at runtime, even if the patch assembles.

Similarly `TigonRequest.method()`, `url()`, `headers()` are semantic landmarks, not guaranteed accessible methods forever. Compare `TigonRequest` definition and call sites in each version. Check null safety before calling accessors.

## 6. Outgoing request body — remain evidence-based

The 448 experiment attempted `TigonObservable.onUploadBody` and even toggled two observer-constructor booleans, but **zero such callbacks were observed**. The subsequent successful `LX/02gB.onBody` was for **downloaded response bytes only**. The app-side GraphQL POST body (`doc_id`, variables, forms) was **not recorded** in the final confirmed tests.

A candidate for independent investigation is `TigonXplatBodyStream.transferBytes` variants. Study the flow:

```text
API request construction / GraphQL serializer
       -> TigonBodyProvider
       -> TigonXplatBodyStream.transferBytes(...)
       -> Tigon/native upload
```

Questions that must be answered before claiming upload success:

1. Does the stream receive the exact outgoing HTTP entity bytes or an intermediate/compressed representation?
2. Which argument holds **valid** byte length and offset for each overload?
3. How can this stream be mapped to the *same requestId* used by the response-callback recorder? Does its provider carry a request pointer or request object?
4. Is it safe to copy without altering `ByteBuffer.position()`, source `byte[]`, backpressure, or stream return values?
5. Are all uploads encountered (forms/multipart/streamed/offset) and cancellation/retries correctly accounted for?
6. Do real saved test samples prove both request and response file contents?

Until those are done, report **response-capture-only**. Do not claim GraphQL bodies or followers data just because their endpoint URLs were observed.

## 7. Native and format branches

- **No TigonCallbacks match**: search for transformed names, inherited Java/JNI bridge, other concrete callback implementations or changed networking architecture. Re-run scan after extracting all split dex files. Report a blocker if no grounded hook exists.
- **No onBody invocation**: distinguish callback absence, feature gate, app cache, test traffic, wrong process, and method mismatch. Use an explicit diagnostic counter; never conclude native impossibility solely from one zero count.
- **Different ABI**: do not copy `arm64-v8a` native libraries into x86_64 only builds. The direct Smali approach should not need Frida `.so` files.
- **Android >=10 scoped storage**: replace 448's absolute shared `Download/...` path with app-private `filesDir` or `getExternalFilesDir()` plus explicit export. For public Downloads use MediaStore/SAF with proper user approval; no assumptions about broad storage permissions.
- **Compressed content**: `Content-Encoding`, chunks and HTTP range may not equal what `ByteBuffer` carries. Identify if callback observes transport-compressed or parsed bytes and record the stage.
- **HTTP/2, QUIC, streaming**: an `onBody` chunk is not a message boundary and a file is not automatically a complete asset. Preserve ordering and ranges, and report incomplete fragments.
- **Play Integrity / signature mismatch**: re-signed Instagram may fail login or installation on some releases; do not suggest defeating integrity controls. Record the limitation, use a reproducible test APK where authorized.

## 8. Version adaptation worksheet

For each version, write `reports/<version>-port.md` including:

```markdown
# Instagram Tigon capture port: <versionName> (<versionCode>)
- Input APK: <file>; SHA256: <hash>; variant/splits: <...>
- Test device: <Android API, ABI, device type>
- Decoder/compiler: <tool versions>
- Native Tigon present: <evidence>
- Callback base: <descriptor/path>
- Concrete callback: <descriptor/path/instantiating method>
- `onStarted` descriptor/accessors: <...>
- `onResponse` descriptor/status/headers: <...>
- `onBody` descriptor/consumer behavior: <...>
- `onEOM/onError` descriptors: <...>
- Body upload stream available: <descriptor; unimplemented unless proven>
- New helper package/path: <...>
- Register map for every changed method: <.locals, p0/p1, max v, invocations>
- Capture destination/privacy defaults: <...>
- Diff and rollback artifact paths: <...>
- Build/sign/install verification: <commands + exit codes>
- Regression with capture OFF/ON: <posts/images/videos/reels/UI result>
- Evidence: <JSONL validity, true JSON response bytes, JPEG signature, moof/ftyp, SHA, counts>
- Status per feature: VERIFIED / IMPLEMENTED-UNVERIFIED / NOT-IMPLEMENTED / FAILED
- Limitations and next required tests: <...>
```

## 9. Decision table

| Observation | Correct next step |
|---|---|
| Same Tigon callback hierarchy, different obfuscated names | Re-map signatures/fields; port minimal hook with register audit |
| Metadata works, observer body callbacks silent | Inspect concrete `TigonCallbacks` path; do not flip flags repeatedly |
| Response body `.bin` exists and parses JSON | Verify full length and lifecycle; check stable original app rendering |
| Request-body bytes absent | Mark incomplete, investigate independent upload-stream path |
| JPEG saved with no proper extension | Use `<sha256>.<ext>`; verify magic and on-disk path components |
| `.mp4` starts with `moof` | Mark fMP4 media segment; locate `ftyp`/`moov` init and Range metadata before reassembly |
| Feed/media broken after hook | Immediate rollback, isolate register corruption and blocking hot path |
| Captures valid, thread count growing | Replace per-event thread spawn and control actual queue size |
| Valid callback, inaccessible storage on newer Android | Switch to app-private storage and user-triggered export |
| Signature or integrity prevents app use | Report hard blocker; do not hide, bypass or misrepresent it |
