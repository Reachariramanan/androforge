# Inspecting HTTPS Traffic of Your Own Android App with Reqable (Non-Rooted Device)

**A combined, complete reference: APK patching guide + certificate-trust research report + questionnaire + verification analysis**

---

## 0. About This Document

This file merges four things into one reference, without dropping any of the content from the sources:

| # | Source | What it contributed |
|---|--------|---------------------|
| A | **The original guide** (written by ChatGPT; you pasted it at the start) | The APK-patching workflow: Apktool decode, network security config, manifest edit, rebuild, zipalign, sign, install, connect to Reqable, limitations |
| B | **The questionnaire** (clarifying questions and your answers) | Your exact setup and the scope of what still needed solving |
| C | **The research report** (produced in this conversation from Reqable docs, Android Developers docs, HTTP Toolkit, GitHub issues, etc.; you also uploaded it as a PDF) | The "finish the certificate trust" steps, gaps in the original guide, pinning, React Native behaviour, Wi-Fi proxy specifics, troubleshooting, checklist |
| D | **The verification analysis** (my assessment of A and C, plus one extra search) | Which claims are solid, which are inference, and the Android 17 certificate-transparency check |

**How the sections are organised.** Content from A and C that covers the same topic is placed together (for example, "install the certificate" combines the guide's Section 3 with the report's Section 1). Where the two documents disagree or one corrects the other, both statements are kept and the correction is marked.

**Scope reminder.** Everything here assumes you **own** the app. The configuration changes described weaken TLS protections for that app and must **never ship in production builds**.

---

## 1. Questionnaire and Scope

### 1.1 The clarifying questions that were asked

1. What would you like me to do with it: check its accuracy against current Android and Reqable documentation, troubleshoot a problem you're hitting, or research what it doesn't cover (certificate pinning, Flutter apps, split APKs)?
2. What kind of app is it: native Android (Java/Kotlin), Flutter, React Native, or something else?
3. What's your target Android version and setup: Wi-Fi proxy or VPN mode, and a non-rooted device?

### 1.2 Your answers

- **Current status:** You already patched the APK successfully so that it trusts user CAs.
- **What you need:** Help with only the **remaining certificate trust steps**.

| Question | Your answer |
|----------|-------------|
| 1. What to focus on | Any gaps in the guide for getting a user CA **fully trusted after the APK is already patched**, especially network security config or residual pinning issues |
| 2. App type | **Native Android (Java/Kotlin) + some React Native** |
| 3. Android version and setup | **Android 13/14, non-rooted device, Wi-Fi proxy mode with Reqable** |

**Your stated goal:** research the cleanest way to finish the certificate installation and trust setup on a non-rooted device.

### 1.3 What the research was commissioned to cover

The research brief covered five areas (all answered in the sections below):

1. The exact current procedure to export and install the Reqable root CA on Android 13/14 without root (formats, how Reqable serves the cert, menu locations, screen-lock requirement, warning prompt, OEM differences for Samsung/Xiaomi/Pixel, verifying the install, Android 14 specifics including the APEX-based system CA store).
2. Gaps or mistakes in the guide's approach (is `<certificates src="user"/>` sufficient, `debug-overrides`, `targetSdkVersion` 24+ effects, existing `domain-config` precedence, cleartext, verifying that the patched config was applied).
3. Residual certificate pinning in your own app (NSC `<pin-set>`, OkHttp `CertificatePinner`, TrustKit, custom TrustManagers, React Native pinning libraries) and how React Native's networking stack interacts with user CA trust and the system proxy.
4. Wi-Fi proxy specifics for Reqable on Android 13/14 (host/port, same-network requirements, HTTPS decryption settings, proxy vs VPN mode, troubleshooting).
5. A minimal end-to-end validation checklist (how to tell trust-anchor failure from pinning failure from proxy bypass).

**Scope constraint applied:** for pinning, only legitimate debug-build configuration of your **own** app was researched (NSC `debug-overrides`, build-variant-specific pinning, OkHttp debug configuration), not bypassing protections in third-party apps.

---

## 2. Executive Summary (TL;DR)

Your patched `base-config` with `<certificates src="system"/>` + `<certificates src="user"/>` is the correct and sufficient trust change for a non-debuggable, Apktool-rebuilt APK. The remaining work is to install the **desktop** Reqable CA as a user CA through Settings, and then confirm that nothing else in your app overrides that trust. The usual culprits are an existing `domain-config`, a `<pin-set>`, OkHttp `CertificatePinner`, or traffic that never uses the Wi-Fi proxy.

- **Install the right cert the right way.** Export the CA from **Reqable desktop**, not the phone app (each Reqable install generates its own CA). Copy it to the phone. Install it only through Settings → *Encryption & credentials* → *Install a certificate* → **CA certificate**. A screen lock is required. Since Android 11, apps can't even prompt you to install a CA, so tapping the file no longer works. Android 14's APEX/Conscrypt change affects only the *system* store and does not matter for user CAs.
- **Your NSC is right, but it can be silently overridden.** A `domain-config` that has its own `trust-anchors` or `pin-set` wins for those hosts. User CAs do **not** bypass pins unless `overridePins="true"` is set. `<debug-overrides>` applies only when `android:debuggable="true"`, so it will do nothing in a release-style APK you re-signed. OkHttp `CertificatePinner` and React Native pinning libraries enforce pins independently of NSC.
- **Diagnose by error signature.**
  - `Trust anchor for certification path not found` = the user CA is not trusted for that host.
  - `Certificate pinning failure!` / `Pin verification failed` = pinning.
  - No CONNECT entry in Reqable at all = proxy bypass (Flutter/Dart, raw sockets, native libs, QUIC/HTTP/3, which Reqable capture does not support).

**Verdict from the verification analysis (Section 12):** the core of both documents is right, but neither is gospel. Trust the parts that match Android's official docs. A few points (WebView, Custom Tabs, one Android 17 reference) are inference or unverified, and are flagged where they appear.

---

## 3. How the Solution Works

### 3.1 Concept (from the original guide)

If you have the APK but not the source code, you can often modify it to trust Reqable's certificate and inspect HTTPS traffic on a non-rooted Android phone.

Since you own the app, you can use a process called **APK patching**. This modifies the compiled application's configuration without needing its original Java or Kotlin source code. The most practical tools are **Apktool** and **Android's APK signing tools**.

### 3.2 Flow

```
Original APK
   |  (does not trust Reqable's user CA)
   v
Decode using Apktool
   v
Modify network security configuration
   v
Allow user-installed CA certificates
   v
Rebuild and sign APK
   v
Install patched APK on non-rooted Android phone
   v
Reqable HTTPS inspection
   (provided traffic is routed through the proxy
    and TLS validation succeeds)
```

### 3.3 The important distinction (from the original guide, Section 5)

You are **not** changing Android's system CA store on the non-rooted phone. Instead, you are changing **your application's trust policy**.

```
Non-rooted Android
    |
    +-- System CA store (unchanged)
    |
    +-- User CA store
    |      |
    |      +-- Reqable CA
    |
    +-- Your patched APK
           |
           +-- network_security_config.xml
           |      |
           |      +-- Trust system CAs
           |      +-- Trust user CAs
           |
           +-- HTTPS traffic via Reqable
```

This is sufficient for many native Android applications that rely on Android's normal TLS trust machinery.

### 3.4 What the guide needs (prerequisites)

A computer with **Java**, **Apktool**, **Android SDK Build Tools** (`zipalign`, `apksigner`), and your APK.

---

## 4. Part A: Patching the APK (Original Guide, Steps 1–5)

> You have already completed this part. It is kept in full for completeness, with notes from the research report added where they apply.

Assume your APK is named `myapp.apk`.

### Step 1: Decode your APK

```bash
apktool d myapp.apk -o myapp_decoded
```

This produces:

```
myapp_decoded/
├── AndroidManifest.xml
├── apktool.yml
├── res/
├── smali/
├── smali_classes2/
└── assets/
```

The `smali` directories contain disassembled Dalvik bytecode. You generally do **not** need to edit these just to configure Android's certificate trust.

### Step 2: Create the network security configuration

Inside the decoded folder, create `myapp_decoded/res/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config>
        <trust-anchors>
            <certificates src="system" />
            <certificates src="user" />
        </trust-anchors>
    </base-config>
</network-security-config>
```

This tells Android's standard network security framework to accept certificates from both the **system CA store** and the **user-installed CA store**.

- This configuration works without marking the APK as debuggable, but it is suitable **only for a testing APK**, because it broadens the app's certificate trust.
- Reqable documents the same `system` + `user` trust approach for Android applications.
- *Research note:* this body matches Reqable's own "Method 2" sample for non-root devices. Reqable's sample also adds `cleartextTrafficPermitted="true"` and tells you to remove the config from release builds.

### Step 3: Edit `AndroidManifest.xml`

Find the `<application>` element and add:

```
android:networkSecurityConfig="@xml/network_security_config"
```

For example:

```xml
<application
    android:label="@string/app_name"
    android:networkSecurityConfig="@xml/network_security_config">

    <!-- Existing application components -->

</application>
```

- Keep **all** existing attributes and child elements.
- If the app **already has** a network security configuration, inspect and **extend** it rather than replacing it blindly, especially if the existing file has domain-specific rules. (The report explains why this matters in Section 7.)

### Step 4: Rebuild the APK

```bash
apktool b myapp_decoded -o myapp_patched_unsigned.apk
```

### Step 5: Align and sign the APK

The rebuilt APK **must be signed** before Android will install it. Apktool itself confirms that rebuilt APKs must be signed separately.

Align using Android SDK Build Tools:

```bash
zipalign -p -f 4 \
  myapp_patched_unsigned.apk \
  myapp_patched_aligned.apk
```

Generate a testing key:

```bash
keytool -genkeypair \
  -keystore debug-test.jks \
  -alias testkey \
  -keyalg RSA \
  -keysize 3072 \
  -validity 3650
```

Then sign:

```bash
apksigner sign \
  --ks debug-test.jks \
  --ks-key-alias testkey \
  --out myapp_patched.apk \
  myapp_patched_aligned.apk
```

Verify:

```bash
apksigner verify --verbose myapp_patched.apk
```

The final APK is now ready for testing.

**Important (signing identity):** If the original application is already installed with a **different signing certificate**, Android will not allow this patched APK to update it. You must either sign using the original signing key or **uninstall the existing installation first**. Uninstalling may delete local application data.

**Note for newer devices or APKs with native libraries (16 KiB alignment):** use the current Android SDK's 16 KiB-aware zip alignment option where appropriate. Android recommends:

```bash
zipalign -P 16 -f -v 4 <input.apk> <output.apk>
```

for APKs containing `.so` libraries.

### Additional patching notes from the research report

- **Split APKs:** if your application came from an Android App Bundle, you may need the complete set of APK splits rather than a single extracted base APK. If splits are installed, every split must be re-signed with the **same key**.
- **Existing `networkSecurityConfig`:** a pre-existing `android:networkSecurityConfig` attribute may point at a *different* XML file, which means you edited a file the app never loads. Confirm there is exactly one such attribute (see Section 7.4 for the verification commands).

---

## 5. Part B: Installing the Certificate and Connecting to Reqable

This section combines the guide's Section 3 with the report's detailed Android 13/14 procedure.

### 5.1 The short procedure (original guide, Section 3)

Once the modified APK is built:

1. **Install Reqable's CA certificate** on the phone under *Settings → Security → Encryption & credentials → Install a certificate → CA certificate*.
2. **Install the patched APK:**
   ```bash
   adb install myapp_patched.apk
   ```
3. **Open Reqable on the phone and start traffic capture in VPN mode.** Alternatively, use Reqable on a computer and set the phone's Wi-Fi proxy to the computer's IP address and Reqable's listening port. *(Your chosen setup is the Wi-Fi proxy variant; see Section 9.)*
4. **Open your patched application** and perform an action that makes an HTTPS request.
5. **Check Reqable** for the request URL, headers, body and response.

Reqable's documentation confirms that user certificates can be installed without root, while the app needs appropriate trust configuration on Android 7+.

### 5.2 Which Reqable CA to install (critical gap in the guide)

"Install the Reqable CA" is **ambiguous** in the original guide.

- Reqable warns that if you analyse traffic with the **desktop** app, you must install the **PC's** CA on the phone. The CA generated by Reqable for each device is different.
- If you install the CA exported from the **Reqable phone app** while proxying to the **desktop**, every handshake fails.

### 5.3 Getting the file onto the phone

- In Reqable desktop, open the certificate/shield page and use the built-in Android guide. Reqable says it has built-in guidelines for installing Android and iOS certificates.
- The official docs do **not** publish a fixed download hostname. The Windows changelog for v3.0.36 (2026-01-20) notes an update to the CA certificate download link. **Use whatever URL/QR the desktop app currently shows**, rather than a hostname from an old tutorial.
- Reqable's non-root guide gives two delivery routes:
  - (a) Put the phone on the same LAN, set the Wi-Fi proxy to the PC, and download the CA in the phone browser.
  - (b) Save the cert on the desktop and push it with ADB, for example:
    ```bash
    adb push reqable-ca.crt /sdcard/Download/
    ```
- **Format:** the phone installs a `.crt` (PEM or DER X.509). `.p12` is only for moving a Reqable root between Reqable installs.

### 5.4 Installing the certificate (Android 13/14, menu locations vary by OEM)

| Device | Path |
|---|---|
| Reqable docs / AOSP-style | Settings → Security → Encryption & credentials → Install a certificate → **CA certificate** |
| Pixel / stock Android 13–15 | Settings → Security & privacy → More security settings → Encryption & credentials → Install a certificate → CA certificate |
| Samsung One UI | Settings → Biometrics and security → Other security settings → Install from device storage → CA certificate |
| Xiaomi/HyperOS and others | Search Settings for "CA certificate" (paths vary) |

- Expect a **full-screen warning** that CA certificates can put your privacy at risk. Choose **Install anyway**, then authenticate.
- A **PIN, pattern, or password screen lock is required** for credential storage.
- **Why tapping the file no longer works:** since Android 11, CA certificates can only be installed via Settings (AOSP `KeyChain.createInstallIntent()` docs). The installer refuses installs launched by anything other than Settings. HTTP Toolkit notes that Android 11 (API level 30, 2020) tightened this further so that apps can no longer even prompt the user to install a CA.

**Xiaomi/HyperOS gotcha.** Reqable issue #856 (POCO X4 GT, HyperOS, Android 14) reports the installer crashing when the `.crt` is selected. The Reqable author's diagnosis was that the installer lacks permission to read the certificate file, and the suggested fix is to move the file to another public folder and try again. The reporter fixed it by granting the system file-access permission.

### 5.5 Verifying the installation

- Go to Settings → … → Encryption & credentials → **Trusted credentials → User** tab. On Samsung, use **View security certificates → User**.
- Reqable can check certificate status over ADB, but its docs say it **cannot detect** the user-certificate installation status of non-root devices and will always display "Unknown Certificate Installation Status." The Settings list is therefore your **source of truth**.

### 5.6 Browser sanity check

- Reqable's install docs say that with a higher version of Chrome, you need to install the CA in the **user** certificate directory.
- The Reqable docs repo adds that Chromium-based browsers trust the user certificate by default and do not perform CT log verification.
- Item 7 of Reqable's Android FAQ explains that **Firefox** uses its own built-in CA store, so the Reqable CA is not trusted there whether it is in the system or user directory. You have to enable "Use third party CA certificates" in Firefox's secret settings.

---

## 6. Review of the Original Guide: What It Got Right and Where It Has Gaps

### 6.1 What the guide got right

- The NSC body matches Reqable's own "Method 2" sample for non-root devices. Reqable's sample also adds `cleartextTrafficPermitted="true"`, and tells you to remove the config from release builds.
- The Settings path in the guide (Settings → Security → Encryption & Credentials → Install a Certificate → CA Certificate) is the one Reqable documents.
- The overall approach (patch trust policy of the app, leave the system store alone) is sound for native Android apps using the standard platform TLS stack.

### 6.2 Gaps and outdated or misleading points in the guide

1. **"Install the Reqable CA" is ambiguous.** Reqable warns that if you analyse traffic with the desktop app, you must install the *PC's* CA on the phone. The CA generated for each device is different. Installing the CA exported from the Reqable phone app while proxying to the desktop makes every handshake fail.

2. **Tapping the `.crt` file no longer installs it.** Since Android 11, CA certificates can only be installed via Settings (AOSP `KeyChain.createInstallIntent()` docs). The installer refuses installs launched by anything other than Settings. HTTP Toolkit notes that Android 11 (API level 30, 2020) tightened this further so that it is impossible for an app to prompt the user to install a CA at all.

3. **`debug-overrides` is not a drop-in improvement for your patched APK.** Android applies `debug-overrides` only when `android:debuggable` is `"true"`. If it is `"false"`, the section is completely ignored. A rebuilt release APK is normally not debuggable, so `base-config` is the right choice for the Apktool path. `debug-overrides` (or Reqable's `debugImplementation("com.reqable.android:user-certificate-trust:1.0.0")`) is the cleaner choice when you build a **debug variant from source**.

4. **`base-config` does not reach every host.** Android uses the most specific matching `domain-config` for a destination. Values not set in a `domain-config` are inherited from `base-config`, but a `domain-config` that declares its own `<trust-anchors>` **replaces** them for that domain. If the original APK shipped its own NSC with domain rules for your API host, user-CA trust from `base-config` does not apply there.

5. **User CAs do not bypass pins by default.** `overridePins` defaults to `"false"` everywhere except inside `debug-overrides`, where the default is `"true"`. A surviving `<pin-set>` will reject Reqable's re-signed certificates even with `src="user"` in `base-config`.

6. **Android 14's "APEX-based CA store" is irrelevant here.** Android 14 moved *system* CAs to `/apex/com.android.conscrypt/cacerts`, which broke root-based system-store injection. HTTP Toolkit notes that limited user-installed CA certificates continue functioning as before. Your non-root user-CA path is unaffected.

7. **Flutter is categorically different.** Reqable states the user-certificate approach is only valid for Android native apps, not Flutter-based apps. Dart's `HttpClient` also doesn't use the system proxy by default.

---

## 7. Making Sure Your Patched Network Security Config Actually Applies

### 7.1 Recommended NSC for the patched APK

This keeps your `base-config`, makes user CAs override pins, and covers any existing domain rules:

```xml
<network-security-config>
  <base-config>
    <trust-anchors>
      <certificates src="system"/>
      <certificates src="user" overridePins="true"/>
    </trust-anchors>
  </base-config>
  <!-- If the original file had domain-config blocks with their own trust-anchors,
       add the same user line inside each one, or delete those trust-anchors. -->
</network-security-config>
```

### 7.2 For a source build: the cleanest variant-scoped option

Use `debug-overrides` (`overridePins` defaults to `true` there), or put the NSC in `src/debug/res/xml/` with a `src/debug/AndroidManifest.xml` overlay:

```xml
<network-security-config>
  <debug-overrides>
    <trust-anchors>
      <certificates src="system"/>
      <certificates src="user"/>
    </trust-anchors>
  </debug-overrides>
</network-security-config>
```

Reqable also publishes a helper artifact for this purpose: `debugImplementation("com.reqable.android:user-certificate-trust:1.0.0")`.

### 7.3 `targetSdkVersion` and cleartext

- **targetSdkVersion.** Apps targeting API 23 and lower trust user CAs by default. Apps targeting API 24 and higher trust **only system CAs** unless the NSC opts in. Your opt-in is therefore **mandatory**, and it does not depend on any further targetSdk increase.
- **Cleartext.** Irrelevant for HTTPS through the proxy. It matters only if the app talks plain `http://`, such as a React Native debug build loading JS from Metro. Since Android 9 (API 28), cleartext is off by default. Adding an NSC can also change the cleartext behaviour you previously got from the manifest's `usesCleartextTraffic` flag, so add `cleartextTrafficPermitted="true"` **only where you really need HTTP**.

### 7.4 Verifying the rebuilt APK

```bash
# 1. Manifest attribute present (and only once) on <application>
aapt2 dump xmltree --file AndroidManifest.xml app-signed.apk | grep -i networkSecurityConfig

# 2. The referenced resource exists
aapt2 dump resources app-signed.apk | grep -i network_security_config

# 3. Compiled XML contents are what you intended
aapt2 dump xmltree --file res/xml/network_security_config.xml app-signed.apk

# 4. targetSdk and debuggable flag
aapt2 dump badging app-signed.apk | grep -iE "targetSdkVersion|debuggable"

# 5. Round-trip check
apktool d -f app-signed.apk -o verify && diff -r original_decoded/res/xml verify/res/xml
```

Things to watch for:

- A pre-existing `android:networkSecurityConfig` pointing at a **different** XML file means you edited a file the app never loads.
- Resource paths can be obfuscated by R8 resource shrinking, so search `resources.arsc` by name.
- If split APKs are installed, check that **every split** is re-signed with the same key.

---

## 8. Residual Pinning and the App's Networking Stack

### 8.1 Pinning mechanisms in your own app, and how to handle them in a debug/test build

| Mechanism | Does `src="user"` in base-config fix it? | Legitimate debug-build fix |
|---|---|---|
| NSC `<pin-set>` | **No** (`overridePins` defaults to false) | `overridePins="true"` on user certs; or move user trust into `debug-overrides` (pins skipped for debug anchors); or drop the pin-set in debug resources |
| OkHttp `CertificatePinner` | **No**, enforced by OkHttp after the handshake ("Certificate pinning failure!") | Build the pinner only in release (`if (!BuildConfig.DEBUG) builder.certificatePinner(...)`), or use `CertificatePinner.DEFAULT` in debug |
| TrustKit-Android | **Partly.** TrustKit uses the NSC file and supports `debug-overrides`; on Android N+ it uses the OS's pinning | Add user CA under `debug-overrides`; set `enforcePinning="false"` in a debug-only `trustkit-config` |
| Custom `X509TrustManager` / `SSLSocketFactory` / `HostnameVerifier` | **No**, if it loads a bundled keystore instead of platform defaults | Use platform-default trust in debug. Don't ship trust-all managers, which Android flags as an unsafe TrustManager risk |
| `react-native-ssl-pinning` | **No**, it builds its own OkHttp client with pins | Gate pinned calls behind a debug flag. Note issue #158: `disableAllSecurity` doesn't work as expected on Android |
| `react-native-ssl-public-key-pinning` | **No**, it uses OkHttp `CertificatePinner` | Don't call `initializeSslPinning()` in debug, or call `disableSslPinning()` |
| Custom RN `OkHttpClientFactory` with pinner | **No** | Return an unpinned client in debug |

### 8.2 How the React Native networking stack interacts with user-CA trust and the proxy

- **`fetch` / `XMLHttpRequest`** (and therefore Axios, Apollo `HttpLink`, and most JS SDKs built on them) go through `NetworkingModule` → OkHttp from `OkHttpClientProvider`. That client uses the **platform trust manager (your NSC)** and the **system proxy**, so it shows up in Reqable.
- **RN `WebSocket`** also uses OkHttp, but historically `WebSocketModule` created its own `OkHttpClient` per connection (RN issue #10437). A custom factory may not apply to it. NSC trust still applies. Reqable captures WebSockets upgraded from HTTP/1.1.
- **`react-native-webview` / Android System WebView** generally follows platform certificate handling (Chromium engineers said WebView behaviour should follow the Android platform). Treat WebView NSC behaviour as **very likely but verify it**, because there is no explicit official statement that WebView honours user-CA trust anchors.
- **Chrome Custom Tabs** run inside the Chrome browser (a feature of Chrome, sharing Chrome's cookie jar). They therefore follow **Chrome's trust, not your NSC**. This is an inference from the docs, not an explicit statement. Reqable's docs note that the latest Chrome ignores a self-signed CA installed in the Android *system* certificate directory, and that higher Chrome versions need the CA in the **user** directory. A user-installed Reqable CA is therefore what lets Custom Tabs traffic decrypt.
- **Native SDKs** (Firebase, Sentry, analytics) use their own Android HTTP clients, usually OkHttp or `HttpURLConnection`. Those still honour NSC and the system proxy **unless they pin or bundle their own CAs**.

### 8.3 What commonly will not show up in Reqable (Wi-Fi proxy mode)

- **Flutter/Dart:** ignores the system proxy and user CAs.
- **Native C/C++ code** (libcurl, BoringSSL with bundled CA bundles) and **raw sockets:** ignore both.
- **gRPC:** the OkHttp transport generally honours NSC. Netty/Cronet/native transports may not, and gRPC needs HTTP/2 end-to-end.
- **Cronet / QUIC / HTTP/3:** uses UDP/443, which an HTTP proxy never sees. Reqable capture does not yet support HTTP/3 (QUIC).
- **Anything that disables proxies:** for example `Proxy.NO_PROXY`.

For these, use Reqable's mobile **collaboration/VPN mode**. The Reqable Android app provides an enhanced mode that captures apps not using the Wi-Fi proxy, such as Flutter apps. Note that TLS trust for Flutter still has to be handled in-app.

---

## 9. Wi-Fi Proxy Mode Specifics (Reqable on Android 13/14)

- **Proxy target:** the PC's LAN IP plus Reqable's port. Reqable listens on a **single port, 9000 by default**, and accepts HTTP/HTTPS/SOCKS on it. On the phone: Wi-Fi → (network) → Edit/Advanced → Proxy: **Manual** → host = PC IP, port = 9000. Then toggle Wi-Fi off and on. The proxy setting is **per-SSID** and does not cover mobile data.
- **Network requirements (Reqable FAQ):** same LAN **and** same segment (some LANs prohibit cross-segment communication). Allow the Reqable port through the PC firewall. Guest/AP-isolation Wi-Fi breaks this, and a **phone hotspot** is a recommended fallback.
- **Optional ADB route:**
  ```bash
  adb shell settings put global http_proxy <PC_IP>:9000
  ```
  Undo with:
  ```bash
  adb shell settings put global http_proxy :0
  ```
- **SSL Proxying in Reqable:** decryption of all SSL is on by default once the CA is installed. Use *Tools → SSL Proxying* to restrict decryption to your API domains (wildcards like `*.api.example.com`). Bypassed traffic shows a lock icon. This also helps when third-party SDKs pin.
- **Proxy vs VPN mode:**
  - **Wi-Fi proxy** captures only proxy-aware clients and is system-wide.
  - **Collaboration mode** (the Reqable phone app scans the desktop QR code) syncs the desktop CA to the phone and runs a VPN, which can capture specific apps and proxy-unaware traffic.

---

## 10. Troubleshooting and Limitations

### 10.1 Reading the result in Reqable (original guide's table)

| Situation | What it means |
|---|---|
| Requests appear and decrypt correctly | Your patch worked |
| Requests appear but show TLS errors | Certificate trust or pinning may still be blocking interception |
| No requests appear | Traffic may not be routed through Reqable |
| App crashes after patching | Rebuilding, signing, or integrity checks may be interfering |
| Some domains work but others fail | The app may use different networking libraries or trust rules |

### 10.2 Limitations of the patch (original guide)

The APK patch only modifies Android's **standard CA trust configuration**. It does not automatically change every networking library.

- **Certificate pinning:** an app using OkHttp's `CertificatePinner` or a custom TLS implementation can still reject Reqable's certificates. Android's XML configuration alone may not be sufficient.
- **Flutter:** many Flutter apps use Dart's own networking and certificate-handling behaviour. Reqable specifically notes that Android's Network Security Configuration method does not generally solve Flutter certificate trust.
- **APK integrity checks:** re-signing changes the application's identity at the signing-certificate level. Apps relying on Play Integrity, signature checks, or server-side validation may no longer function normally.
- **Split APKs:** if your application came from an Android App Bundle, you may need the complete set of APK splits rather than a single extracted base APK.

### 10.3 Detailed troubleshooting table (research report)

| Symptom | Likely cause | Fix |
|---|---|---|
| Requests appear in Reqable but handshake fails; logcat `CertPathValidatorException: Trust anchor for certification path not found` | User CA not trusted for that host: NSC not loaded, overridden by `domain-config`, or the wrong (phone-app) CA was installed | Re-run the `aapt2` checks; add `src="user"` to every `domain-config`; reinstall the **desktop** CA |
| `SSLPeerUnverifiedException: Certificate pinning failure!` | OkHttp `CertificatePinner` / RN pinning library | Disable the pinner in debug builds |
| `CertificateException: Pin verification failed` | NSC `<pin-set>` | `overridePins="true"` or `debug-overrides` |
| No requests at all (not even CONNECT) | Proxy bypass, wrong IP/port, firewall, AP isolation | Test Chrome first; check firewall/segment; use VPN/collaboration mode for proxy-unaware stacks |
| Chrome works, app shows nothing | App ignores system proxy (Flutter, native, `NO_PROXY`) | VPN/Enhanced mode; configure proxy in-app for debug |
| Only some domains fail | Per-domain `domain-config`/pins, third-party SDK pinning, mTLS | Add the domain's rules; set SSL Proxying bypass for SDK hosts; import the client cert in Reqable SSL settings for mTLS |
| App crashes or hangs on launch after repackaging | Signature/integrity checks, split-APK mismatch, Play Integrity | Debug build from source; re-sign all splits with one key |
| Media/Google endpoints missing | QUIC/HTTP/3 over UDP | Disable QUIC in the client for debug; Reqable capture does not support HTTP/3 |
| WebSocket silent | Non-HTTP/1.1 upgrade, or separate client | Reqable supports WS over HTTP/1.1; check the WS library's proxy/trust settings |
| CA install fails/crashes (Xiaomi) | Installer cannot read file | Move file to Download, grant file access |

### 10.4 Telling the three failure classes apart (validation logic)

Use logcat while exercising the app:

```bash
adb logcat | grep -iE "CertPathValidator|Trust anchor|pinning|Pin verification|SSLHandshake"
```

| What you see | Meaning |
|---|---|
| `Trust anchor for certification path not found` | **Trust-anchor failure.** The user CA is not trusted for that host (NSC missing, overridden, or wrong CA installed) |
| `Certificate pinning failure!` or `Pin verification failed` | **Pinning failure.** OkHttp pinner, RN library, or NSC `<pin-set>` |
| Nothing in Reqable at all, not even a CONNECT | **Proxy bypass.** The client ignores the system proxy or uses UDP/QUIC |

### 10.5 Suggested next step (original guide)

The best next step is to **inspect your APK** before deciding whether it needs only an XML change or additional modifications: its manifest, any existing network security configuration, and signs of networking libraries or certificate pinning. That determines whether the simple non-root Reqable setup is likely to work, without unnecessarily changing more of the APK. (The original guide offered to inspect an uploaded APK for this.)

---

## 11. Prioritised Checklist (Start-to-Finish)

1. **Export the CA from Reqable desktop** (the shield/certificate page). Push it:
   ```bash
   adb push <ca>.crt /sdcard/Download/
   ```
2. **Set a screen lock**, then install via Settings → Encryption & credentials → Install a certificate → **CA certificate** (Samsung: Other security settings → Install from device storage). Confirm it appears under **Trusted credentials → User**.
3. **Set the Wi-Fi proxy** to `<PC LAN IP>:9000` (or your configured port), and allow that port in the PC firewall.
4. **Browser test:** open an HTTPS site in Chrome. You should see decrypted traffic in Reqable. If you don't, fix the proxy/cert before touching the app.
5. **Verify the APK:** run the `aapt2` commands in Section 7.4. Confirm a single `networkSecurityConfig` attribute, the intended XML, and no stray `domain-config` / `pin-set`.
6. **Harden the NSC:** add `overridePins="true"` to the user certificates, and add `src="user"` inside any `domain-config` that has its own `trust-anchors`.
7. **Remove code-level pinning for test builds** (OkHttp `CertificatePinner`, RN pinning libraries, custom TrustManagers) using build-variant flags. Prefer moving to a source debug build with `debug-overrides` or Reqable's `debugImplementation` artifact.
8. **Run the app with logcat** (command in Section 10.4). Classify each failure with the tables above.
9. **Use Reqable SSL Proxying** to decrypt only your domains. For proxy-unaware components, switch to collaboration/VPN mode.

---

## 12. Verification Analysis: Is It Correct, and Where Is Caution Needed?

### 12.1 Provenance

- The **original guide** (the one pasted at the start) came from ChatGPT; it ends with a link to a ChatGPT "deep-research" connector.
- The **PDF you uploaded** is the research report produced in this conversation, assembled from Reqable docs, Android Developers docs, HTTP Toolkit, GitHub issues and similar sources.

### 12.2 Short verdict

The core of both documents is right, but neither is gospel. Trust the parts that match Android's official docs.

### 12.3 What is solid (and matches the docs)

- Your `base-config` with `system` + `user` is the correct opt-in. Apps targeting API 24+ don't trust user CAs by default, so this change is required.
- The remaining steps are: install the Reqable CA from the **desktop** app (each install has its own CA); do it **through Settings**, since tapping the file no longer installs it; then make sure no `domain-config`, `pin-set`, or OkHttp `CertificatePinner` overrides your trust setting.
- `debug-overrides` is ignored in a non-debuggable APK. For your patched APK, `base-config` is the right place.

### 12.4 Where to be more careful

- **The Android 17 note in the report.** The report cited an HTTP Toolkit post titled "Android 17 enables certificate transparency, and breaks custom CAs" (dated 23 Sep 2026). I could **not** find that post, and its title conflicts with the report's own conclusion that the user-CA setup should keep working.
- **WebView and Custom Tabs.** Those parts were inference, not official statements, and the report says so.
- **Settings menu paths.** For Pixel and Samsung, some paths came from SSL-vendor blogs rather than Google. Menus vary by phone, so searching Settings for "CA certificate" is more reliable.
- **Length.** The report was much longer than the situation strictly needs.

### 12.5 Extra check performed: Android 17 and certificate transparency

A targeted search of Android's official *Network security configuration* page found the following:

- Certificate transparency verification **isn't performed on connections that use custom trust anchors**. This supports the conclusion that your user-CA setup should be fine.
- Certificate transparency support exists only from Android 16 (API 36). On Android 16 it is opt-in (`<certificateTransparency enabled="true"/>`, disabled by default). From Android 17 (API 37) it is enabled by default (confirmed in the German-language version of the same page). There is also a documented way to opt out.
- **New item:** starting with Android 17 (API 37), **Encrypted Client Hello (ECH)** is used in "enabled" mode by default. The page says ECH support depends on the app's network library. This is a forward-looking item to watch if you later test on Android 17 with a proxy; it does not affect Android 13/14.
- You are on Android 13/14, so none of this affects you now. Re-test if you move to Android 17 or raise `targetSdk`.

### 12.6 What to actually do (condensed)

1. Export the CA from Reqable on your computer and install it on the phone via Settings → Install a certificate → CA certificate.
2. Test in Chrome through the Wi-Fi proxy first. If Reqable decrypts that, the certificate and proxy setup are good.
3. Open your patched app and watch `adb logcat`:
   - "Trust anchor for certification path not found" → trust configuration problem.
   - "Certificate pinning failure" → leftover pinning in the app.

If you share the logcat error or the app's `network_security_config.xml` (if it already had one), it is possible to say which case you are in.

---

## 13. Caveats

- The exact current Reqable certificate-download URL is **not documented** in Reqable's public docs. It lives in the app's built-in guide and was changed in v3.0.36, so rely on what the desktop app shows.
- WebView honouring user-CA trust via NSC, and Custom Tabs following Chrome's trust, are well-supported **inferences** rather than explicit official statements.
- **Looking ahead (Android 17):** Android's *Network security configuration* page says certificate transparency is enabled by default starting with Android 17 (API 37). The same page says that if any `<trust-anchors>` is `user` or inline (for example `@raw/cert.pem`), the verification is disabled, so this user-CA setup should keep working. A cited HTTP Toolkit post (23 Sep 2026) describing Android 17 as rolling out and breaking custom CAs **could not be verified** (see Section 12.4). Re-test when you raise `targetSdk` or update devices.
- Everything here assumes you **own** the app. The configuration changes described weaken TLS protections and should **never ship in production builds**.
- Some APK integrity/signature behaviour (Play Integrity, signature checks, server-side validation) can stop a re-signed APK from working normally regardless of the certificate setup.

---

## 14. Sources

**Reqable (official docs, repos, app)**
- Install Certificate: https://reqable.com/en-US/docs/getting-started/installation/
- Docs repo, installation page: https://github.com/reqable/reqable-docs/blob/master/en-US/getting-started/installation/index.md
- Docs repo, Windows changelog (v3.0.36): https://github.com/reqable/reqable-docs/blob/master/en-US/changelogs/windows/index.md
- Non-rooted Android blog post: https://reqable.com/en-US/blog/2024/11/03/post
- Android FAQ: https://reqable.com/en-US/docs/faq/android
- SSL proxying: https://reqable.com/en-US/docs/capture/ssl
- Proxy: https://reqable.com/en-US/docs/capture/proxy
- Introduction: https://reqable.com/en-US/docs/introduction/
- Collaboration mode: https://reqable.com/en-US/docs/getting-started/collaboration/
- `android-certificate-trust` helper: https://github.com/reqable/android-certificate-trust
- Issue #856 (CA install crash on HyperOS): https://github.com/reqable/reqable-app/issues/856
- Android app on Google Play: https://play.google.com/store/apps/details?id=com.reqable.android&hl=en_US

**Android / AOSP / Chromium**
- Network security configuration: https://developer.android.com/privacy-and-security/security-config
- `KeyChain.java` (AOSP): https://android.googlesource.com/platform/frameworks/base/+/master/keystore/java/android/security/KeyChain.java
- Chromium issue on WebView certificate transparency: https://issues.chromium.org/issues/41435501
- Chrome Custom Tabs announcement (archived): https://webarchive.library.unt.edu/web/20160706054808mp_/https://android-developers.blogspot.com/2015/09/chrome-custom-tabs-smooth-transition.html

**HTTP Toolkit and community write-ups**
- Android 11 tightens CA restrictions: https://httptoolkit.com/blog/android-11-trust-ca-certificates/
- Intercepting HTTPS on Android: https://httptoolkit.com/blog/intercepting-android-https/
- Android 14 system CA post: https://github.com/httptoolkit/httptoolkit-website/blob/main/src/content/posts/android-14-install-system-ca-certificate.mdx
- Where Android certificates are stored: https://yarygintech.com/articles/where-android-certificates-are-stored/
- Deep dive into certificate pinning on Android: https://securevale.blog/articles/deep-dive-into-certificate-pinning-on-android/
- Installing certificates on Android (menu paths): https://www.ssldragon.com/how-to/install-ssl-certificate/android/ , https://www.ssl2buy.com/wiki/how-to-install-ssl-certificate-on-android , https://www.ibm.com/support/pages/node/604209
- Setting an Android proxy: https://ritzherald.com/how-to-setup-proxy-on-android/ , https://voidmob.com/blog/how-to-use-proxy-on-mobile-tutorial

**Pinning libraries and React Native**
- TrustKit-Android: https://github.com/datatheorem/TrustKit-Android/blob/master/README.md
- `react-native-ssl-pinning` issue #158: https://github.com/MaxToyberman/react-native-ssl-pinning/issues/158
- `react-native-ssl-public-key-pinning`: https://www.npmjs.com/package/react-native-ssl-public-key-pinning
- React Native issue #10437 (WebSocketModule): https://github.com/facebook/react-native/issues/10437

**Flutter, Cronet and QUIC**
- Proxyman with Flutter: https://sarunw.com/posts/how-to-use-proxyman-with-flutter/
- Flutter proxy behaviour: https://blog.snoopbees.com/why-your-proxy-doesnt-work-on-flutter-apps-and-how-to-fix-it-bba9d7c9b3f2
- Cronet / HTTP3: https://medium.com/the-react-native-log/using-cronet-in-your-mobile-app-7dda3a89c132
- QUIC blocking / fallback to HTTP/2: https://hedgevpn.com/en/blog/quic-http3-blocked/

**Original guide's references**
- Reqable (API Debugging Proxy & REST Client), Apktool (https://apktool.org), the Reqable GitHub repository, and Android Developers documentation (zipalign 16 KiB guidance).

---

*End of document.*
