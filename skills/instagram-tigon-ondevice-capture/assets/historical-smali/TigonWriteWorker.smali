.class public Lcom/instagram/app/TigonWriteWorker;
.super Ljava/lang/Object;
.source "TigonWriteWorker.java"
.implements Ljava/lang/Runnable;


# instance fields
.field private final mRequestId:J


# direct methods
.method public constructor <init>(J)V
    .locals 0

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    iput-wide p1, p0, Lcom/instagram/app/TigonWriteWorker;->mRequestId:J

    return-void
.end method


# virtual methods
.method public run()V
    .locals 2

    iget-wide v0, p0, Lcom/instagram/app/TigonWriteWorker;->mRequestId:J

    invoke-static {v0, v1}, Lcom/instagram/app/TigonCapture;->writeAndRemove(J)V

    return-void
.end method
