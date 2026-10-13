/*
 * On-device Tigon traffic capture for Instagram, running inside an embedded
 * frida-gadget (no PC/Reqable needed at runtime). Hooks the Java-level
 * observer entry points that Tigon's native layer calls directly on every
 * request (com.facebook.tigon.tigonobserver.TigonObservable), including the
 * body observer callbacks whose TigonBodyObservation.body() returns the
 * plaintext (pre-encryption / post-decryption) ByteBuffer.
 *
 * Output: /sdcard/Download/InstagramCaptures/capture_<date>.jsonl (rotates
 * at ~10MB), one JSON object per completed request.
 *
 * Toggle: delete/create /sdcard/Download/InstagramCaptures/DISABLED to
 * pause capture without reinstalling. Checked once at gadget load and then
 * re-checked every CHECK_INTERVAL requests.
 */
Java.perform(function () {
  var BASE_DIR = "/storage/emulated/0/Download/InstagramCaptures/";
  var DISABLED_FLAG = BASE_DIR + "DISABLED";
  var MAX_BODY_BYTES = 65536;
  var MAX_FILE_BYTES = 10 * 1024 * 1024;
  var CHECK_INTERVAL = 20;

  var REDACT_HEADERS = [
    "authorization", "cookie", "set-cookie", "x-ig-www-claim",
    "x-mid", "ig-u-ds-user-id", "x-fb-session-id", "x-ig-device-id",
    "x-ig-family-device-id", "proxy-authorization",
  ];
  var REDACT_BODY_KEYS = [
    "password", "access_token", "accesstoken", "auth_token", "authtoken",
    "session_id", "sessionid", "csrftoken", "secret", "token",
  ];

  var JFile = Java.use("java.io.File");
  var JFileOutputStream = Java.use("java.io.FileOutputStream");
  var JString = Java.use("java.lang.String");

  var pending = {};
  var requestCount = 0;
  var captureEnabled = true;
  var notifShown = false;

  function ensureDir() {
    try {
      var d = JFile.$new(BASE_DIR);
      if (!d.exists()) d.mkdirs();
    } catch (e) {
      console.log("[capture] ensureDir failed: " + e);
    }
  }

  function checkEnabled() {
    try {
      captureEnabled = !JFile.$new(DISABLED_FLAG).exists();
    } catch (e) {
      captureEnabled = true;
    }
    return captureEnabled;
  }

  function nowIso() {
    return new Date().toISOString();
  }

  function redactHeaders(map) {
    var out = {};
    if (map === null || map === undefined) return out;
    try {
      var it = map.entrySet().iterator();
      while (it.hasNext()) {
        var e = it.next();
        var k = e.getKey() === null ? "" : e.getKey().toString();
        var v = e.getValue();
        var vs = v === null ? null : v.toString();
        if (REDACT_HEADERS.indexOf(k.toLowerCase()) !== -1) vs = "[REDACTED]";
        out[k] = vs;
      }
    } catch (e) {
      out["_error"] = "header_decode_failed: " + e;
    }
    return out;
  }

  function redactBodyText(text) {
    if (!text) return text;
    try {
      // JSON-ish "key":"value" redaction, case-insensitive on key.
      var re = new RegExp(
        '("(?:' + REDACT_BODY_KEYS.join("|") + ')"\\s*:\\s*")([^"]*)(")',
        "gi"
      );
      return text.replace(re, "$1[REDACTED]$3");
    } catch (e) {
      return text;
    }
  }

  function bufToText(byteBuffer, cap) {
    if (byteBuffer === null || byteBuffer === undefined) return null;
    try {
      var dup = byteBuffer.duplicate();
      var len = dup.remaining();
      var toRead = Math.min(len, cap);
      var JByteBuffer = Java.use("java.nio.ByteBuffer");
      var bytesArr = Java.array("byte", new Array(toRead).fill(0));
      dup.get(bytesArr, 0, toRead);
      var str = JString.$new(bytesArr, "UTF-8").toString();
      return {
        text: redactBodyText(str),
        truncated: len > cap,
        fullLength: len,
      };
    } catch (e) {
      return { error: "body_decode_failed: " + e };
    }
  }

  function getRec(id) {
    if (!pending[id]) pending[id] = { requestId: id, ts: nowIso() };
    return pending[id];
  }

  function currentFile() {
    var day = new Date().toISOString().slice(0, 10);
    var base = BASE_DIR + "capture_" + day;
    var path = base + ".jsonl";
    try {
      var f = JFile.$new(path);
      var idx = 1;
      while (f.exists() && f.length() > MAX_FILE_BYTES) {
        path = base + "." + idx + ".jsonl";
        f = JFile.$new(path);
        idx++;
      }
    } catch (e) {}
    return path;
  }

  function writeRecord(rec) {
    try {
      ensureDir();
      var line = JSON.stringify(rec) + "\n";
      var fos = JFileOutputStream.$new(currentFile(), true);
      var bytes = JString.$new(line).getBytes("UTF-8");
      fos.write(bytes);
      fos.close();
      requestCount++;
      maybeNotify();
    } catch (e) {
      console.log("[capture] writeRecord failed: " + e);
    }
  }

  function maybeNotify() {
    try {
      if (requestCount % 10 !== 0 && notifShown) return;
      var ActivityThread = Java.use("android.app.ActivityThread");
      var app = ActivityThread.currentApplication();
      if (!app) return;
      var ctx = app.getApplicationContext();
      var NotificationManagerClass = Java.use("android.app.NotificationManager");
      var nm = Java.cast(
        ctx.getSystemService("notification"),
        NotificationManagerClass
      );
      var channelId = "tigon_capture";
      if (Java.use("android.os.Build$VERSION").SDK_INT.value >= 26) {
        var ChannelClass = Java.use("android.app.NotificationChannel");
        var channel = ChannelClass.$new(
          channelId,
          "Traffic Capture",
          3 // IMPORTANCE_DEFAULT
        );
        nm.createNotificationChannel(channel);
      }
      var BuilderClass = Java.use("android.app.Notification$Builder");
      var builder = Java.use("android.os.Build$VERSION").SDK_INT.value >= 26
        ? BuilderClass.$new(ctx, channelId)
        : BuilderClass.$new(ctx);
      builder.setContentTitle("Traffic capture active");
      builder.setContentText("Captured requests: " + requestCount);
      builder.setSmallIcon(ctx.getApplicationInfo().icon.value);
      builder.setOngoing(true);
      nm.notify(424242, builder.build());
      notifShown = true;
    } catch (e) {
      console.log("[capture] notify failed (non-fatal): " + e);
    }
  }

  // --- Floating record/pause button (needs "Display over other apps") ---
  function updateButtonAppearance(btn) {
    try {
      var Color = Java.use("android.graphics.Color");
      var color = captureEnabled
        ? Color.parseColor("#E53935")
        : Color.parseColor("#757575");
      btn.setBackgroundColor(color);
      btn.setText(captureEnabled ? "REC" : "OFF");
    } catch (e) {
      console.log("[capture] updateButtonAppearance error: " + e);
    }
  }

  function writeDisabledFlag(disabled) {
    try {
      var f = JFile.$new(DISABLED_FLAG);
      if (disabled) {
        ensureDir();
        if (!f.exists()) f.createNewFile();
      } else if (f.exists()) {
        f.delete();
      }
    } catch (e) {
      console.log("[capture] writeDisabledFlag error: " + e);
    }
  }

  function toggleCapture(btn) {
    captureEnabled = !captureEnabled;
    writeDisabledFlag(!captureEnabled);
    updateButtonAppearance(btn);
    console.log("[capture] toggled via overlay, enabled=" + captureEnabled);
  }

  function createOverlayButton(ctx) {
    try {
      var WindowManagerCls = Java.use("android.view.WindowManager");
      var LayoutParamsCls = Java.use("android.view.WindowManager$LayoutParams");
      var ViewGroupLayoutParamsCls = Java.use(
        "android.view.ViewGroup$LayoutParams"
      );
      var Button = Java.use("android.widget.Button");
      var Gravity = Java.use("android.view.Gravity");
      var PixelFormat = Java.use("android.graphics.PixelFormat");

      var wm = Java.cast(ctx.getSystemService("window"), WindowManagerCls);

      var TYPE_APPLICATION_OVERLAY = 2038;
      var FLAG_NOT_FOCUSABLE = 8;
      var FLAG_NOT_TOUCH_MODAL = 32;

      var lp = LayoutParamsCls.$new(
        ViewGroupLayoutParamsCls.WRAP_CONTENT.value,
        ViewGroupLayoutParamsCls.WRAP_CONTENT.value,
        TYPE_APPLICATION_OVERLAY,
        FLAG_NOT_FOCUSABLE | FLAG_NOT_TOUCH_MODAL,
        PixelFormat.TRANSLUCENT.value
      );
      lp.gravity.value = Gravity.TOP.value | Gravity.RIGHT.value;
      lp.x.value = 20;
      lp.y.value = 200;

      var btn = Button.$new(ctx);
      btn.setTextColor(-1);
      btn.setAlpha(0.85);
      updateButtonAppearance(btn);

      var state = { downX: 0, downY: 0, downRawX: 0, downRawY: 0, moved: false };

      var TouchListener = Java.registerClass({
        name: "com.instagram.app.CaptureOverlayTouchListener",
        implements: [Java.use("android.view.View$OnTouchListener")],
        methods: {
          onTouch: function (view, event) {
            var action = event.getAction();
            if (action === 0) {
              state.downX = lp.x.value;
              state.downY = lp.y.value;
              state.downRawX = event.getRawX();
              state.downRawY = event.getRawY();
              state.moved = false;
              return false;
            } else if (action === 2) {
              var dx = event.getRawX() - state.downRawX;
              var dy = event.getRawY() - state.downRawY;
              if (Math.abs(dx) > 12 || Math.abs(dy) > 12) state.moved = true;
              lp.x.value = state.downX - Math.round(dx);
              lp.y.value = state.downY + Math.round(dy);
              try {
                wm.updateViewLayout(view, lp);
              } catch (e) {}
              return true;
            } else if (action === 1) {
              if (!state.moved) toggleCapture(view);
              return true;
            }
            return false;
          },
        },
      });

      btn.setOnTouchListener(TouchListener.$new());
      wm.addView(btn, lp);
      console.log("[capture] overlay record button added");
    } catch (e) {
      console.log("[capture] createOverlayButton error: " + e);
    }
  }

  function initOverlay() {
    try {
      var Settings = Java.use("android.provider.Settings");
      var ActivityThread = Java.use("android.app.ActivityThread");
      var app = ActivityThread.currentApplication();
      if (!app) return;
      var ctx = app.getApplicationContext();

      var canDraw = Settings.canDrawOverlays(ctx);
      if (!canDraw) {
        console.log(
          "[capture] Overlay permission not granted - opening grant screen. " +
            "Grant 'Display over other apps' for Instagram, then relaunch to see the REC button."
        );
        try {
          var Intent = Java.use("android.content.Intent");
          var Uri = Java.use("android.net.Uri");
          var intent = Intent.$new(
            "android.settings.action.MANAGE_OVERLAY_PERMISSION"
          );
          var uri = Uri.parse("package:" + ctx.getPackageName());
          intent.setData(uri);
          intent.addFlags(0x10000000); // FLAG_ACTIVITY_NEW_TASK
          ctx.startActivity(intent);
        } catch (e2) {
          console.log("[capture] could not open overlay settings: " + e2);
        }
        return;
      }

      var Handler = Java.use("android.os.Handler");
      var Looper = Java.use("android.os.Looper");
      var mainHandler = Handler.$new(Looper.getMainLooper());

      var InitRunnable = Java.registerClass({
        name: "com.instagram.app.CaptureOverlayInitRunnable",
        implements: [Java.use("java.lang.Runnable")],
        methods: {
          run: function () {
            createOverlayButton(ctx);
          },
        },
      });

      mainHandler.post(InitRunnable.$new());
    } catch (e) {
      console.log("[capture] initOverlay error: " + e);
    }
  }

  ensureDir();
  checkEnabled();
  console.log("[capture] init, enabled=" + captureEnabled + " dir=" + BASE_DIR);
  initOverlay();

  var Observable = Java.use(
    "com.facebook.tigon.tigonobserver.TigonObservable"
  );

  Observable.onStarted.overload(
    "com.facebook.tigon.tigonobserver.TigonObserverData"
  ).implementation = function (data) {
    try {
      if (requestCount % CHECK_INTERVAL === 0) checkEnabled();
      if (captureEnabled) {
        var id = data.requestId().toString();
        var rec = getRec(id);
        var req = data.submittedRequest();
        if (req) {
          rec.method = req.method();
          rec.url = req.url();
          rec.requestHeaders = redactHeaders(req.headers());
        }
        rec.tsStartedMs = data.tsStartedMs().toString();
      }
    } catch (e) {
      console.log("[capture] onStarted error: " + e);
    }
    return this.onStarted(data);
  };

  Observable.onResponse.overload(
    "com.facebook.tigon.tigonobserver.TigonObserverData"
  ).implementation = function (data) {
    try {
      if (captureEnabled) {
        var id = data.requestId().toString();
        var rec = getRec(id);
        var resp = data.response();
        if (resp) {
          try {
            rec.status = resp.A00.value;
          } catch (e1) {}
          try {
            rec.responseHeaders = redactHeaders(resp.A01.value);
          } catch (e2) {}
        }
      }
    } catch (e) {
      console.log("[capture] onResponse error: " + e);
    }
    return this.onResponse(data);
  };

  Observable.onEOM.overload(
    "com.facebook.tigon.tigonobserver.TigonObserverData"
  ).implementation = function (data) {
    try {
      if (captureEnabled) {
        var id = data.requestId().toString();
        var rec = getRec(id);
        rec.tsEndedMs = data.tsEndedMs().toString();
        rec.outcome = "success";
        writeRecord(rec);
        delete pending[id];
      }
    } catch (e) {
      console.log("[capture] onEOM error: " + e);
    }
    return this.onEOM(data);
  };

  Observable.onError.overload(
    "com.facebook.tigon.tigonobserver.TigonObserverData"
  ).implementation = function (data) {
    try {
      if (captureEnabled) {
        var id = data.requestId().toString();
        var rec = getRec(id);
        rec.tsEndedMs = data.tsEndedMs().toString();
        rec.outcome = "error";
        try {
          var err = data.error();
          rec.error = err ? err.toString() : null;
        } catch (e1) {}
        writeRecord(rec);
        delete pending[id];
      }
    } catch (e) {
      console.log("[capture] onError error: " + e);
    }
    return this.onError(data);
  };

  Observable.onDownloadBody.overload(
    "com.facebook.tigon.tigonobserver.interfaces.TigonBodyObservation"
  ).implementation = function (obs) {
    try {
      if (captureEnabled) {
        var id = obs.mRequestId.value.toString();
        var rec = getRec(id);
        if (obs.mHasBody.value) {
          var buf = obs.body();
          rec.responseBody = bufToText(buf, MAX_BODY_BYTES);
        }
      }
    } catch (e) {
      console.log("[capture] onDownloadBody error: " + e);
    }
    return this.onDownloadBody(obs);
  };

  Observable.onUploadBody.overload(
    "com.facebook.tigon.tigonobserver.interfaces.TigonBodyObservation"
  ).implementation = function (obs) {
    try {
      if (captureEnabled) {
        var id = obs.mRequestId.value.toString();
        var rec = getRec(id);
        if (obs.mHasBody.value) {
          var buf = obs.body();
          rec.requestBody = bufToText(buf, MAX_BODY_BYTES);
        }
      }
    } catch (e) {
      console.log("[capture] onUploadBody error: " + e);
    }
    return this.onUploadBody(obs);
  };

  console.log("[capture] Tigon observer hooks installed");
});
