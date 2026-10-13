# Version diffs and locating Android networking/data paths

## Contents
1. Compare package versions structurally
2. Find functionality across obfuscation
3. Networking candidate taxonomy
4. Trace callbacks without semantic overreach
5. Historical case and pitfalls

## 1. Version comparison protocol

Inventory old and new builds independently:

```bash
python scripts/apk_inventory.py old.apk --json reports/old.json
python scripts/apk_inventory.py new.apk --json reports/new.json
python scripts/compare_inventories.py reports/old.json reports/new.json \
  --json reports/structural-diff.json
```

Compare original hashes and file count, DEX partitions, native ABIs/library basenames, manifest presence and resource/asset counts. Decode both with the **same documented Apktool version** if possible; record tool changes if upgrading for newer formats. Index relevant Smali method/prototype and type-use candidates in both versions. DEX partition numbers and absolute line offsets can shift without a functional rewrite.

## 2. Port by behaviors and call graph

Select semantic anchors in this order when feasible: known public library interface, method argument/return descriptors, superclass/implements, object factory use, native JNI declaration, distinctive res/xml or manifest component, string or stable logging tag, and verified runtime call path. Build a table old symbol -> old role -> new candidates -> new evidence -> confidence. If several candidates remain, state why and use read-only test instrumentation on an authorized device to disambiguate.

## 3. Networking libraries worth recognizing

The app might use `OkHttp`, `Retrofit`, `Volley`, `HttpURLConnection`, `Cronet`, gRPC, `WebView` or a native client such as Tigon. Detect library packages in Smali, assets and `.so` names; do not assume a specific one without evidence. Candidate signatures include request builders, `Callback.onResponse`, completion/error handlers, Java NIO `ByteBuffer` consumers, native request service JNI methods, stream transfer methods and per-request callback object construction.

Useful broad search terms **as initial clues only**:

```bash
python scripts/smali_index.py decoded --class-substr 'okhttp' --limit 40
python scripts/smali_index.py decoded --method-substr 'onResponse' --limit 60
python scripts/smali_index.py decoded --method-substr 'onBody' --limit 60
python scripts/smali_index.py decoded --class-substr 'tigon' --limit 60
```

Validate every hit by Smali hierarchy/call site. Network observers may expose headers but no content; download callbacks can contain partial fragments, encrypted/compressed representations, or payload slices. A method name such as `onBody` does not prove decrypted full-body access.

## 4. No silent body capture or overclaiming

A callback executing for one sampled request doesn't establish universal coverage. Track whether each candidate fires under login/feed/image/video/upload cases in a consented test environment, the number of chunks, byte lengths and mismatch states (only if authorized). Avoid logging bearer tokens, cookies, password fields or request/response bodies as a default. A `ByteBuffer` should be inspected read-only on a duplicate to avoid consuming the source; control thread and file I/O overhead. Full outgoing-body stream correlation is a separate problem, not automatically solved by response callback discovery.

## 5. Specific previous technical lesson

In the historical Instagram 448 test APK, a `TigonObservable` debug observer produced lifecycle metadata while its `onDownloadBody` and `onUploadBody` did not fire during observed tests. A concrete subclass extending Tigon's callback base was then located by examining `onBody(ByteBuffer)` and the callback factory; this yielded verified JSON response content and fragments of media, not a complete universally applicable capture pipeline. A register error occurred after a `.locals` change where `p0` aliased an overwritten `v` register; a repair was built and installed without a subsequent comprehensive app-feed verification. Another earlier attempt had a Frida Gadget library mapped but no confirmed runtime agent. These findings teach **how to distinguish evidence levels**. Do not reuse obfuscated class IDs or portray the historical experiments as a guaranteed ready-made fix for newer versions.
