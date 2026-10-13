.class public Lcom/instagram/app/TigonBodyWorker;
.super Ljava/lang/Object;
.source "TigonBodyWorker.java"
.implements Ljava/lang/Runnable;


# instance fields
.field private final mData:[B

.field private final mIsUpload:Z

.field private final mRequestId:J


# direct methods
.method public constructor <init>(JZ[B)V
    .locals 0

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    iput-wide p1, p0, Lcom/instagram/app/TigonBodyWorker;->mRequestId:J

    iput-boolean p3, p0, Lcom/instagram/app/TigonBodyWorker;->mIsUpload:Z

    iput-object p4, p0, Lcom/instagram/app/TigonBodyWorker;->mData:[B

    return-void
.end method


# virtual methods
.method public run()V
    .locals 5

    iget-wide v0, p0, Lcom/instagram/app/TigonBodyWorker;->mRequestId:J

    iget-boolean v2, p0, Lcom/instagram/app/TigonBodyWorker;->mIsUpload:Z

    iget-object v3, p0, Lcom/instagram/app/TigonBodyWorker;->mData:[B

    invoke-static {v0, v1, v2, v3}, Lcom/instagram/app/TigonCapture;->processBody(JZ[B)V

    return-void
.end method
