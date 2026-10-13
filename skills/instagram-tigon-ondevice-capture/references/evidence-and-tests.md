# Evidence, tests and truthful outcome reporting

This reference defines **what constitutes proof** when adapting the 448 direct-Smali capture to another Instagram version. Compilation, installation, process existence, local folder creation and thread count are separate checkpoints; none alone proves that the requested data was captured or that the original app works.

## 1. Layers of evidence

| Layer | Example evidence | What it does **not** prove |
|---|---|---|
| Source mapping | `TigonCallbacks` subclass, actual `sendRequest` call path | Callback is exercised in this installed build |
| Static Smali audit | No obvious `p0` register overwrite or invoke v16 | ART verifier and app can run all paths |
| APK build/sign | `apktool b`, zipalign check, `apksigner verify` pass | Android installation and login succeed |
| Device install | `adb install -r` returns `Success` | Feed/images/reels render, capture works |
| Hook activity | Request method/url/status appear in JSONL | HTTP body bytes observed |
| Body file | Nonempty `response_body.bin` exists | It is full, decoded, correct or associated |
| Byte check | SHA/byte length match and JSON parses | Every app response was captured |
| Media signature | JPEG magic, or fMP4 `moof` | Video is complete/playable |
| Thread count plateau | Fewer OS threads after executor change | Queue memory bounded, feed unblocked |
| UI functional matrix | Posts/photos/reels work OFF and ON | All network traffic universally covered |

## 2. Minimum positive tests

Use an authorized test account only. The app must operate normally during each step. If body collection is enabled by explicit permission, use benign app actions that produce test traffic.

1. **Baseline:** Clean original/test build loads home feed, photos, reels/video, profile, refresh. Note environmental failures separately.
2. **Metadata:** One API request captures distinct `method`, redacted URL/path, request headers, response status/headers, a stable local requestId, timestamp and lifecycle outcome. File parses line by line as JSONL.
3. **Response JSON:** At least one saved actual response body `.bin` parses into JSON and can be associated with its request metadata. Its byte length and SHA-256 match manifest values. Do **not** print raw response in report.
4. **Image:** At least one saved actual downloaded image has correct JPEG/PNG/WEBP signature and an appropriate file extension. Where possible decode it in an image viewer, without exposing third-party personal content.
5. **Video:** Identify a genuinely stored media byte stream, inspect box signature. If it begins with `moof`, label as a **fragment**, not a full video; record HTTP Range/chunk sequence if available.
6. **Lifecycle edge cases:** Test cancellation, retry, 204/empty, error, response without Content-Length, cached resource, large response and OFF toggle. Partial/missing must not appear as complete.
7. **Stress:** With capture ON, scroll feed and reels for a sustained representative test. Measure process memory, writer queue depth, pending request count, number of open files, dropped chunks and OS threads. Repeat OFF.
8. **Privacy:** Confirm test output contains no password/token/cookie/header secret/identifying body in logs or publicly writable storage. Only the specifically opted-in private body files may contain raw content.

For an unimplemented request-body hook, the count should explicitly remain zero/not supported. Do **not** claim a full-duplex recorder or GraphQL POST payloads without separate byte-level proof.

## 3. Local analyzer usage

```bash
python scripts/analyze_capture.py --root ./export/InstagramCaptures \
  --manifest ./report/capture-manifest.json --strict
```

The script is read-only with respect to raw body content and prints **aggregate evidence**: line counts, body file existence, lengths, SHA match, valid JSON body count (if MIME indicates JSON), media signature counts, missing paths and dropped/malformed records. It writes only sanitized summary JSON. It does not run any network connection and does not display raw bodies, cookies, headers or full URLs. Optional route-shaped endpoint summary masks every non-whitelisted route component and removes query strings:

```bash
python scripts/analyze_capture.py --root ./export/InstagramCaptures \
  --endpoint-stats --probe-keys followers following
```

`--probe-keys` reports only counts of matching JSON *key names*, **not values or follower identities**. A matching key is **not** proof of a particular user relationship. Validate deeper semantic claims manually and privately when explicitly authorized.

The transcript's verified JSON response was 694 bytes from a reels tray endpoint; this is a suitable *shape* to validate, but do not bundle or expose raw Instagram response data as a fixture.

## 4. Valid media and limitations

**JPEG:** first three bytes `FF D8 FF`. **PNG:** `89 50 4E 47 0D 0A 1A 0A`. **WebP:** `RIFF` at 0 and `WEBP` at byte 8. For MP4 ISO BMFF, a complete media file normally has an `ftyp` brand box near the start, with `moov`/`mdat` structure. A file beginning with a `moof` box is consistent with a **fragmented** media segment and may require a separate init segment to play. Never give `.mp4` extension alone as proof.

**HTTP Range:** response 206 and `Content-Range` can indicate a partial range. Content-Length may describe compressed transport bytes rather than decoded bytes observed in Java callback. Response completeness must be stated relative to the observed layer, not assumed universal.

**Coverage:** Metadata observer and per-request callback hooks may correspond to different code paths and assign different ID types. Some requests may use caches or alternate stacks. Count “outcome-only” and unpaired records; investigate rather than silently discard them. The 448 session had examples of **30 outcome-only records among 62 records**, and their exact cause was **not established**.

## 5. Regression and triage procedure

If metadata/body captures appear but images/posts/reels do not display:

- Stop calling the build successful; compare capture OFF/ON and pristine baseline.
- Look first for `p0`/`vL` alias collision in patched callbacks; the 448 source definitely had it.
- Inspect crashes, native aborts, verifier errors, ANRs, `onBody` callback latency and resource stalls.
- Ensure the logger never changes original ByteBuffer cursor or return value.
- Ensure `onEOM` finalizer does not close data while another worker still writes it.
- Move hash/disk-copy work out of global locks, cap queue bytes, record dropped captures without blocking app traffic.
- Revert the last patch when immediate stabilization is needed.

The one-line change `.locals 6` to `.locals 8` installed successfully but was never followed by a user-confirmed feed check in the export. A new AI must explicitly rerun this functional test before claiming that historical regression is resolved.

## 6. Reporting template

Use this exact per-version status structure in human-readable reports:

```text
APK version / versionCode / SHA-256 / package / ABI:
Test device Android version/API and environment:
Hook point found by semantic inspection:
Changed Smali classes and registers:
Build / zipalign / apksigner / ADB install evidence:
Capture privacy mode and local storage method:

IMPLEMENTED AND VERIFIED
- [feature] — [grounded evidence, counts, sanity tests]

IMPLEMENTED BUT NOT YET VERIFIED
- [feature] — [missing test evidence]

NOT IMPLEMENTED
- [feature] — [known limitation]

REGRESSIONS / FAILED ATTEMPTS
- [failure] — [symptoms, suspected and confirmed causes separately, rollback state]

Data integrity: JSONL records, malformed, metadata, response-body files,
request-body files, image signatures, fMP4 fragments, dropped records/bytes.
UI: cold-start, feed/posts/photos/reels/video, profile, refresh OFF/ON.
Resources: threads, peak memory, queue size, disk quota and file handles.
Privacy: credentials redacted, private capture path, export approvals.
Next step(s) and user-relevant blockers:
```

Reports should not contain raw bodies, social media identifiers, access tokens, private images or unredacted headers. Keep evidence file hashes and counts where sufficient.

## 7. Historical benchmark (do not expect identical numbers on future versions)

| Observation in the source export | Interpretation |
|---|---|
| 182 requests / 77 endpoints, metadata headers/status | Observer-based lifecycle capture worked |
| 0 request/response bodies via debug observer | That specific body path did not run on sampled traffic |
| 41 lines, 8 with real response bodies, 0 malformed | New `TigonCallbacks` response `onBody` path worked |
| 694-byte parseable JSON response | Direct in-process content verified |
| 3/66 malformed to 0/54 | Concurrency/serialization race fix improved JSONL quality |
| 15 response bodies in later run | Some additional response coverage confirmed |
| JPEG 240×426 recognized by `file` | Image saved with real bytes |
| `moof`/`traf`/`tfhd`/`tfdt` media bytes | Real fMP4 segment, not complete video |
| Threads stabilized approximately 147–149 | Bounded worker threads, not bounded memory queue |
| After thread/asset build: feed blank | Functional regression, initially missed by assistant |
| `.locals 6` → `.locals 8` build signed/installed | Corrected one real alias bug, feed recovery not retested |
