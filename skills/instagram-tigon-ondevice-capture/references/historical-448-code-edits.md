# Historical 448.0.0.18.84 code edit ledger

> **Provenance:** Extracted directly from the user-provided session JSONL `Edit` tool inputs, in actual chronological order. These are **historical version-specific examples, not a ready-to-apply patch for another Instagram APK**. Avoid using raw obfuscated names, offsets, or register numbers on a different build.

The restored helper engine is in `assets/historical-smali/` (`TigonCapture.smali`, `TigonBodyWorker.smali`, and `TigonWriteWorker.smali`). Those helper sources were reconstructed by starting with the transcript `Write` entries and applying each later `Edit` in sequence; all string replacements matched.

## How to port an entry

Read this ledger only after `scripts/scan_tigon.py` has located the callback class for the **current** APK. Check method descriptors, register slots, catch handlers, and control flow on the new version. Copy behavior, not literal registers or strings. Audit with `scripts/audit_smali.py`, compile, and run the app regression suite.

## Transcript action 3371: `TigonObservable.smali`

Observer request-metadata lifecycle hook (worked).

**Before** (matching anchor/source fragment):

```smali
.method private onStarted(Lcom/facebook/tigon/tigonobserver/TigonObserverData;)V
    .locals 1

    .line 0
    const/4 v0, 0x2
```

**After** (recorded edit; action 4337 uses the final corrected local-register count):

```smali
.method private onStarted(Lcom/facebook/tigon/tigonobserver/TigonObserverData;)V
    .locals 10

    :try_start_cap_started
    invoke-virtual {p1}, Lcom/facebook/tigon/tigonobserver/TigonObserverData;->requestId()J

    move-result-wide v1

    invoke-virtual {p1}, Lcom/facebook/tigon/tigonobserver/TigonObserverData;->submittedRequest()Lcom/facebook/tigon/iface/TigonRequest;

    move-result-object v3

    if-eqz v3, :cond_cap_started_nullreq

    invoke-virtual {v3}, Lcom/facebook/tigon/iface/TigonRequest;->method()Ljava/lang/String;

    move-result-object v4

    invoke-virtual {v3}, Lcom/facebook/tigon/iface/TigonRequest;->url()Ljava/lang/String;

    move-result-object v5

    invoke-virtual {v3}, Lcom/facebook/tigon/iface/TigonRequest;->headers()Ljava/util/Map;

    move-result-object v6

    invoke-static {v1, v2, v4, v5, v6}, Lcom/instagram/app/TigonCapture;->onStarted(JLjava/lang/String;Ljava/lang/String;Ljava/util/Map;)V

    :cond_cap_started_nullreq
    :try_end_cap_started
    .catch Ljava/lang/Throwable; {:try_start_cap_started .. :try_end_cap_started} :catch_cap_started

    goto :cap_started_cont

    :catch_cap_started
    move-exception v0

    :cap_started_cont
    .line 0
    const/4 v0, 0x2
```

## Transcript action 3375: `TigonObservable.smali`

Observer status/response-headers hook (worked).

**Before** (matching anchor/source fragment):

```smali
.method private onResponse(Lcom/facebook/tigon/tigonobserver/TigonObserverData;)V
    .locals 1

    .line 0
    const/4 v0, 0x3
```

**After** (recorded edit; action 4337 uses the final corrected local-register count):

```smali
.method private onResponse(Lcom/facebook/tigon/tigonobserver/TigonObserverData;)V
    .locals 10

    :try_start_cap_resp
    invoke-virtual {p1}, Lcom/facebook/tigon/tigonobserver/TigonObserverData;->requestId()J

    move-result-wide v1

    invoke-virtual {p1}, Lcom/facebook/tigon/tigonobserver/TigonObserverData;->response()LX/00MW;

    move-result-object v3

    if-eqz v3, :cond_cap_resp_null

    iget v4, v3, LX/00MW;->A00:I

    iget-object v5, v3, LX/00MW;->A01:Ljava/util/Map;

    invoke-static {v1, v2, v4, v5}, Lcom/instagram/app/TigonCapture;->onResponse(JILjava/util/Map;)V

    :cond_cap_resp_null
    :try_end_cap_resp
    .catch Ljava/lang/Throwable; {:try_start_cap_resp .. :try_end_cap_resp} :catch_cap_resp

    goto :cap_resp_cont

    :catch_cap_resp
    move-exception v0

    :cap_resp_cont
    .line 0
    const/4 v0, 0x3
```

## Transcript action 3398: `TigonObservable.smali`

Observer EOM hook, matched the actual `const/4` instruction found after first attempt used a different anchor.

**Before** (matching anchor/source fragment):

```smali
.method private onEOM(Lcom/facebook/tigon/tigonobserver/TigonObserverData;)V
    .locals 1

    .line 0
    const/4 v0, 0x4
```

**After** (recorded edit; action 4337 uses the final corrected local-register count):

```smali
.method private onEOM(Lcom/facebook/tigon/tigonobserver/TigonObserverData;)V
    .locals 10

    :try_start_cap_eom
    invoke-virtual {p1}, Lcom/facebook/tigon/tigonobserver/TigonObserverData;->requestId()J

    move-result-wide v1

    invoke-static {v1, v2}, Lcom/instagram/app/TigonCapture;->onEOM(J)V
    :try_end_cap_eom
    .catch Ljava/lang/Throwable; {:try_start_cap_eom .. :try_end_cap_eom} :catch_cap_eom

    goto :cap_eom_cont

    :catch_cap_eom
    move-exception v0

    :cap_eom_cont
    .line 0
    const/4 v0, 0x4
```

## Transcript action 3406: `TigonObservable.smali`

Observer error hook.

**Before** (matching anchor/source fragment):

```smali
.method private onError(Lcom/facebook/tigon/tigonobserver/TigonObserverData;)V
    .locals 1

    .line 0
    const/4 v0, 0x5
```

**After** (recorded edit; action 4337 uses the final corrected local-register count):

```smali
.method private onError(Lcom/facebook/tigon/tigonobserver/TigonObserverData;)V
    .locals 10

    :try_start_cap_err
    invoke-virtual {p1}, Lcom/facebook/tigon/tigonobserver/TigonObserverData;->requestId()J

    move-result-wide v1

    invoke-virtual {p1}, Lcom/facebook/tigon/tigonobserver/TigonObserverData;->error()Lcom/facebook/tigon/TigonError;

    move-result-object v3

    const-string v4, ""

    if-eqz v3, :cond_cap_err_noerr

    invoke-virtual {v3}, Ljava/lang/Object;->toString()Ljava/lang/String;

    move-result-object v4

    :cond_cap_err_noerr
    invoke-static {v1, v2, v4}, Lcom/instagram/app/TigonCapture;->onError(JLjava/lang/String;)V
    :try_end_cap_err
    .catch Ljava/lang/Throwable; {:try_start_cap_err .. :try_end_cap_err} :catch_cap_err

    goto :cap_err_cont

    :catch_cap_err
    move-exception v0

    :cap_err_cont
    .line 0
    const/4 v0, 0x5
```

## Transcript action 3416: `TigonObservable.smali`

Observer download-body hook (compiled but never observed firing on test traffic).

**Before** (matching anchor/source fragment):

```smali
.method private onDownloadBody(Lcom/facebook/tigon/tigonobserver/interfaces/TigonBodyObservation;)V
    .locals 1

    .line 0
    const/16 v0, 0x8
```

**After** (recorded edit; action 4337 uses the final corrected local-register count):

```smali
.method private onDownloadBody(Lcom/facebook/tigon/tigonobserver/interfaces/TigonBodyObservation;)V
    .locals 10

    :try_start_cap_dl
    iget-wide v1, p1, Lcom/facebook/tigon/tigonobserver/interfaces/TigonBodyObservation;->mRequestId:J

    iget-boolean v3, p1, Lcom/facebook/tigon/tigonobserver/interfaces/TigonBodyObservation;->mHasBody:Z

    const/4 v4, 0x0

    if-eqz v3, :cond_cap_dl_nobody

    invoke-virtual {p1}, Lcom/facebook/tigon/tigonobserver/interfaces/TigonBodyObservation;->body()Ljava/nio/ByteBuffer;

    move-result-object v4

    :cond_cap_dl_nobody
    const/4 v5, 0x0

    invoke-static {v1, v2, v5, v4, v3}, Lcom/instagram/app/TigonCapture;->onBody(JZLjava/nio/ByteBuffer;Z)V
    :try_end_cap_dl
    .catch Ljava/lang/Throwable; {:try_start_cap_dl .. :try_end_cap_dl} :catch_cap_dl

    goto :cap_dl_cont

    :catch_cap_dl
    move-exception v0

    :cap_dl_cont
    .line 0
    const/16 v0, 0x8
```

## Transcript action 3420: `TigonObservable.smali`

Observer upload-body hook (compiled but never observed firing on test traffic).

**Before** (matching anchor/source fragment):

```smali
.method private onUploadBody(Lcom/facebook/tigon/tigonobserver/interfaces/TigonBodyObservation;)V
    .locals 1

    .line 0
    const/4 v0, 0x7
```

**After** (recorded edit; action 4337 uses the final corrected local-register count):

```smali
.method private onUploadBody(Lcom/facebook/tigon/tigonobserver/interfaces/TigonBodyObservation;)V
    .locals 10

    :try_start_cap_ul
    iget-wide v1, p1, Lcom/facebook/tigon/tigonobserver/interfaces/TigonBodyObservation;->mRequestId:J

    iget-boolean v3, p1, Lcom/facebook/tigon/tigonobserver/interfaces/TigonBodyObservation;->mHasBody:Z

    const/4 v4, 0x0

    if-eqz v3, :cond_cap_ul_nobody

    invoke-virtual {p1}, Lcom/facebook/tigon/tigonobserver/interfaces/TigonBodyObservation;->body()Ljava/nio/ByteBuffer;

    move-result-object v4

    :cond_cap_ul_nobody
    const/4 v5, 0x1

    invoke-static {v1, v2, v5, v4, v3}, Lcom/instagram/app/TigonCapture;->onBody(JZLjava/nio/ByteBuffer;Z)V
    :try_end_cap_ul
    .catch Ljava/lang/Throwable; {:try_start_cap_ul .. :try_end_cap_ul} :catch_cap_ul

    goto :cap_ul_cont

    :catch_cap_ul
    move-exception v0

    :cap_ul_cont
    .line 0
    const/4 v0, 0x7
```

## Transcript action 3588: `IGTigonService.smali`

First observer-constructor boolean call site (body hook still did not fire).

**Before** (matching anchor/source fragment):

```smali
    new-instance v5, Lcom/facebook/tigon/tigonobserver/TigonObservable;

    .line 120
    .line 121
    move-object v6, v3

    .line 122
    move v7, v4

    .line 123
    move v8, v4

    .line 124
    move-object v9, v2
```

**After** (recorded edit; action 4337 uses the final corrected local-register count):

```smali
    new-instance v5, Lcom/facebook/tigon/tigonobserver/TigonObservable;

    .line 120
    .line 121
    move-object v6, v3

    .line 122
    const/4 v7, 0x1

    .line 123
    const/4 v8, 0x1

    .line 124
    move-object v9, v2
```

## Transcript action 3612: `TigonServiceLayer.smali`

Second observer-constructor boolean call site (body hook still did not fire).

**Before** (matching anchor/source fragment):

```smali
    new-array v9, v5, [LX/03oj;

    .line 144
    .line 145
    new-instance v3, Lcom/facebook/tigon/tigonobserver/TigonObservable;

    .line 146
    .line 147
    invoke-direct/range {v3 .. v9}, Lcom/facebook/tigon/tigonobserver/TigonObservable;-><init>(Lcom/facebook/tigon/TigonXplatService;ZZLjava/util/concurrent/Executor;[LX/03oi;[LX/03oj;)V
```

**After** (recorded edit; action 4337 uses the final corrected local-register count):

```smali
    new-array v9, v5, [LX/03oj;

    .line 144
    .line 145
    new-instance v3, Lcom/facebook/tigon/tigonobserver/TigonObservable;

    .line 146
    const/4 v5, 0x1

    const/4 v6, 0x1

    .line 147
    invoke-direct/range {v3 .. v9}, Lcom/facebook/tigon/tigonobserver/TigonObservable;-><init>(Lcom/facebook/tigon/TigonXplatService;ZZLjava/util/concurrent/Executor;[LX/03oi;[LX/03oj;)V
```

## Transcript action 4337: `02gB.smali`

Breakthrough: concrete per-request TigonCallbacks.onBody(ByteBuffer) hook. The first version with `.locals 6` was **WRONG**: `v6` aliased `p0`. The final later patch changed it to `.locals 8`. The new snippet below includes the corrected `.locals 8`.

**Before** (matching anchor/source fragment):

```smali
.method public final onBody(Ljava/nio/ByteBuffer;)V
    .locals 3

    const/4 v0, 0x0

    invoke-static {p1, v0}, LX/05Ue;->A0U(Ljava/lang/Object;I)V

    iget v1, p0, LX/02gB;->A01:I
```

**After** (recorded edit; action 4337 uses the final corrected local-register count):

```smali
.method public final onBody(Ljava/nio/ByteBuffer;)V
    .locals 8

    :try_start_cap_cb_body
    invoke-static {p0}, Ljava/lang/System;->identityHashCode(Ljava/lang/Object;)I

    move-result v4

    int-to-long v4, v4

    invoke-virtual {p1}, Ljava/nio/ByteBuffer;->duplicate()Ljava/nio/ByteBuffer;

    move-result-object v6

    const/4 v3, 0x0

    const/4 v2, 0x1

    invoke-static {v4, v5, v3, v6, v2}, Lcom/instagram/app/TigonCapture;->onBody(JZLjava/nio/ByteBuffer;Z)V
    :try_end_cap_cb_body
    .catch Ljava/lang/Throwable; {:try_start_cap_cb_body .. :try_end_cap_cb_body} :catch_cap_cb_body

    goto :cap_cb_body_cont

    :catch_cap_cb_body
    move-exception v2

    :cap_cb_body_cont
    const/4 v0, 0x0

    invoke-static {p1, v0}, LX/05Ue;->A0U(Ljava/lang/Object;I)V

    iget v1, p0, LX/02gB;->A01:I
```

## Transcript action 4342: `02gB.smali`

Actual callback onStarted; method/url/header getters are version-dependent.

**Before** (matching anchor/source fragment):

```smali
.method public final onStarted(Lcom/facebook/tigon/iface/TigonRequest;)V
    .locals 3

    const/4 v0, 0x0

    invoke-static {p1, v0}, LX/05Ue;->A0U(Ljava/lang/Object;I)V

    iput-object p1, p0, LX/02gB;->A03:Lcom/facebook/tigon/iface/TigonRequest;
```

**After** (recorded edit; action 4337 uses the final corrected local-register count):

```smali
.method public final onStarted(Lcom/facebook/tigon/iface/TigonRequest;)V
    .locals 8

    :try_start_cap_cb_started
    invoke-static {p0}, Ljava/lang/System;->identityHashCode(Ljava/lang/Object;)I

    move-result v5

    int-to-long v5, v5

    invoke-virtual {p1}, Lcom/facebook/tigon/iface/TigonRequest;->method()Ljava/lang/String;

    move-result-object v4

    invoke-virtual {p1}, Lcom/facebook/tigon/iface/TigonRequest;->url()Ljava/lang/String;

    move-result-object v3

    invoke-virtual {p1}, Lcom/facebook/tigon/iface/TigonRequest;->headers()Ljava/util/Map;

    move-result-object v7

    invoke-static {v5, v6, v4, v3, v7}, Lcom/instagram/app/TigonCapture;->onStarted(JLjava/lang/String;Ljava/lang/String;Ljava/util/Map;)V
    :try_end_cap_cb_started
    .catch Ljava/lang/Throwable; {:try_start_cap_cb_started .. :try_end_cap_cb_started} :catch_cap_cb_started

    goto :cap_cb_started_cont

    :catch_cap_cb_started
    move-exception v3

    :cap_cb_started_cont
    const/4 v0, 0x0

    invoke-static {p1, v0}, LX/05Ue;->A0U(Ljava/lang/Object;I)V

    iput-object p1, p0, LX/02gB;->A03:Lcom/facebook/tigon/iface/TigonRequest;
```

## Transcript action 4353: `02gB.smali`

Actual callback onResponse; `LX/00MW` is version-specific.

**Before** (matching anchor/source fragment):

```smali
.method public final onResponse(LX/00MW;)V
    .locals 2

    const/4 v0, 0x0

    invoke-static {p1, v0}, LX/05Ue;->A0U(Ljava/lang/Object;I)V

    const/16 v1, 0x17
```

**After** (recorded edit; action 4337 uses the final corrected local-register count):

```smali
.method public final onResponse(LX/00MW;)V
    .locals 8

    :try_start_cap_cb_resp
    invoke-static {p0}, Ljava/lang/System;->identityHashCode(Ljava/lang/Object;)I

    move-result v5

    int-to-long v5, v5

    iget v4, p1, LX/00MW;->A00:I

    iget-object v7, p1, LX/00MW;->A01:Ljava/util/Map;

    invoke-static {v5, v6, v4, v7}, Lcom/instagram/app/TigonCapture;->onResponse(JILjava/util/Map;)V
    :try_end_cap_cb_resp
    .catch Ljava/lang/Throwable; {:try_start_cap_cb_resp .. :try_end_cap_cb_resp} :catch_cap_cb_resp

    goto :cap_cb_resp_cont

    :catch_cap_cb_resp
    move-exception v4

    :cap_cb_resp_cont
    const/4 v0, 0x0

    invoke-static {p1, v0}, LX/05Ue;->A0U(Ljava/lang/Object;I)V

    const/16 v1, 0x17
```

## Transcript action 4358: `02gB.smali`

Actual callback onEOM.

**Before** (matching anchor/source fragment):

```smali
.method public final onEOM(LX/00PO;)V
    .locals 3

    const/4 v0, 0x0

    invoke-static {p1, v0}, LX/05Ue;->A0U(Ljava/lang/Object;I)V

    iget-object v0, p0, LX/02gB;->A0H:LX/0FJl;
```

**After** (recorded edit; action 4337 uses the final corrected local-register count):

```smali
.method public final onEOM(LX/00PO;)V
    .locals 5

    :try_start_cap_cb_eom
    invoke-static {p0}, Ljava/lang/System;->identityHashCode(Ljava/lang/Object;)I

    move-result v3

    int-to-long v3, v3

    invoke-static {v3, v4}, Lcom/instagram/app/TigonCapture;->onEOM(J)V
    :try_end_cap_cb_eom
    .catch Ljava/lang/Throwable; {:try_start_cap_cb_eom .. :try_end_cap_cb_eom} :catch_cap_cb_eom

    goto :cap_cb_eom_cont

    :catch_cap_cb_eom
    move-exception v3

    :cap_cb_eom_cont
    const/4 v0, 0x0

    invoke-static {p1, v0}, LX/05Ue;->A0U(Ljava/lang/Object;I)V

    iget-object v0, p0, LX/02gB;->A0H:LX/0FJl;
```

## Transcript action 4363: `02gB.smali`

Actual callback onError.

**Before** (matching anchor/source fragment):

```smali
.method public final onError(Lcom/facebook/tigon/TigonError;LX/00PO;)V
    .locals 3

    invoke-static {p1}, LX/05Ue;->A0Q(Ljava/lang/Object;)V
```

**After** (recorded edit; action 4337 uses the final corrected local-register count):

```smali
.method public final onError(Lcom/facebook/tigon/TigonError;LX/00PO;)V
    .locals 7

    :try_start_cap_cb_err
    invoke-static {p0}, Ljava/lang/System;->identityHashCode(Ljava/lang/Object;)I

    move-result v5

    int-to-long v5, v5

    const-string v4, ""

    if-eqz p1, :cond_cap_cb_err_noerr

    invoke-virtual {p1}, Ljava/lang/Object;->toString()Ljava/lang/String;

    move-result-object v4

    :cond_cap_cb_err_noerr
    invoke-static {v5, v6, v4}, Lcom/instagram/app/TigonCapture;->onError(JLjava/lang/String;)V
    :try_end_cap_cb_err
    .catch Ljava/lang/Throwable; {:try_start_cap_cb_err .. :try_end_cap_cb_err} :catch_cap_cb_err

    goto :cap_cb_err_cont

    :catch_cap_cb_err
    move-exception v4

    :cap_cb_err_cont
    invoke-static {p1}, LX/05Ue;->A0Q(Ljava/lang/Object;)V
```

## Transcript action 4472: `TigonCapture.smali`

Preserve the computed SHA-256 in `v6` rather than reusing `v0`.

**Before** (matching anchor/source fragment):

```smali
.method private static appendResponseExtras(Ljava/lang/StringBuilder;JLjava/lang/String;)V
    .locals 6

    if-eqz p3, :cond_end

    invoke-static {p3}, Lcom/instagram/app/TigonCapture;->sha256File(Ljava/lang/String;)Ljava/lang/String;

    move-result-object v0

    if-eqz v0, :cond_nosha

    const-string v1, "responseBodySha256"

    invoke-static {p0, v1, v0}, Lcom/instagram/app/TigonCapture;->appendField(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/String;)V

    :cond_nosha
```

**After** (recorded edit; action 4337 uses the final corrected local-register count):

```smali
.method private static appendResponseExtras(Ljava/lang/StringBuilder;JLjava/lang/String;)V
    .locals 7

    if-eqz p3, :cond_end

    invoke-static {p3}, Lcom/instagram/app/TigonCapture;->sha256File(Ljava/lang/String;)Ljava/lang/String;

    move-result-object v6

    if-eqz v6, :cond_nosha

    const-string v1, "responseBodySha256"

    invoke-static {p0, v1, v6}, Lcom/instagram/app/TigonCapture;->appendField(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/String;)V

    :cond_nosha
```

## Transcript action 4477: `TigonCapture.smali`

Use `<sha256>.<extension>` rather than a `number/extension` directory.

**Before** (matching anchor/source fragment):

```smali
    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v4, p1, p2}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;

    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v4, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
```

**After** (recorded edit; action 4337 uses the final corrected local-register count):

```smali
    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    if-eqz v6, :cond_namefallback

    invoke-virtual {v4, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    goto :cond_namedone

    :cond_namefallback
    invoke-virtual {v4, p1, p2}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;

    :cond_namedone
    const-string v5, "."

    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v4, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
```

## Transcript action 4595: `TigonCapture.smali`

Introduce bounded thread COUNT with an executor; the fixed pool still has an unbounded queue and must be redesigned for strict bounded buffers.

**Before** (matching anchor/source fragment):

```smali
.field private static final sBodyPaths:Ljava/util/HashMap;


# direct methods
.method static constructor <clinit>()V
    .locals 1
```

**After** (recorded edit; action 4337 uses the final corrected local-register count):

```smali
.field private static final sBodyPaths:Ljava/util/HashMap;

.field private static final sExecutor:Ljava/util/concurrent/ExecutorService;


# direct methods
.method static constructor <clinit>()V
    .locals 1
```

## Transcript action 4605: `TigonCapture.smali`

Initialize the static executor with two threads.

**Before** (matching anchor/source fragment):

```smali
    sput-object v0, Lcom/instagram/app/TigonCapture;->sBodyPaths:Ljava/util/HashMap;

    return-void
.end method
```

**After** (recorded edit; action 4337 uses the final corrected local-register count):

```smali
    sput-object v0, Lcom/instagram/app/TigonCapture;->sBodyPaths:Ljava/util/HashMap;

    const/4 v0, 0x2

    invoke-static {v0}, Ljava/util/concurrent/Executors;->newFixedThreadPool(I)Ljava/util/concurrent/ExecutorService;

    move-result-object v0

    sput-object v0, Lcom/instagram/app/TigonCapture;->sExecutor:Ljava/util/concurrent/ExecutorService;

    return-void
.end method
```

## Transcript action 4617: `TigonCapture.smali`

Use the shared executor for body and finalize tasks instead of a new OS thread per chunk. WARNING: two workers can reorder finalization vs body writing unless sequencing is enforced.

**Before** (matching anchor/source fragment):

```smali
    new-instance v1, Lcom/instagram/app/TigonBodyWorker;

    invoke-direct {v1, p0, p1, p2, v0}, Lcom/instagram/app/TigonBodyWorker;-><init>(JZ[B)V

    new-instance v2, Ljava/lang/Thread;

    invoke-direct {v2, v1}, Ljava/lang/Thread;-><init>(Ljava/lang/Runnable;)V

    invoke-virtual {v2}, Ljava/lang/Thread;->start()V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    :cond_skip
    return-void

    :catch_0
    move-exception v0

    return-void
.end method

.method private static spawnWriteWorker(J)V
    .locals 2

    new-instance v0, Lcom/instagram/app/TigonWriteWorker;

    invoke-direct {v0, p0, p1}, Lcom/instagram/app/TigonWriteWorker;-><init>(J)V

    new-instance v1, Ljava/lang/Thread;

    invoke-direct {v1, v0}, Ljava/lang/Thread;-><init>(Ljava/lang/Runnable;)V

    invoke-virtual {v1}, Ljava/lang/Thread;->start()V

    return-void
.end method
```

**After** (recorded edit; action 4337 uses the final corrected local-register count):

```smali
    new-instance v1, Lcom/instagram/app/TigonBodyWorker;

    invoke-direct {v1, p0, p1, p2, v0}, Lcom/instagram/app/TigonBodyWorker;-><init>(JZ[B)V

    sget-object v2, Lcom/instagram/app/TigonCapture;->sExecutor:Ljava/util/concurrent/ExecutorService;

    invoke-interface {v2, v1}, Ljava/util/concurrent/ExecutorService;->execute(Ljava/lang/Runnable;)V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    :cond_skip
    return-void

    :catch_0
    move-exception v0

    return-void
.end method

.method private static spawnWriteWorker(J)V
    .locals 2

    new-instance v0, Lcom/instagram/app/TigonWriteWorker;

    invoke-direct {v0, p0, p1}, Lcom/instagram/app/TigonWriteWorker;-><init>(J)V

    sget-object v1, Lcom/instagram/app/TigonCapture;->sExecutor:Ljava/util/concurrent/ExecutorService;

    invoke-interface {v1, v0}, Ljava/util/concurrent/ExecutorService;->execute(Ljava/lang/Runnable;)V

    return-void
.end method
```

## Transcript action 4753: `02gB.smali`

Last known regression fix, `.locals 6` → `.locals 8` to stop writing into p0 alias. Built, signed, installed; UI feed recovery not confirmed after this installation.

**Before** (matching anchor/source fragment):

```smali
.method public final onBody(Ljava/nio/ByteBuffer;)V
    .locals 6
```

**After** (recorded edit; action 4337 uses the final corrected local-register count):

```smali
.method public final onBody(Ljava/nio/ByteBuffer;)V
    .locals 8
```

## Exact one-line crash regression fix

The working build initially became nonfunctional for posts, images, reels, and videos. Diagnostic inspection found the original injected `onBody` used `.locals 6` while writing `move-result-object v6`; in an instance method, `p0` was the same physical register as `v6`. The transcript changed `.locals 6` to `.locals 8`, then successfully rebuilt, aligned, signed and installed the APK. **There was no subsequent confirmation in the export that UI rendering recovered.**

## Why this ledger is not a general-purpose patch

- Obfuscation changes class names (`LX/02gB`, `LX/00MW`, `LX/05Ue`) and field names between releases.
- The same method name might represent another internal stack or carry different parameters on another release.
- The original source still has known hardening gaps: unbounded executor queue, questionable cross-thread ordering, shared lock during hash/file copy, public Download folder raw bodies, missing request-body path, no complete video assembly.
- Verify device/app stability and raw-body privacy before any distribution; never claim the last build was fully verified.
