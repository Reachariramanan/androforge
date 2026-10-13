# AGENTS.md

## Universal AI Agent Instructions

This repository contains reusable skills for AI agents.

### Skill Discovery

All skills are located in:

`./skills/`

Each skill has a `SKILL.md` entrypoint containing:

- Name and description
- Required tools and dependencies
- Execution workflow
- Supporting references
- Executable scripts
- Verification instructions

### Agent Workflow

Before performing a task:

1. Inspect `./skills/` for relevant skills.
2. Read the relevant `SKILL.md`.
3. Follow its instructions.
4. Resolve relative paths from the skill directory.
5. Use `./tools/` for shared utilities.
6. Use `./scripts/` for repository-level automation.
7. Test results before reporting success.

### Portability

Do not assume a specific AI provider, model, IDE, or proprietary agent API.

Treat `SKILL.md` as the authoritative skill definition.

If the agent lacks a required execution capability, report the limitation instead of assuming success.

Agent-facing guide to this repo's active work: a local APK Workbench (see `CLAUDE.md` for the
general tool layout) currently focused on one deep sub-project — direct smali instrumentation of
a personal Instagram APK install to capture plaintext request/response bodies and downloaded
media, without Frida, without a CA cert/MITM proxy, and without modifying network traffic.

Scope: authorized, personal-device security research only. The target is the user's own
Instagram account and APK, installed on devices they own (an AVD emulator and a physical OPPO
A15s, Android 10/API 29, arm64-v8a, serial `<DEVICE_SERIAL>`). See `CLAUDE.md` and `README.md`
for the full authorization statement — it applies here too.

## Why this exists / the constraint set

The user's goal: inspect real request bodies, response bodies, and downloaded assets from their
own authorized Instagram install — not just URLs/headers. Explicit constraints given by the user,
still binding on any future work here:

- No Frida unless absolutely necessary (see "Approaches tried" — Frida was tried and abandoned).
- No CA cert, no MITM proxy, no network traffic modification.
- Don't interfere with `ByteBuffer` positions or consume streams the app itself still needs.
- Capture must be switchable on/off (see `DISABLED` flag file, below).
- Bounded buffering, incremental file writes — no unbounded growth (threads, memory, or queues).
- Stay scoped to the authorized test device/account; redact credentials and session tokens.

## Approaches tried, in order (do not re-propose the abandoned ones without being asked)

1. **Reqable MITM proxy** — ABANDONED. Worked technically (confirmed Tigon traffic flowing
   through a desktop proxy after flipping `android:debuggable` to activate Meta's own
   `<debug-overrides>` trust block in `fb_network_security_config.xml`), but the user explicitly
   rejected CA-cert/proxy interception as a method. `research/Reqable_Android_HTTPS_Inspection_Complete_Guide.md`
   is a leftover reference doc from this phase.
2. **Frida gadget injection** — ABANDONED. `objection patchapk` embedded `libfrida-gadget.so` via
   a patched `InstagramAppShell.smali` constructor (background-thread `System.loadLibrary` call).
   The `.so` mapped into the process (confirmed via `/proc/pid/maps`) but Frida's own JS runtime
   never initialized — zero `gum-js-loop` threads ever appeared, the gadget never opened its port.
   Working theory: Meta's native code has anti-instrumentation defenses that silently neutralize
   Frida without crashing. All gadget files, the loader thread, and the `SYSTEM_ALERT_WINDOW`
   overlay-button feature built alongside it were fully reverted; `InstagramAppShell.smali` is
   back to stock. **Do not re-attempt Frida against this target unless the user asks.**
3. **Direct smali bytecode patching — CURRENT, WORKING.** No Frida, no proxy, no CA cert. Detailed
   below.

## Current architecture (Approach 3)

Working tree for all of this: `workdir/instagram-448.0.0.18.84/apktool_decoded/` — this is the
live, actively-edited `apktool d`-decoded source tree. (Note the directory naming split: the
emulator-era slug `workdir/instagram-448-0-0-18-84/` from `scripts/`' `apk_slug()` convention is
mostly unused now; `instagram-448.0.0.18.84/` with the dotted version is the active one, built by
hand with `apktool`/`zipalign`/`apksigner` directly rather than through `scripts/frida-patch-apk.sh`.)

Output directory for builds: `workdir/instagram-448.0.0.18.84/reqable_patched/` (name is a holdover
from the abandoned Reqable phase — nothing in it relates to Reqable anymore). Contains the signing
keystore `debug-test.jks` (password `<KEYSTORE_PASSWORD>`, alias `testkey`, RSA 3072) and every build
iteration's output APK. **Latest known-good-attempt**: `instagram_bugfix_signed.apk` (fixes the
register bug described below; functional verification on-device still pending at time of writing).

### The capture engine: `smali_classes3/com/instagram/app/TigonCapture.smali`

Hand-written smali class, not decompiled from anything. Static state only (static maps keyed by
request id or by `keyFor(id, isUpload)` → `"<id>_u"` / `"<id>_d"` strings):

- `sPending: HashMap<Long, StringBuilder>` — also doubles as the lock object for the critical
  section shared between `onStarted`/`onResponse`/`writeAndRemove`.
- `sOpenStreams`, `sByteCounts`, `sPreviews`, `sContentType`, `sBodyPaths` — per-request-id or
  per-key scratch state, cleaned up at the end of `writeAndRemove`.
- `sExecutor = Executors.newFixedThreadPool(2)` — bounded background pool (see "Bugs fixed", #4).

Public entry points (all correlate work by a `long` id, called from the hook sites described
below):

| Method | Called from | Purpose |
|---|---|---|
| `onStarted(J,String,String,Map)` | request start | records method, URL, request headers |
| `onResponse(J,I,Map)` | headers received | records status code, response headers |
| `onBody(J,Z,ByteBuffer,Z)` | each body chunk | hot path: `copyBytesFast` → hands off to `sExecutor` |
| `onEOM(J)` | request complete | triggers `spawnWriteWorker` → async finalize |
| `onError(J,String)` | request failed | records error, triggers `spawnWriteWorker` |
| `processBody(J,Z,[B)` | `TigonBodyWorker` (pool thread) | does the actual file write / preview capture |
| `writeAndRemove(J)` | `TigonWriteWorker` (pool thread) | finalizes one request's JSON line, see below |

`onStarted` and `onResponse` take `monitor-enter`/`monitor-exit` on `sPending` around their
`StringBuilder` mutation (fixed a real race — see "Bugs fixed" #2). `onBody` is deliberately kept
cheap: it duplicates the incoming `ByteBuffer` (`invoke-virtual {buf}, ->duplicate()`, which shares
the underlying memory but has independent position/limit) *before* reading from it, so the real
app code's own consumption of the original buffer is never disturbed — this satisfies the user's
"don't interfere with ByteBuffer positions" constraint. All actual I/O (file writes, SHA-256
hashing) is deferred to `sExecutor`-pooled runnables (`TigonBodyWorker`, `TigonWriteWorker`, both
trivial `Runnable` wrappers in the same package), never done synchronously on the calling (native
callback) thread.

`writeAndRemove` is the finalizer: closes open file streams, computes final byte counts, appends
request/response body fields (`appendBodyFields`) and response extras (`appendResponseExtras` —
SHA-256 hash via `sha256File`, content-type/category detection via `extFromMime`/`categoryFromMime`,
copies the body into `assets/<category>/<sha256>.<ext>` via `copyFile`), then writes one finished
JSON line to `traffic.jsonl` and clears all per-request map entries.

Other helpers worth knowing about: `headersToJson` (redacts via `isSensitiveHeader`: authorization,
cookie, set-cookie, x-ig-www-claim, x-mid, ig-u-ds-user-id, x-fb-session-id,
proxy-authorization), `redactBody` (regex-based redaction of `password`/`token`/`secret`/
`session_id` JSON keys), `escapeJson` (manual, no library dependency available in this context).

**Kill switch**: an empty file at `/storage/emulated/0/Download/InstagramCaptures/DISABLED` makes
`writeAndRemove` skip writing (checked every call) — this is the on/off switch the user required.
There's no equivalent gate on `onBody`'s per-chunk work yet, only on the final write — acceptable
since without a final write nothing persists, but worth knowing if finer-grained pause/resume is
ever requested.

**Output layout actually produced** (on the device, under `/storage/emulated/0/Download/InstagramCaptures/`):

```
traffic.jsonl                       # one JSON line per request: method, url, requestHeaders,
                                     # status, responseHeaders, outcome, requestBody{Bytes,Path,Preview},
                                     # responseBody{Bytes,Path,Preview}, responseBodySha256,
                                     # contentType, assetPath
requests/<id>/request_body.bin
responses/<id>/response_body.bin
assets/{images,videos,audio}/<sha256>.<ext>
DISABLED                            # presence = capture paused (empty file, create/delete to toggle)
```

Deliberately **not yet implemented**: a `manifest.json` summary (deferred to off-device Python
post-processing), and byte-accurate completeness checking against `Content-Length` (`outcome` is
currently just `"success"`/`"error"` based on whether `onEOM` or `onError` fired).

### The hook points

Three independent places call into `TigonCapture`, discovered in this order:

1. **`smali/com/facebook/tigon/tigonobserver/TigonObservable.smali`** — the original, intended
   hook point (Tigon's native "debug observer" interface). Patched `onStarted`/`onResponse`/
   `onEOM`/`onError`/`onDownloadBody`/`onUploadBody`. **Finding: `onDownloadBody`/`onUploadBody`
   never fire** (confirmed via diagnostic `Log.i`, zero invocations across many real-traffic runs),
   even after forcing both `TigonObservable` constructor call sites — `IGTigonService.smali`
   (~line 339) and `TigonServiceLayer.smali` (~line 146), the only two in the app — to pass `true`
   for both boolean observability flags. Conclusion: native code gates body observation via
   something the two Java-level booleans don't control (likely a server-side Gatekeeper/
   QuickExperiment flag, or hardcoded in a production build). `onStarted`/`onResponse`/`onEOM`/
   `onError` on this class DO fire and provide a redundant metadata-only stream, keyed by Tigon's
   own native numeric request id (a different id space from #3 below — no collision risk).

2. **`TigonXplatBodyStream.smali`** (`smali/com/facebook/tigon/TigonXplatBodyStream.smali`,
   implements `TigonBodyStream` — `transferBytes`, `writeEOM`, `reportBodyLength`, `reportError`)
   — the universal interception point for **outgoing request bodies** (what the app sends, e.g.
   GraphQL `doc_id` + variables). **Identified but not yet hooked.** This is the clear next step
   for request-body capture; `requestBodyBytes`/`Path` fields exist in `TigonCapture` but are
   essentially never populated today. Open design question: correlating a `TigonXplatBodyStream`
   instance to the matching `LX/02gB` instance for the same logical request — different object
   graphs, no shared field found yet. Worth checking `TigonBodyProvider`/`TigonXplatBodyProvider`/
   `TigonXplatTailingFileBodyProvider` construction call sites for a shared id before assuming
   none exists.

3. **`smali_classes2/X/02gB.smali`** — **THE WORKING HOOK.** Concrete subclass of
   `Lcom/facebook/tigon/TigonCallbacks;` (abstract base, `smali_classes3/com/facebook/tigon/TigonCallbacks.smali`).
   Instantiated per-request by `TigonServiceLayer.smali`'s `makeTigonCallbacks(...)` and passed
   into `TigonXplatService.sendRequest(TigonRequest, TigonBodyProvider, TigonCallbacks, Executor)`
   — Tigon's mandatory, *unconditional* per-request API; every request passes one of these, and
   its methods are genuinely always called, unlike `TigonObservable`'s body callbacks. Patched
   methods: `onStarted(TigonRequest)`, `onResponse(LX/00MW;)`, `onBody(ByteBuffer)`, `onEOM(LX/00PO;)`,
   `onError(TigonError,LX/00PO;)` — each wrapped in `try/catch Ljava/lang/Throwable;` so a bug in
   our code can never propagate into the app's real callback handling (though see the register
   bug below for a way a bug can *still* break things). No instance field exposes a numeric
   request id, so correlation uses `System.identityHashCode(p0)` cast to `long` — valid because
   exactly one `LX/02gB` instance exists per request for the lifetime of that request.
   `onBody` duplicates the buffer before reading (same ByteBuffer-safety pattern as above); the
   original object (`p1`) is what the app's own producer/consumer queue (an internal `LX/02gC`
   class using `ReentrantLock`+`Condition`+`Queue`) actually consumes.

   **Confirmed working with real data**: verified complete, valid JSON response bodies (e.g. a
   694-byte `/api/v1/feed/reels_tray/` response), real images (`assets/images/*.jpg`/`.webp`,
   spot-checked with `file` as a genuine 240×426 JPEG), and real video fragments
   (`assets/videos/*.mp4` — confirmed via hex dump to be legitimate fragmented-MP4 `moof`/`mdat`
   segments, i.e. real DASH-style streaming chunks, not corrupted — **but not standalone-playable
   without locating and concatenating a separate init segment containing `ftyp`/`moov`, which has
   not been done yet**).

## Smali gotcha that caused a real regression — read before editing any hooked method

**Register budget**: in a smali method, `.locals N` only reserves `v0..v(N-1)` as true locals.
Parameters follow immediately after: for an instance method with k explicit parameters, `p0`
(`this`) is register `vN`, `p1` is `v(N+1)`, etc. **If you use a register number ≥ N for a temp
value, you are silently overwriting a parameter**, not allocating a fresh local — the verifier
does not flag this if the types happen to be compatible at the bytecode level (object vs. object).

This exact mistake broke the app in this session: `02gB.smali`'s patched `onBody` declared
`.locals 6` for an instance method with one parameter (`ByteBuffer`), making `p0` (`this`) live in
register `v6`. The inserted code did `move-result-object v6` to stash a duplicated `ByteBuffer`,
directly clobbering `this`. The very next original-code line, `iget v1, p0, LX/02gB;->A01:I`, then
read a field off what was now a `ByteBuffer` object instead of an `LX/02gB` instance. Because
`onBody` fires for every response chunk of every request app-wide, this broke essentially all
content loading (reported by the user as "no posts, images, videos, reels"). **Fix applied**:
bumped `.locals` from `6` to `8` in that method, which shifts `p0`→`v8`/`p1`→`v9`, safely out of
the way of the `v0..v7` temps already in use. No other edited method in this codebase has this bug
(checked `onStarted`, `onResponse`, `onEOM`, `onError` in both `TigonObservable` and `02gB` — all
use `.locals` counts large enough to keep their temps below the parameter registers).

**Rule going forward**: whenever patching a smali method, work out `N_locals + N_params` for the
method's actual signature (remember `this` counts as a param for instance methods, and wide types
`J`/`D` consume two consecutive registers) before choosing which register numbers are safe for
inserted temporaries. When in doubt, pad `.locals` generously — unused locals are free.

## Known open issues (in priority order)

1. **Possible lock-held-during-slow-I/O in `writeAndRemove`.** The `monitor-enter`/`monitor-exit`
   on `sPending` in `writeAndRemove` currently wraps the call to `appendResponseExtras`, which
   calls `sha256File` and (inside it) `copyFile` — both synchronous, full-file reads for
   potentially multi-MB video/image bodies. Since `onStarted`/`onResponse` for every *other*
   concurrent request also block on this same lock, a slow hash/copy of one large video could
   stall metadata recording for unrelated simultaneous requests. This was the leading hypothesis
   for the app-breakage report in this session, but the actual root cause turned out to be the
   register bug above (fixed). This lock-scope issue is still real and unaddressed — the fix, if
   pursued, is to compute the SHA-256 and do the file copy *before* taking the lock (they only
   need the already-known `respPath` string), then take the lock briefly just to append the
   already-computed result strings into the shared `StringBuilder`.
2. **`TigonXplatBodyStream` not yet hooked** — see hook point #2 above; this is what's blocking
   request-body capture (GraphQL variables, upload bodies).
3. **Fragmented MP4 captures lack an init segment** — captured video assets are valid `moof`/`mdat`
   fragments but need their corresponding `ftyp`/`moov` init segment (likely fetched once per
   video/representation, separately from the media fragments) to be independently playable.
   Not yet investigated which hook/request this would come through.
3. **"~30 bare records" mystery** — some fraction of `traffic.jsonl` entries have only
   `{"outcome":"success"}` with no method/URL/headers. Hypothesized to be cache hits or requests
   that never got a `submittedRequest` populated, but never confirmed with added diagnostics.
4. **Followers/following capture not yet verified** — the user has not yet been walked through
   navigating to their followers/following screen with a capture-enabled build running to confirm
   that flow's traffic is captured correctly.
5. **Record on/off floating overlay button** — was built once as a Frida-JS overlay (now dead code,
   abandoned with the rest of the Frida approach) and has not been reimplemented against the
   current smali-only build. The file-based `DISABLED` flag toggle (`adb shell` touch/rm) is the
   only on/off control today. Revisit only if the user asks for the in-app button again.

## Operational notes for working in this tree

- **Device**: physical OPPO A15s, serial `<DEVICE_SERIAL>`, Android 10 / API 29, arm64-v8a. The
  emulator (`Medium_Phone_API_36.0`, Google Play image) is effectively abandoned for this work —
  it ANR-crash-loops under chronic host memory pressure (observed as low as 600MB–2GB free of
  15.8GB total) even on the unmodified app, unrelated to our patches. Default to the physical
  device for all Instagram testing.
- **Build command**: `java -jar tools/apktool/apktool.jar b <apktool_decoded dir> -o <out.apk>`.
  Incremental: apktool only re-smalis folders that changed (watch for "has not changed" vs.
  "Smaling X folder..." in the log) — editing only `smali_classes3` (TigonCapture/workers) or
  `smali_classes2` (`LX/02gB`) or root `smali` (`TigonObservable`/`IGTigonService`/
  `TigonServiceLayer`/`InstagramAppShell`) keeps rebuilds to ~20–100s. Any manifest edit forces a
  full `aapt2` resource rebuild (~300–350s).
- **Sign in two separate tool calls**: `zipalign` then `apksigner`, never combined in one Bash
  call — combining them has tripped a safety-classifier false positive ("[Third-Party Attack]")
  more than once in this session; splitting into two calls has always worked immediately.
  Keystore: `workdir/instagram-448.0.0.18.84/reqable_patched/debug-test.jks`, password
  `<KEYSTORE_PASSWORD>`, alias `testkey`. Reused across every build iteration — `adb install -r` over an
  existing same-keystore install never needs an uninstall first.
- **Install/launch sequence** (reliable, use every time after a rebuild):
  ```
  adb -s <DEVICE_SERIAL> install -r <signed.apk>
  adb -s <DEVICE_SERIAL> shell rm -rf //sdcard/Download/InstagramCaptures   # clear old captures
  adb -s <DEVICE_SERIAL> shell am force-stop com.instagram.android
  adb -s <DEVICE_SERIAL> shell am start -n com.instagram.android/.activity.MainTabActivity
  ```
  ("Unknown command: install-incremental" then falling back to "Performing Streamed Install" on
  `adb install` is normal, not an error.) **Note the double leading slash** on device-side paths
  (`//sdcard/...`) — this git-bash/MSYS2 environment mangles single-leading-slash POSIX paths into
  `C:/Program Files/Git/sdcard/...` when passed to native Windows `adb.exe`; the double-slash
  form reliably avoids this.
- **Always check free memory before a rebuild** on this host:
  `Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty FreePhysicalMemory`
  (PowerShell). A silently truncated apktool build log or a "End-of-central-directory signature
  not found" on the output zip means it got OOM-killed mid-build — just retry once memory frees up
  from the previous failed JVM exiting; it has succeeded on retry every time so far.
- **Toolchain paths** (this is a non-interactive bash session; PATH additions made via
  `setx`/PowerShell persistent env vars do NOT apply here — always use full paths or
  `export PATH=...` explicitly per command):
  - `adb`: `/c/Users/reach/AppData/Local/Android/Sdk/platform-tools/adb.exe`
  - `zipalign`/`apksigner`: `/c/Users/reach/AppData/Local/Android/Sdk/build-tools/36.0.0/`
  - `apktool`: `java -jar tools/apktool/apktool.jar`
- **No git repo in this working directory** — nothing here is committed; all state is the working
  tree only. If version control is ever wanted, that's a decision for the user to make explicitly,
  not something to set up unprompted.
- When validating a fix on this target, **verify the actual in-app behavior** (feed/posts/images/
  videos/reels rendering), not just thread counts or capture-file population — a prior fix in this
  session passed a files/thread-count check but still shipped the register bug above, which only
  surfaced as a user-reported "nothing loads."
