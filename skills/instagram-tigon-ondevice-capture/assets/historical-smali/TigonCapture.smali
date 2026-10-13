.class public Lcom/instagram/app/TigonCapture;
.super Ljava/lang/Object;
.source "TigonCapture.java"


# static fields
.field private static final sPending:Ljava/util/HashMap;

.field private static final sOpenStreams:Ljava/util/HashMap;

.field private static final sByteCounts:Ljava/util/HashMap;

.field private static final sPreviews:Ljava/util/HashMap;

.field private static final sContentType:Ljava/util/HashMap;

.field private static final sBodyPaths:Ljava/util/HashMap;

.field private static final sExecutor:Ljava/util/concurrent/ExecutorService;


# direct methods
.method static constructor <clinit>()V
    .locals 1

    new-instance v0, Ljava/util/HashMap;

    invoke-direct {v0}, Ljava/util/HashMap;-><init>()V

    sput-object v0, Lcom/instagram/app/TigonCapture;->sPending:Ljava/util/HashMap;

    new-instance v0, Ljava/util/HashMap;

    invoke-direct {v0}, Ljava/util/HashMap;-><init>()V

    sput-object v0, Lcom/instagram/app/TigonCapture;->sOpenStreams:Ljava/util/HashMap;

    new-instance v0, Ljava/util/HashMap;

    invoke-direct {v0}, Ljava/util/HashMap;-><init>()V

    sput-object v0, Lcom/instagram/app/TigonCapture;->sByteCounts:Ljava/util/HashMap;

    new-instance v0, Ljava/util/HashMap;

    invoke-direct {v0}, Ljava/util/HashMap;-><init>()V

    sput-object v0, Lcom/instagram/app/TigonCapture;->sPreviews:Ljava/util/HashMap;

    new-instance v0, Ljava/util/HashMap;

    invoke-direct {v0}, Ljava/util/HashMap;-><init>()V

    sput-object v0, Lcom/instagram/app/TigonCapture;->sContentType:Ljava/util/HashMap;

    new-instance v0, Ljava/util/HashMap;

    invoke-direct {v0}, Ljava/util/HashMap;-><init>()V

    sput-object v0, Lcom/instagram/app/TigonCapture;->sBodyPaths:Ljava/util/HashMap;

    const/4 v0, 0x2

    invoke-static {v0}, Ljava/util/concurrent/Executors;->newFixedThreadPool(I)Ljava/util/concurrent/ExecutorService;

    move-result-object v0

    sput-object v0, Lcom/instagram/app/TigonCapture;->sExecutor:Ljava/util/concurrent/ExecutorService;

    return-void
.end method

.method private static getOrCreate(J)Ljava/lang/StringBuilder;
    .locals 3

    sget-object v0, Lcom/instagram/app/TigonCapture;->sPending:Ljava/util/HashMap;

    invoke-static {p0, p1}, Ljava/lang/Long;->valueOf(J)Ljava/lang/Long;

    move-result-object v1

    invoke-virtual {v0, v1}, Ljava/util/HashMap;->get(Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v2

    check-cast v2, Ljava/lang/StringBuilder;

    if-nez v2, :cond_0

    new-instance v2, Ljava/lang/StringBuilder;

    invoke-direct {v2}, Ljava/lang/StringBuilder;-><init>()V

    const-string v0, "{"

    invoke-virtual {v2, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    sget-object v0, Lcom/instagram/app/TigonCapture;->sPending:Ljava/util/HashMap;

    invoke-virtual {v0, v1, v2}, Ljava/util/HashMap;->put(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;

    :cond_0
    return-object v2
.end method

.method private static escapeJson(Ljava/lang/String;)Ljava/lang/String;
    .locals 2

    if-nez p0, :cond_0

    const-string p0, ""

    :cond_0
    const-string v0, "\\"

    const-string v1, "\\\\"

    invoke-virtual {p0, v0, v1}, Ljava/lang/String;->replace(Ljava/lang/CharSequence;Ljava/lang/CharSequence;)Ljava/lang/String;

    move-result-object p0

    const-string v0, "\""

    const-string v1, "\\\""

    invoke-virtual {p0, v0, v1}, Ljava/lang/String;->replace(Ljava/lang/CharSequence;Ljava/lang/CharSequence;)Ljava/lang/String;

    move-result-object p0

    const-string v0, "\n"

    const-string v1, "\\n"

    invoke-virtual {p0, v0, v1}, Ljava/lang/String;->replace(Ljava/lang/CharSequence;Ljava/lang/CharSequence;)Ljava/lang/String;

    move-result-object p0

    const-string v0, "\r"

    const-string v1, "\\r"

    invoke-virtual {p0, v0, v1}, Ljava/lang/String;->replace(Ljava/lang/CharSequence;Ljava/lang/CharSequence;)Ljava/lang/String;

    move-result-object p0

    return-object p0
.end method

.method private static appendField(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/String;)V
    .locals 2

    if-nez p2, :cond_0

    const-string p2, ""

    :cond_0
    invoke-static {p2}, Lcom/instagram/app/TigonCapture;->escapeJson(Ljava/lang/String;)Ljava/lang/String;

    move-result-object v0

    const-string v1, "\""

    invoke-virtual {p0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {p0, p1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    const-string v1, "\":\""

    invoke-virtual {p0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {p0, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    const-string v1, "\","

    invoke-virtual {p0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    return-void
.end method

.method private static appendRawField(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/String;)V
    .locals 1

    const-string v0, "\""

    invoke-virtual {p0, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {p0, p1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    const-string v0, "\":"

    invoke-virtual {p0, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {p0, p2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    const-string v0, ","

    invoke-virtual {p0, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    return-void
.end method

.method private static stripTrailingComma(Ljava/lang/StringBuilder;)V
    .locals 2

    invoke-virtual {p0}, Ljava/lang/StringBuilder;->length()I

    move-result v0

    if-lez v0, :cond_0

    add-int/lit8 v1, v0, -0x1

    invoke-virtual {p0, v1}, Ljava/lang/StringBuilder;->charAt(I)C

    move-result v1

    const/16 v0, 0x2c

    if-ne v1, v0, :cond_0

    invoke-virtual {p0}, Ljava/lang/StringBuilder;->length()I

    move-result v0

    add-int/lit8 v1, v0, -0x1

    invoke-virtual {p0, v1, v0}, Ljava/lang/StringBuilder;->delete(II)Ljava/lang/StringBuilder;

    :cond_0
    return-void
.end method

.method private static isSensitiveHeader(Ljava/lang/String;)Z
    .locals 2

    if-eqz p0, :cond_false

    invoke-virtual {p0}, Ljava/lang/String;->toLowerCase()Ljava/lang/String;

    move-result-object v0

    const-string v1, "authorization"

    invoke-virtual {v0, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v1

    if-nez v1, :cond_true

    const-string v1, "cookie"

    invoke-virtual {v0, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v1

    if-nez v1, :cond_true

    const-string v1, "set-cookie"

    invoke-virtual {v0, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v1

    if-nez v1, :cond_true

    const-string v1, "x-ig-www-claim"

    invoke-virtual {v0, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v1

    if-nez v1, :cond_true

    const-string v1, "x-mid"

    invoke-virtual {v0, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v1

    if-nez v1, :cond_true

    const-string v1, "ig-u-ds-user-id"

    invoke-virtual {v0, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v1

    if-nez v1, :cond_true

    const-string v1, "x-fb-session-id"

    invoke-virtual {v0, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v1

    if-nez v1, :cond_true

    const-string v1, "proxy-authorization"

    invoke-virtual {v0, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v1

    if-nez v1, :cond_true

    :cond_false
    const/4 v1, 0x0

    return v1

    :cond_true
    const/4 v1, 0x1

    return v1
.end method

.method private static headersToJson(Ljava/util/Map;)Ljava/lang/String;
    .locals 6

    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    const-string v1, "{"

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    if-eqz p0, :cond_done

    invoke-interface {p0}, Ljava/util/Map;->entrySet()Ljava/util/Set;

    move-result-object v1

    invoke-interface {v1}, Ljava/util/Set;->iterator()Ljava/util/Iterator;

    move-result-object v1

    :loop_start
    invoke-interface {v1}, Ljava/util/Iterator;->hasNext()Z

    move-result v2

    if-eqz v2, :cond_done

    invoke-interface {v1}, Ljava/util/Iterator;->next()Ljava/lang/Object;

    move-result-object v2

    check-cast v2, Ljava/util/Map$Entry;

    invoke-interface {v2}, Ljava/util/Map$Entry;->getKey()Ljava/lang/Object;

    move-result-object v3

    invoke-virtual {v3}, Ljava/lang/Object;->toString()Ljava/lang/String;

    move-result-object v3

    invoke-interface {v2}, Ljava/util/Map$Entry;->getValue()Ljava/lang/Object;

    move-result-object v4

    const-string v5, ""

    if-eqz v4, :cond_nullval

    invoke-virtual {v4}, Ljava/lang/Object;->toString()Ljava/lang/String;

    move-result-object v5

    :cond_nullval
    invoke-static {v3}, Lcom/instagram/app/TigonCapture;->isSensitiveHeader(Ljava/lang/String;)Z

    move-result v4

    if-eqz v4, :cond_notsensitive

    const-string v5, "[REDACTED]"

    :cond_notsensitive
    invoke-static {v0, v3, v5}, Lcom/instagram/app/TigonCapture;->appendField(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/String;)V

    goto :loop_start

    :cond_done
    invoke-static {v0}, Lcom/instagram/app/TigonCapture;->stripTrailingComma(Ljava/lang/StringBuilder;)V

    const-string v1, "}"

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    return-object v0
.end method

.method private static redactBody(Ljava/lang/String;)Ljava/lang/String;
    .locals 3

    if-nez p0, :cond_0

    return-object p0

    :cond_0
    :try_start_0
    const-string v0, "(?i)(\"(?:password|access_token|accesstoken|auth_token|authtoken|session_id|sessionid|csrftoken|secret|token)\"\\s*:\\s*\")[^\"]*(\")"

    const-string v1, "$1[REDACTED]$2"

    invoke-virtual {p0, v0, v1}, Ljava/lang/String;->replaceAll(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;

    move-result-object v2
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-object v2

    :catch_0
    move-exception v0

    return-object p0
.end method

.method public static copyBytesFast(Ljava/nio/ByteBuffer;)[B
    .locals 5

    if-nez p0, :cond_0

    const/4 v0, 0x0

    return-object v0

    :cond_0
    :try_start_0
    invoke-virtual {p0}, Ljava/nio/ByteBuffer;->duplicate()Ljava/nio/ByteBuffer;

    move-result-object v0

    invoke-virtual {v0}, Ljava/nio/ByteBuffer;->remaining()I

    move-result v1

    const v2, 0x200000

    if-le v1, v2, :cond_1

    move v1, v2

    :cond_1
    new-array v3, v1, [B

    const/4 v4, 0x0

    invoke-virtual {v0, v3, v4, v1}, Ljava/nio/ByteBuffer;->get([BII)Ljava/nio/ByteBuffer;
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-object v3

    :catch_0
    move-exception v0

    const/4 v0, 0x0

    return-object v0
.end method

.method private static bytesToText([BI)Ljava/lang/String;
    .locals 3

    if-nez p0, :cond_0

    const/4 v0, 0x0

    return-object v0

    :cond_0
    :try_start_0
    new-instance v0, Ljava/lang/String;

    const/4 v1, 0x0

    const-string v2, "UTF-8"

    invoke-direct {v0, p0, v1, p1, v2}, Ljava/lang/String;-><init>([BIILjava/lang/String;)V

    invoke-static {v0}, Lcom/instagram/app/TigonCapture;->redactBody(Ljava/lang/String;)Ljava/lang/String;

    move-result-object v0
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-object v0

    :catch_0
    move-exception v0

    const-string v0, "[body decode error]"

    return-object v0
.end method

.method private static keyFor(JZ)Ljava/lang/String;
    .locals 2

    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    invoke-virtual {v0, p0, p1}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;

    if-eqz p2, :cond_0

    const-string v1, "_u"

    goto :cond_1

    :cond_0
    const-string v1, "_d"

    :cond_1
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    return-object v0
.end method

.method private static ensureBodyPath(JZ)Ljava/lang/String;
    .locals 6

    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    const-string v1, "/storage/emulated/0/Download/InstagramCaptures/"

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    if-eqz p2, :cond_0

    const-string v1, "requests/"

    goto :cond_1

    :cond_0
    const-string v1, "responses/"

    :cond_1
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v0, p0, p1}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v2

    new-instance v3, Ljava/io/File;

    invoke-direct {v3, v2}, Ljava/io/File;-><init>(Ljava/lang/String;)V

    invoke-virtual {v3}, Ljava/io/File;->exists()Z

    move-result v4

    if-nez v4, :cond_2

    invoke-virtual {v3}, Ljava/io/File;->mkdirs()Z

    :cond_2
    new-instance v4, Ljava/lang/StringBuilder;

    invoke-direct {v4}, Ljava/lang/StringBuilder;-><init>()V

    invoke-virtual {v4, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    const-string v5, "/"

    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    if-eqz p2, :cond_3

    const-string v5, "request_body.bin"

    goto :cond_4

    :cond_3
    const-string v5, "response_body.bin"

    :cond_4
    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v4}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v4

    invoke-static {p0, p1, p2}, Lcom/instagram/app/TigonCapture;->keyFor(JZ)Ljava/lang/String;

    move-result-object v5

    sget-object v0, Lcom/instagram/app/TigonCapture;->sBodyPaths:Ljava/util/HashMap;

    invoke-virtual {v0, v5, v4}, Ljava/util/HashMap;->put(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;

    return-object v4
.end method

.method private static getOrOpenStream(JZ)Ljava/io/FileOutputStream;
    .locals 4

    invoke-static {p0, p1, p2}, Lcom/instagram/app/TigonCapture;->keyFor(JZ)Ljava/lang/String;

    move-result-object v0

    sget-object v1, Lcom/instagram/app/TigonCapture;->sOpenStreams:Ljava/util/HashMap;

    invoke-virtual {v1, v0}, Ljava/util/HashMap;->get(Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v2

    check-cast v2, Ljava/io/FileOutputStream;

    if-eqz v2, :cond_0

    return-object v2

    :cond_0
    invoke-static {p0, p1, p2}, Lcom/instagram/app/TigonCapture;->ensureBodyPath(JZ)Ljava/lang/String;

    move-result-object v3

    new-instance v2, Ljava/io/FileOutputStream;

    const/4 v1, 0x1

    invoke-direct {v2, v3, v1}, Ljava/io/FileOutputStream;-><init>(Ljava/lang/String;Z)V

    sget-object v1, Lcom/instagram/app/TigonCapture;->sOpenStreams:Ljava/util/HashMap;

    invoke-virtual {v1, v0, v2}, Ljava/util/HashMap;->put(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;

    return-object v2
.end method

.method private static incrCount(Ljava/lang/String;I)J
    .locals 4

    sget-object v0, Lcom/instagram/app/TigonCapture;->sByteCounts:Ljava/util/HashMap;

    invoke-virtual {v0, p0}, Ljava/util/HashMap;->get(Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v1

    check-cast v1, Ljava/lang/Long;

    const-wide/16 v2, 0x0

    if-eqz v1, :cond_0

    invoke-virtual {v1}, Ljava/lang/Long;->longValue()J

    move-result-wide v2

    :cond_0
    int-to-long v0, p1

    add-long/2addr v2, v0

    invoke-static {v2, v3}, Ljava/lang/Long;->valueOf(J)Ljava/lang/Long;

    move-result-object v0

    sget-object v1, Lcom/instagram/app/TigonCapture;->sByteCounts:Ljava/util/HashMap;

    invoke-virtual {v1, p0, v0}, Ljava/util/HashMap;->put(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;

    return-wide v2
.end method

.method private static getCount(Ljava/lang/String;)J
    .locals 2

    sget-object v0, Lcom/instagram/app/TigonCapture;->sByteCounts:Ljava/util/HashMap;

    invoke-virtual {v0, p0}, Ljava/util/HashMap;->get(Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v0

    check-cast v0, Ljava/lang/Long;

    if-nez v0, :cond_0

    const-wide/16 v0, 0x0

    return-wide v0

    :cond_0
    invoke-virtual {v0}, Ljava/lang/Long;->longValue()J

    move-result-wide v0

    return-wide v0
.end method

.method private static extFromMime(Ljava/lang/String;)Ljava/lang/String;
    .locals 2

    if-nez p0, :cond_0

    const-string v0, "bin"

    return-object v0

    :cond_0
    invoke-virtual {p0}, Ljava/lang/String;->toLowerCase()Ljava/lang/String;

    move-result-object v0

    const-string v1, "image/jpeg"

    invoke-virtual {v0, v1}, Ljava/lang/String;->contains(Ljava/lang/CharSequence;)Z

    move-result v1

    if-eqz v1, :cond_1

    const-string v0, "jpg"

    return-object v0

    :cond_1
    const-string v1, "image/png"

    invoke-virtual {v0, v1}, Ljava/lang/String;->contains(Ljava/lang/CharSequence;)Z

    move-result v1

    if-eqz v1, :cond_2

    const-string v0, "png"

    return-object v0

    :cond_2
    const-string v1, "image/webp"

    invoke-virtual {v0, v1}, Ljava/lang/String;->contains(Ljava/lang/CharSequence;)Z

    move-result v1

    if-eqz v1, :cond_3

    const-string v0, "webp"

    return-object v0

    :cond_3
    const-string v1, "image/gif"

    invoke-virtual {v0, v1}, Ljava/lang/String;->contains(Ljava/lang/CharSequence;)Z

    move-result v1

    if-eqz v1, :cond_4

    const-string v0, "gif"

    return-object v0

    :cond_4
    const-string v1, "video/mp4"

    invoke-virtual {v0, v1}, Ljava/lang/String;->contains(Ljava/lang/CharSequence;)Z

    move-result v1

    if-eqz v1, :cond_5

    const-string v0, "mp4"

    return-object v0

    :cond_5
    const-string v1, "audio/mpeg"

    invoke-virtual {v0, v1}, Ljava/lang/String;->contains(Ljava/lang/CharSequence;)Z

    move-result v1

    if-eqz v1, :cond_6

    const-string v0, "mp3"

    return-object v0

    :cond_6
    const-string v1, "application/json"

    invoke-virtual {v0, v1}, Ljava/lang/String;->contains(Ljava/lang/CharSequence;)Z

    move-result v1

    if-eqz v1, :cond_7

    const-string v0, "json"

    return-object v0

    :cond_7
    const-string v0, "bin"

    return-object v0
.end method

.method private static categoryFromMime(Ljava/lang/String;)Ljava/lang/String;
    .locals 2

    if-nez p0, :cond_0

    const-string v0, "other"

    return-object v0

    :cond_0
    invoke-virtual {p0}, Ljava/lang/String;->toLowerCase()Ljava/lang/String;

    move-result-object v0

    const-string v1, "image/"

    invoke-virtual {v0, v1}, Ljava/lang/String;->contains(Ljava/lang/CharSequence;)Z

    move-result v1

    if-eqz v1, :cond_1

    const-string v0, "images"

    return-object v0

    :cond_1
    const-string v1, "video/"

    invoke-virtual {v0, v1}, Ljava/lang/String;->contains(Ljava/lang/CharSequence;)Z

    move-result v1

    if-eqz v1, :cond_2

    const-string v0, "videos"

    return-object v0

    :cond_2
    const-string v1, "audio/"

    invoke-virtual {v0, v1}, Ljava/lang/String;->contains(Ljava/lang/CharSequence;)Z

    move-result v1

    if-eqz v1, :cond_3

    const-string v0, "audio"

    return-object v0

    :cond_3
    const-string v0, "other"

    return-object v0
.end method

.method private static sha256File(Ljava/lang/String;)Ljava/lang/String;
    .locals 10

    :try_start_0
    const-string v0, "SHA-256"

    invoke-static {v0}, Ljava/security/MessageDigest;->getInstance(Ljava/lang/String;)Ljava/security/MessageDigest;

    move-result-object v1

    new-instance v2, Ljava/io/FileInputStream;

    invoke-direct {v2, p0}, Ljava/io/FileInputStream;-><init>(Ljava/lang/String;)V

    const/16 v3, 0x2000

    new-array v3, v3, [B

    :loop_read
    invoke-virtual {v2, v3}, Ljava/io/FileInputStream;->read([B)I

    move-result v4

    const/4 v5, -0x1

    if-eq v4, v5, :cond_done

    const/4 v5, 0x0

    invoke-virtual {v1, v3, v5, v4}, Ljava/security/MessageDigest;->update([BII)V

    goto :loop_read

    :cond_done
    invoke-virtual {v2}, Ljava/io/FileInputStream;->close()V

    invoke-virtual {v1}, Ljava/security/MessageDigest;->digest()[B

    move-result-object v4

    new-instance v5, Ljava/lang/StringBuilder;

    invoke-direct {v5}, Ljava/lang/StringBuilder;-><init>()V

    array-length v6, v4

    const/4 v7, 0x0

    :loop_hex
    if-ge v7, v6, :cond_hexdone

    aget-byte v8, v4, v7

    and-int/lit16 v8, v8, 0xff

    invoke-static {v8}, Ljava/lang/Integer;->toHexString(I)Ljava/lang/String;

    move-result-object v9

    invoke-virtual {v9}, Ljava/lang/String;->length()I

    move-result v0

    const/4 v1, 0x1

    if-ne v0, v1, :cond_nopad

    const-string v0, "0"

    invoke-virtual {v5, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    :cond_nopad
    invoke-virtual {v5, v9}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    add-int/lit8 v7, v7, 0x1

    goto :loop_hex

    :cond_hexdone
    invoke-virtual {v5}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-object v0

    :catch_0
    move-exception v0

    const/4 v0, 0x0

    return-object v0
.end method

.method private static copyFile(Ljava/lang/String;Ljava/lang/String;)V
    .locals 6

    :try_start_0
    new-instance v0, Ljava/io/File;

    invoke-direct {v0, p1}, Ljava/io/File;-><init>(Ljava/lang/String;)V

    invoke-virtual {v0}, Ljava/io/File;->getParentFile()Ljava/io/File;

    move-result-object v1

    if-eqz v1, :cond_0

    invoke-virtual {v1}, Ljava/io/File;->exists()Z

    move-result v2

    if-nez v2, :cond_0

    invoke-virtual {v1}, Ljava/io/File;->mkdirs()Z

    :cond_0
    new-instance v1, Ljava/io/FileInputStream;

    invoke-direct {v1, p0}, Ljava/io/FileInputStream;-><init>(Ljava/lang/String;)V

    new-instance v2, Ljava/io/FileOutputStream;

    invoke-direct {v2, p1}, Ljava/io/FileOutputStream;-><init>(Ljava/lang/String;)V

    const/16 v3, 0x2000

    new-array v3, v3, [B

    :loop_copy
    invoke-virtual {v1, v3}, Ljava/io/FileInputStream;->read([B)I

    move-result v4

    const/4 v5, -0x1

    if-eq v4, v5, :cond_done

    const/4 v5, 0x0

    invoke-virtual {v2, v3, v5, v4}, Ljava/io/FileOutputStream;->write([BII)V

    goto :loop_copy

    :cond_done
    invoke-virtual {v1}, Ljava/io/FileInputStream;->close()V

    invoke-virtual {v2}, Ljava/io/FileOutputStream;->close()V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-void

    :catch_0
    move-exception v0

    return-void
.end method

.method private static closeStreamIfOpen(Ljava/lang/String;)V
    .locals 2

    :try_start_0
    sget-object v0, Lcom/instagram/app/TigonCapture;->sOpenStreams:Ljava/util/HashMap;

    invoke-virtual {v0, p0}, Ljava/util/HashMap;->remove(Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v1

    check-cast v1, Ljava/io/FileOutputStream;

    if-eqz v1, :cond_0

    invoke-virtual {v1}, Ljava/io/FileOutputStream;->flush()V

    invoke-virtual {v1}, Ljava/io/FileOutputStream;->close()V

    :cond_0
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-void

    :catch_0
    move-exception v0

    return-void
.end method

.method private static findHeaderIgnoreCase(Ljava/util/Map;Ljava/lang/String;)Ljava/lang/String;
    .locals 5

    if-eqz p0, :cond_notfound

    invoke-interface {p0}, Ljava/util/Map;->entrySet()Ljava/util/Set;

    move-result-object v0

    invoke-interface {v0}, Ljava/util/Set;->iterator()Ljava/util/Iterator;

    move-result-object v0

    :loop
    invoke-interface {v0}, Ljava/util/Iterator;->hasNext()Z

    move-result v1

    if-eqz v1, :cond_notfound

    invoke-interface {v0}, Ljava/util/Iterator;->next()Ljava/lang/Object;

    move-result-object v1

    check-cast v1, Ljava/util/Map$Entry;

    invoke-interface {v1}, Ljava/util/Map$Entry;->getKey()Ljava/lang/Object;

    move-result-object v2

    if-eqz v2, :cond_skip

    invoke-virtual {v2}, Ljava/lang/Object;->toString()Ljava/lang/String;

    move-result-object v2

    invoke-virtual {v2, p1}, Ljava/lang/String;->equalsIgnoreCase(Ljava/lang/String;)Z

    move-result v3

    if-eqz v3, :cond_skip

    invoke-interface {v1}, Ljava/util/Map$Entry;->getValue()Ljava/lang/Object;

    move-result-object v4

    if-eqz v4, :cond_notfound

    invoke-virtual {v4}, Ljava/lang/Object;->toString()Ljava/lang/String;

    move-result-object v4

    return-object v4

    :cond_skip
    goto :loop

    :cond_notfound
    const/4 v0, 0x0

    return-object v0
.end method

.method public static processBody(JZ[B)V
    .locals 8

    if-eqz p3, :cond_done

    :try_start_0
    invoke-static {p0, p1, p2}, Lcom/instagram/app/TigonCapture;->getOrOpenStream(JZ)Ljava/io/FileOutputStream;

    move-result-object v0

    array-length v1, p3

    const/4 v2, 0x0

    invoke-virtual {v0, p3, v2, v1}, Ljava/io/FileOutputStream;->write([BII)V

    invoke-virtual {v0}, Ljava/io/FileOutputStream;->flush()V

    invoke-static {p0, p1, p2}, Lcom/instagram/app/TigonCapture;->keyFor(JZ)Ljava/lang/String;

    move-result-object v3

    sget-object v4, Lcom/instagram/app/TigonCapture;->sByteCounts:Ljava/util/HashMap;

    invoke-virtual {v4, v3}, Ljava/util/HashMap;->containsKey(Ljava/lang/Object;)Z

    move-result v5

    invoke-static {v3, v1}, Lcom/instagram/app/TigonCapture;->incrCount(Ljava/lang/String;I)J

    if-nez v5, :cond_notfirst

    const v6, 0x2000

    if-gt v1, v6, :cond_uselen

    move v6, v1

    :cond_uselen
    invoke-static {p3, v6}, Lcom/instagram/app/TigonCapture;->bytesToText([BI)Ljava/lang/String;

    move-result-object v7

    sget-object v6, Lcom/instagram/app/TigonCapture;->sPreviews:Ljava/util/HashMap;

    invoke-virtual {v6, v3, v7}, Ljava/util/HashMap;->put(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;

    :cond_notfirst
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    :cond_done
    return-void

    :catch_0
    move-exception v0

    return-void
.end method

.method private static appendBodyFields(Ljava/lang/StringBuilder;Ljava/lang/String;Z)Ljava/lang/String;
    .locals 6

    invoke-static {p1}, Lcom/instagram/app/TigonCapture;->getCount(Ljava/lang/String;)J

    move-result-wide v0

    const-wide/16 v2, 0x0

    cmp-long v4, v0, v2

    if-gtz v4, :cond_have

    const/4 v4, 0x0

    return-object v4

    :cond_have
    sget-object v4, Lcom/instagram/app/TigonCapture;->sBodyPaths:Ljava/util/HashMap;

    invoke-virtual {v4, p1}, Ljava/util/HashMap;->get(Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v4

    check-cast v4, Ljava/lang/String;

    invoke-static {v0, v1}, Ljava/lang/Long;->toString(J)Ljava/lang/String;

    move-result-object v5

    if-eqz p2, :cond_req_bytes

    const-string v0, "responseBodyBytes"

    goto :cond_setbytes

    :cond_req_bytes
    const-string v0, "requestBodyBytes"

    :cond_setbytes
    invoke-static {p0, v0, v5}, Lcom/instagram/app/TigonCapture;->appendRawField(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/String;)V

    if-eqz p2, :cond_req_path

    const-string v0, "responseBodyPath"

    goto :cond_setpath

    :cond_req_path
    const-string v0, "requestBodyPath"

    :cond_setpath
    invoke-static {p0, v0, v4}, Lcom/instagram/app/TigonCapture;->appendField(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/String;)V

    sget-object v0, Lcom/instagram/app/TigonCapture;->sPreviews:Ljava/util/HashMap;

    invoke-virtual {v0, p1}, Ljava/util/HashMap;->get(Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v0

    check-cast v0, Ljava/lang/String;

    if-eqz v0, :cond_nopreview

    if-eqz p2, :cond_req_prev

    const-string v1, "responseBodyPreview"

    goto :cond_setpreview

    :cond_req_prev
    const-string v1, "requestBodyPreview"

    :cond_setpreview
    invoke-static {p0, v1, v0}, Lcom/instagram/app/TigonCapture;->appendField(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/String;)V

    :cond_nopreview
    return-object v4
.end method

.method private static appendResponseExtras(Ljava/lang/StringBuilder;JLjava/lang/String;)V
    .locals 7

    if-eqz p3, :cond_end

    invoke-static {p3}, Lcom/instagram/app/TigonCapture;->sha256File(Ljava/lang/String;)Ljava/lang/String;

    move-result-object v6

    if-eqz v6, :cond_nosha

    const-string v1, "responseBodySha256"

    invoke-static {p0, v1, v6}, Lcom/instagram/app/TigonCapture;->appendField(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/String;)V

    :cond_nosha
    invoke-static {p1, p2}, Ljava/lang/Long;->valueOf(J)Ljava/lang/Long;

    move-result-object v0

    sget-object v1, Lcom/instagram/app/TigonCapture;->sContentType:Ljava/util/HashMap;

    invoke-virtual {v1, v0}, Ljava/util/HashMap;->get(Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v1

    check-cast v1, Ljava/lang/String;

    if-eqz v1, :cond_end

    const-string v2, "contentType"

    invoke-static {p0, v2, v1}, Lcom/instagram/app/TigonCapture;->appendField(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/String;)V

    invoke-static {v1}, Lcom/instagram/app/TigonCapture;->categoryFromMime(Ljava/lang/String;)Ljava/lang/String;

    move-result-object v2

    const-string v3, "other"

    invoke-virtual {v2, v3}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v3

    if-nez v3, :cond_end

    invoke-static {v1}, Lcom/instagram/app/TigonCapture;->extFromMime(Ljava/lang/String;)Ljava/lang/String;

    move-result-object v3

    new-instance v4, Ljava/lang/StringBuilder;

    invoke-direct {v4}, Ljava/lang/StringBuilder;-><init>()V

    const-string v5, "/storage/emulated/0/Download/InstagramCaptures/assets/"

    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v4, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    const-string v5, "/"

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

    invoke-virtual {v4}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v4

    invoke-static {p3, v4}, Lcom/instagram/app/TigonCapture;->copyFile(Ljava/lang/String;Ljava/lang/String;)V

    const-string v2, "assetPath"

    invoke-static {p0, v2, v4}, Lcom/instagram/app/TigonCapture;->appendField(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/String;)V

    :cond_end
    return-void
.end method

.method public static writeAndRemove(J)V
    .locals 10

    sget-object v0, Lcom/instagram/app/TigonCapture;->sPending:Ljava/util/HashMap;

    invoke-static {p0, p1}, Ljava/lang/Long;->valueOf(J)Ljava/lang/Long;

    move-result-object v1

    invoke-virtual {v0, v1}, Ljava/util/HashMap;->remove(Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v2

    check-cast v2, Ljava/lang/StringBuilder;

    const/4 v0, 0x1

    invoke-static {p0, p1, v0}, Lcom/instagram/app/TigonCapture;->keyFor(JZ)Ljava/lang/String;

    move-result-object v3

    const/4 v0, 0x0

    invoke-static {p0, p1, v0}, Lcom/instagram/app/TigonCapture;->keyFor(JZ)Ljava/lang/String;

    move-result-object v4

    invoke-static {v3}, Lcom/instagram/app/TigonCapture;->closeStreamIfOpen(Ljava/lang/String;)V

    invoke-static {v4}, Lcom/instagram/app/TigonCapture;->closeStreamIfOpen(Ljava/lang/String;)V

    if-nez v2, :cond_have

    goto :cleanup

    :cond_have
    new-instance v5, Ljava/io/File;

    const-string v6, "/storage/emulated/0/Download/InstagramCaptures/DISABLED"

    invoke-direct {v5, v6}, Ljava/io/File;-><init>(Ljava/lang/String;)V

    invoke-virtual {v5}, Ljava/io/File;->exists()Z

    move-result v6

    if-eqz v6, :cond_enabled

    goto :cleanup

    :cond_enabled
    sget-object v0, Lcom/instagram/app/TigonCapture;->sPending:Ljava/util/HashMap;

    monitor-enter v0

    :try_start_lock
    const/4 v6, 0x0

    invoke-static {v2, v3, v6}, Lcom/instagram/app/TigonCapture;->appendBodyFields(Ljava/lang/StringBuilder;Ljava/lang/String;Z)Ljava/lang/String;

    const/4 v6, 0x1

    invoke-static {v2, v4, v6}, Lcom/instagram/app/TigonCapture;->appendBodyFields(Ljava/lang/StringBuilder;Ljava/lang/String;Z)Ljava/lang/String;

    move-result-object v7

    invoke-static {v2, p0, p1, v7}, Lcom/instagram/app/TigonCapture;->appendResponseExtras(Ljava/lang/StringBuilder;JLjava/lang/String;)V

    invoke-static {v2}, Lcom/instagram/app/TigonCapture;->stripTrailingComma(Ljava/lang/StringBuilder;)V

    const-string v6, "}"

    invoke-virtual {v2, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    const-string v6, "\n"

    invoke-virtual {v2, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v2}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v6
    :try_end_lock
    .catchall {:try_start_lock .. :try_end_lock} :catchall_lock

    monitor-exit v0

    :try_start_0
    new-instance v7, Ljava/io/File;

    const-string v8, "/storage/emulated/0/Download/InstagramCaptures"

    invoke-direct {v7, v8}, Ljava/io/File;-><init>(Ljava/lang/String;)V

    invoke-virtual {v7}, Ljava/io/File;->exists()Z

    move-result v8

    if-nez v8, :cond_dirok

    invoke-virtual {v7}, Ljava/io/File;->mkdirs()Z

    :cond_dirok
    const-string v7, "/storage/emulated/0/Download/InstagramCaptures/traffic.jsonl"

    new-instance v8, Ljava/io/FileOutputStream;

    const/4 v5, 0x1

    invoke-direct {v8, v7, v5}, Ljava/io/FileOutputStream;-><init>(Ljava/lang/String;Z)V

    const-string v5, "UTF-8"

    invoke-virtual {v6, v5}, Ljava/lang/String;->getBytes(Ljava/lang/String;)[B

    move-result-object v5

    invoke-virtual {v8, v5}, Ljava/io/FileOutputStream;->write([B)V

    invoke-virtual {v8}, Ljava/io/FileOutputStream;->close()V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    :cleanup
    :try_start_1
    sget-object v0, Lcom/instagram/app/TigonCapture;->sByteCounts:Ljava/util/HashMap;

    invoke-virtual {v0, v3}, Ljava/util/HashMap;->remove(Ljava/lang/Object;)Ljava/lang/Object;

    invoke-virtual {v0, v4}, Ljava/util/HashMap;->remove(Ljava/lang/Object;)Ljava/lang/Object;

    sget-object v0, Lcom/instagram/app/TigonCapture;->sPreviews:Ljava/util/HashMap;

    invoke-virtual {v0, v3}, Ljava/util/HashMap;->remove(Ljava/lang/Object;)Ljava/lang/Object;

    invoke-virtual {v0, v4}, Ljava/util/HashMap;->remove(Ljava/lang/Object;)Ljava/lang/Object;

    sget-object v0, Lcom/instagram/app/TigonCapture;->sBodyPaths:Ljava/util/HashMap;

    invoke-virtual {v0, v3}, Ljava/util/HashMap;->remove(Ljava/lang/Object;)Ljava/lang/Object;

    invoke-virtual {v0, v4}, Ljava/util/HashMap;->remove(Ljava/lang/Object;)Ljava/lang/Object;

    sget-object v0, Lcom/instagram/app/TigonCapture;->sContentType:Ljava/util/HashMap;

    invoke-virtual {v0, v1}, Ljava/util/HashMap;->remove(Ljava/lang/Object;)Ljava/lang/Object;
    :try_end_1
    .catch Ljava/lang/Throwable; {:try_start_1 .. :try_end_1} :catch_1

    return-void

    :catch_0
    move-exception v0

    goto :cleanup

    :catchall_lock
    move-exception v0

    sget-object v6, Lcom/instagram/app/TigonCapture;->sPending:Ljava/util/HashMap;

    monitor-exit v6

    goto :cleanup

    :catch_1
    move-exception v0

    return-void
.end method

.method public static onStarted(JLjava/lang/String;Ljava/lang/String;Ljava/util/Map;)V
    .locals 4

    sget-object v0, Lcom/instagram/app/TigonCapture;->sPending:Ljava/util/HashMap;

    monitor-enter v0

    :try_start_0
    invoke-static {p0, p1}, Lcom/instagram/app/TigonCapture;->getOrCreate(J)Ljava/lang/StringBuilder;

    move-result-object v1

    const-string v2, "method"

    invoke-static {v1, v2, p2}, Lcom/instagram/app/TigonCapture;->appendField(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/String;)V

    const-string v2, "url"

    invoke-static {v1, v2, p3}, Lcom/instagram/app/TigonCapture;->appendField(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/String;)V

    invoke-static {p4}, Lcom/instagram/app/TigonCapture;->headersToJson(Ljava/util/Map;)Ljava/lang/String;

    move-result-object v3

    const-string v2, "requestHeaders"

    invoke-static {v1, v2, v3}, Lcom/instagram/app/TigonCapture;->appendRawField(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/String;)V
    :try_end_0
    .catchall {:try_start_0 .. :try_end_0} :catchall_0

    monitor-exit v0

    return-void

    :catchall_0
    move-exception v1

    monitor-exit v0

    return-void
.end method

.method public static onResponse(JILjava/util/Map;)V
    .locals 6

    sget-object v0, Lcom/instagram/app/TigonCapture;->sPending:Ljava/util/HashMap;

    monitor-enter v0

    :try_start_0
    invoke-static {p0, p1}, Lcom/instagram/app/TigonCapture;->getOrCreate(J)Ljava/lang/StringBuilder;

    move-result-object v1

    invoke-static {p2}, Ljava/lang/Integer;->toString(I)Ljava/lang/String;

    move-result-object v2

    const-string v3, "status"

    invoke-static {v1, v3, v2}, Lcom/instagram/app/TigonCapture;->appendRawField(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/String;)V

    invoke-static {p3}, Lcom/instagram/app/TigonCapture;->headersToJson(Ljava/util/Map;)Ljava/lang/String;

    move-result-object v2

    const-string v3, "responseHeaders"

    invoke-static {v1, v3, v2}, Lcom/instagram/app/TigonCapture;->appendRawField(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/String;)V

    const-string v3, "Content-Type"

    invoke-static {p3, v3}, Lcom/instagram/app/TigonCapture;->findHeaderIgnoreCase(Ljava/util/Map;Ljava/lang/String;)Ljava/lang/String;

    move-result-object v4

    if-eqz v4, :cond_0

    invoke-static {p0, p1}, Ljava/lang/Long;->valueOf(J)Ljava/lang/Long;

    move-result-object v5

    sget-object v2, Lcom/instagram/app/TigonCapture;->sContentType:Ljava/util/HashMap;

    invoke-virtual {v2, v5, v4}, Ljava/util/HashMap;->put(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;

    :cond_0
    :try_end_0
    .catchall {:try_start_0 .. :try_end_0} :catchall_0

    monitor-exit v0

    return-void

    :catchall_0
    move-exception v1

    monitor-exit v0

    return-void
.end method

.method public static onBody(JZLjava/nio/ByteBuffer;Z)V
    .locals 4

    if-eqz p4, :cond_skip

    :try_start_0
    invoke-static {p3}, Lcom/instagram/app/TigonCapture;->copyBytesFast(Ljava/nio/ByteBuffer;)[B

    move-result-object v0

    if-eqz v0, :cond_skip

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

.method public static onEOM(J)V
    .locals 3

    :try_start_0
    invoke-static {p0, p1}, Lcom/instagram/app/TigonCapture;->getOrCreate(J)Ljava/lang/StringBuilder;

    move-result-object v0

    const-string v1, "outcome"

    const-string v2, "success"

    invoke-static {v0, v1, v2}, Lcom/instagram/app/TigonCapture;->appendField(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/String;)V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    invoke-static {p0, p1}, Lcom/instagram/app/TigonCapture;->spawnWriteWorker(J)V

    return-void

    :catch_0
    move-exception v0

    invoke-static {p0, p1}, Lcom/instagram/app/TigonCapture;->spawnWriteWorker(J)V

    return-void
.end method

.method public static onError(JLjava/lang/String;)V
    .locals 3

    :try_start_0
    invoke-static {p0, p1}, Lcom/instagram/app/TigonCapture;->getOrCreate(J)Ljava/lang/StringBuilder;

    move-result-object v0

    const-string v1, "outcome"

    const-string v2, "error"

    invoke-static {v0, v1, v2}, Lcom/instagram/app/TigonCapture;->appendField(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/String;)V

    const-string v1, "error"

    invoke-static {v0, v1, p2}, Lcom/instagram/app/TigonCapture;->appendField(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/String;)V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    invoke-static {p0, p1}, Lcom/instagram/app/TigonCapture;->spawnWriteWorker(J)V

    return-void

    :catch_0
    move-exception v0

    invoke-static {p0, p1}, Lcom/instagram/app/TigonCapture;->spawnWriteWorker(J)V

    return-void
.end method
