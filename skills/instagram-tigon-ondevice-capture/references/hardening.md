# Smali, storage, concurrency and privacy hardening

The bundled `assets/historical-smali/*` is a **faithful recovery of tested experimental code**, not production-ready code. It is useful to understand the mechanism and code-edit history, but it contains multiple known and potential hazards that a new version port must address. The October 12 build had a user-reported UI/media regression and a last-minute `.locals` fix without a subsequent full functional confirmation.

## Contents

1. Smali register and verifier traps
2. ByteBuffer, upload and response semantics
3. Threading, ordering, locks and memory
4. Capture format and file lifecycle
5. Sensitive data, permissions and storage
6. Stability and change-control gates
7. Concrete correction plan for old helper

## 1. Smali register and verifier traps

### Register aliasing (the historical root cause)

In a non-static method, `.locals L` reserves v0...v(L−1) as independent locals; parameters follow those in the physical register file. For:

```smali
.method public final onBody(Ljava/nio/ByteBuffer;)V
    .locals 6
```

`p0` aliases `v6` and `p1` aliases `v7`. This inserted instruction was catastrophic:

```smali
invoke-virtual {p1}, Ljava/nio/ByteBuffer;->duplicate()Ljava/nio/ByteBuffer;
move-result-object v6  # overwritten p0 = this
```

Later original instructions still used `iget ..., p0, LX/02gB;->A01:I`. `p0` now pointed to a ByteBuffer, not a `LX/02gB` object. App responses were disrupted. The transcript changed `.locals 6` to `.locals 8` and successfully rebuilt, but the user did not complete a post-install feed retest before exporting the session. Use the scanner's warning and manual live-register analysis, not a blanket rule to add two locals everywhere.

**Additional rules:**

- `.registers R` defines *total* registers; `.locals L` defines only non-parameter registers.
- `long`/`double` arguments use two contiguous physical registers; don't corrupt the second word.
- Short-form `invoke-static {x,...}` can require all passed registers in v0–v15. An earlier `.locals 16` helper caused an assembler register-encoding error. Factor into helpers or use valid `/range` forms, checking contiguous argument order.
- `move-result`/`move-result-object`/`move-result-wide` must follow the invocation they consume, without inserting arbitrary instructions between them.
- `try` bounds, `.catch` and `.catchall` labels must be structurally valid, nonoverlapping where required, and never capture the app's original exceptions in a way that skips critical cleanup.
- Changing a hook's local count can change the compiled verifier's type state at merge points. Inspect original `v` uses and `p` aliases throughout the entire method.
- Do not change return value or swallow an exception originating from the app's original instructions. Only optional instrumentation should fail soft.

Run the included read-only `audit_smali.py` and build with apktool. The tool flags obvious alias writes and oversized invoke operands; it **does not** prove bytecode safety. Build/install/runtime test is mandatory.

## 2. Correct ByteBuffer semantics

Never call `.get(...)` on the original argument unless the app's existing behavior already expects it. Instead:

```java
// Design-level example: NOT source known to be built or run in this session.
ByteBuffer view = original.duplicate();
int size = view.remaining();
if (size <= MAX_CHUNK_BYTES && recordingEnabled) {
    byte[] bytes = new byte[size];
    view.get(bytes);  // only the duplicate position changes
    recorder.trySubmitBody(requestId, bytes);
}
```

`duplicate()` shares underlying memory but has independent cursor state. Copy while the original/native memory is valid; **do not** queue the duplicate itself for later asynchronous reading, because the producer may reuse buffers. Guard null, empty buffers, read-only, direct buffers, unusually large `remaining()`, and repeated callbacks. `copyBytesFast` in the historical engine caps each individual chunk at **0x200000 (2 MB)**, which means any larger single chunk could be truncated unless explicitly flagged; the accumulated file across chunks is not limited to 2 MB. Treat a truncated chunk as **partial** and never write a false byte count.

For outgoing body hooks at `transferBytes(...)`, inspect each overload's exact `offset`, maximum/returned bytes and copy *after* knowing the actual number transferred. Do not mutate input array, ByteBuffer cursor or result. Record whether captured bytes are pre-compression, post-compression, encrypted or decoded; otherwise “exact wire body” claims are unsupported.

## 3. Threading, ordering, locks and memory

### Bugs/risks in the recovered TigonCapture engine

1. **Unbounded task queue:** `Executors.newFixedThreadPool(2)` bounds the number of worker threads, **not the number or aggregate byte size of queued `byte[]` tasks**. Under media-heavy traffic, queued bodies could exhaust memory despite stable thread count.
2. **Body/EOM reordering:** `TigonBodyWorker` and `TigonWriteWorker` share a two-thread pool. A finalize task may execute while a prior body worker is still writing, close a stream early, or compute SHA-256 before pending body bytes are complete.
3. **Incomplete synchronization:** `onStarted` and `onResponse` lock the global `sPending` map for some operations; `onEOM`/`onError` and parts of `writeAndRemove` mutate or remove map state outside that monitor. Many other mutable static HashMaps are unsynchronized. Observed malformed JSON was partially fixed, but logical races remain plausible.
4. **Expensive global lock:** `writeAndRemove` holds `monitor-enter sPending` while `appendResponseExtras` hashes response files and copies media. This can stall all other metadata event writers while processing large files. Move slow I/O completely outside shared map lock.
5. **Coarse exception swallowing:** broad `catch Throwable` may hide failed capture and make reports look complete, even when I/O failed. Track an error counter and mark the record incomplete instead.
6. **ID collision:** `System.identityHashCode(callback)` is not a globally unique request ID. Use a dedicated process-unique monotonically increasing ID with a stable mapping for the life of each callback request.
7. **Disk limits:** no proven file-size quotas, daily rotation, free-disk checks or atomic JSONL record persistence exist in the 448 code.

### Safer future design (not implemented/validated in the historical session)

Use an explicit state object **per request** and an ordered event stream. One feasible design:

```text
Callback thread
  onStarted  -> serialize safe metadata; assign process-unique requestId
  onResponse -> enqueue status/headers update
  onBody     -> byte-copy from duplicate; tryOffer(BODY, immutable byte[])
  onEOM     -> enqueue END after all accepted BODY events
  onError   -> enqueue ERROR and terminate request

Bounded writer queue (capacity in BOTH events and total buffered bytes)
  -> one serial writer OR per-request serial executors with controlled concurrency
  -> write BODY chunks in order
  -> after all accepted BODY events: close stream
  -> compute SHA, MIME, length and completion state outside global lock
  -> append exactly one JSONL line atomically, with relevant counters
```

**Overload policy:** NEVER block Instagram's networking callback until disk work completes. If the queue/budget is exhausted, drop the *capture* for that request (not the app's traffic), set `captureState="partial"`, record `droppedChunks/droppedBytes`, and still allow original callback logic to proceed. Ensure END records aren't lost (reserve control-event capacity or use a fallback finalization path). Denote cancellation, retries and HTTP Range partial responses accurately. Add a bounded map cleanup/reaper to avoid leaks if a request never receives EOM.

**Lock scope:** A short synchronized section may assign ID, append metadata and update state, but do not hash, decode JSON, open files, copy assets or perform slow stream writes while holding a process-wide lock. Use per-request synchronization or immutable queue events.

## 4. Output format, duration, hashing and completeness

The user originally asked for:

```text
InstagramCaptures/
  traffic.jsonl
  requests/<requestId>/request_body.bin
  responses/<requestId>/response_body.bin
  assets/images/<sha256>.<ext>
  assets/videos/<sha256>.<ext>
  assets/audio/<sha256>.<ext>
  assets/other/<sha256>.<ext>
  manifest.json
```

A recommended sanitized per-request record schema (design target, not proof all fields existed historically):

```json
{
  "requestId": "local-process-id:12345",
  "timestampUtc": "2026-10-12T16:00:00Z",
  "method": "POST",
  "urlPath": "/api/v1/example/",
  "requestHeadersRedacted": {},
  "status": 200,
  "responseHeadersRedacted": {},
  "requestBodyPath": null,
  "responseBodyPath": "responses/local-process-id_12345/response_body.bin",
  "responseBodyBytes": 694,
  "responseBodySha256": "<64 hex chars from actual file>",
  "contentType": "application/json",
  "contentEncoding": "identity",
  "mediaSegment": false,
  "httpRange": null,
  "captureState": "partial|complete|failed|cancelled|metadata-only",
  "droppedChunks": 0,
  "reason": "body callback observed; exact HTTP completion checks pending"
}
```

Avoid writing `captureState="complete"` solely because EOM fired. To prove response completeness, cross-check bytes/Content-Length (if present and meaningful after Content-Encoding), transfer semantics, HTTP 206 Range and retries, stream end and errors. Some responses have no Content-Length or were decoded into a different representation. In those cases mark `completeAtCallbackBoundary=true` separately from `httpEntityComplete=true/unknown`.

For binary assets, use hash filenames with actual file extensions, avoiding the historic `id/jpg` path bug. Check bytes by magic, not just `Content-Type`. A `moof` fMP4 fragment should be classified as a `fragment` and include segment/range metadata. Do not claim complete playable video without the matching `ftyp`/`moov` init segment and verified sequence.

For JSONL append, serialize a complete in-memory record (small metadata only) into one JSON line, then write it with a file lock or single writer. Use robust JSON escaping (including control characters), length limits, and UTF-8. Atomicity across power failure is a separate issue: consider temp-file and append-journal or fsync strategy if requested. An on-device `manifest.json` was not achieved historically; `scripts/analyze_capture.py` can create a sanitized off-device manifest.

## 5. Privacy and storage (mandatory for a new port)

The historical engine saved **raw response bodies** to `/storage/emulated/0/Download/InstagramCaptures/`. This was useful for the user's authorized test, but raw bodies can contain session details, account information, personal data and media. Header-key redaction (e.g. `Authorization`, `Cookie`, `X-IG-WWW-Claim`) and limited JSON regex replacement do **not** protect raw `.bin` files; URLs can leak tokens/IDs in query parameters too.

Require these **default protections**:

- Record **metadata only by default**, with query strings and sensitive header keys redacted. Restrict/ignore password, cookie, token, session, credential, CSRF, auth, device identifiers, account IDs, profile data, location and private messaging values by default.
- Require explicit user opt-in, on a test account and device, for any raw API or media-body recording. Give an easily visible OFF state, session stop and clear/export controls.
- Store originals under `Context.getFilesDir()` or private app-specific external files. For Android 10+, scoped storage can make the 448 shared `Download` absolute path unreliable; use MediaStore/SAF for **user-initiated** public Downloads export.
- Protect raw captures from ordinary third-party apps: correct directory permissions, temporary retention, quota/cap/rotation, optional encryption, and consent before exporting.
- Never include unredacted session headers, body previews, full URLs, raw content files or authentication material in bug reports, Skill logs, screenshots or example fixtures.
- Scrub exports at the parsing boundary; do not assume a regex is complete. The bundled analyzer emits aggregate counts and signature information only.
- Use no remote endpoint, telemetry or hidden network listener. If the user later requests upload/share, require explicit intentional action for each export.

**Check the old Reqable worktree:** earlier proxy research edited debuggable/network trust settings. The direct in-process capture method **does not require** disabling TLS protections or changing certificate trust. Revert or justify any left-over altered manifest/debug overrides before distributing a test APK.

## 6. Release/stability checks

Verify with capture OFF and ON:

- cold start, login/test session, home feed, pull-to-refresh, profiles, posts, images, reels, video playback, scrolling, navigation, background/foreground;
- network status outcomes, metadata/body capture events, correct binary signatures and SHA/length;
- no added `VerifyError`, class-load failure, crash, ANR, watchdog, leaked file handles or continuous queue/thread/memory/disk growth;
- callback CPU time and frames loaded under media-heavy traffic versus original baseline;
- no new unredacted shared-directory files or unsafe permissions;
- ability to disable capture **without** changing networking behavior.

A single 30-second thread count plateau is useful but **not sufficient**. The original session's visible feed regression was discovered **after** passing its file/thread checks.

## 7. Concrete edits to prioritize when reusing historical helper

Do not apply `assets/historical-smali/TigonCapture.smali` unaltered to a new APK. At a minimum:

1. Replace absolute `Download/InstagramCaptures` literals and shared data files with configurable app-private storage context and explicit export.
2. Replace `HashMap`/`StringBuilder` cross-thread mutable globals with per-request records and well-defined synchronization.
3. Replace two-worker unbounded task queue with bounded byte/task admission and **strict per-request event ordering**.
4. Move `sha256File` and `copyFile` entirely outside shared map monitor; preferably avoid duplicate full-file I/O if no asset copy is needed.
5. Bound `copyBytesFast` and the aggregate capture budget per request; mark drops, partials and errors explicitly.
6. Make raw bodies opt-in; redact headers, URLs/query, JSON previews and form data before publication/export.
7. Use an ID that remains unique for each request; maintain mapping between lifecycle and body events.
8. Make `onEOM`/`onError` and pending-state removal race-free; finalize only after earlier BODY chunks are durable.
9. Add backpressure counters, quota/rotation, malformed JSONL recovery and sanitized manifest reporting.
10. Re-audit every inserted callback register and exercise the app's actual media rendering—not just APK compiler success.
