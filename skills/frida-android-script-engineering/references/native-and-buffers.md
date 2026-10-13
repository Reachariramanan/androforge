# Native hooks, ABI reasoning and safe buffers

## Contents
1. Native discovery and module timing
2. Read-only Interceptor pattern
3. Android ABI/JNI distinctions
4. ByteBuffer safety for Java paths
5. Native memory validation

## 1. Identify an actual native target

Inspect the original APK's `lib/arm64-v8a`, `lib/armeabi-v7a`, `lib/x86_64` directory names and ABI-specific exports. A module name alone is not enough: `libfoo.so` might be loaded late; an export can be absent in a stripped build. `Process.findModuleByName()` returning `null` requires a delayed-load strategy or a different candidate.

Prefer a low-frequency, narrow, well-understood function in a debug app. Use `Module.getGlobalExportByName('getpid')` as a harmless SDK-compatibility sample only; it is not guaranteed to fire during a short test. The provided `scripts/native_hook.js` logs a bounded count and does not alter return values.

## 2. Example observer

```js
const f = Module.getGlobalExportByName('getpid');
let count = 0;
Interceptor.attach(f, {
  onLeave(retval) {
    if (count++ < 20) {
      send({ event: 'native-return', symbol: 'getpid' });
    }
  }
});
```

Don't make return-value claims from `retval` without knowing the function's C type and ABI. If an attached interceptor changes memory, parameters or return values, that is no longer a read-only hook and needs separate review and testing. ABI mistakes in native hooks can immediately crash the process.

## 3. JNI assumptions

A JNI-exported native method has implicit `JNIEnv*` and `jobject`/`jclass` arguments ahead of Java parameters; stripped/private functions may follow custom conventions. For ARM/Thumb pointers and instruction addresses, use Frida's documented export resolution or platform APIs rather than manual bit-twiddling. Understand whether a pointer's backing memory remains valid past `onLeave` before reading or retaining it.

## 4. ByteBuffer/non-consuming observation

A Java `java.nio.ByteBuffer` may be direct, read-only, sliced, heap-backed or have a nonzero `position()`/nondefault `limit()`. Calling `get()` on the original advances its position and can change target-app behavior. **Duplicate before reading**; do not use `.array()` as a universal shortcut since direct buffers might not support it.

Example for an explicitly authorized *small* test payload:

```js
function readPreviewSafely(byteBuffer, cap) {
  const duplicate = byteBuffer.duplicate();
  const max = Math.min(duplicate.remaining(), cap);
  const output = [];
  for (let i = 0; i < max; i++) {
    output.push(duplicate.get() & 0xff);
  }
  return {count: max, bytes: output};
}
```

Caveat: Frida Java wrappers and buffers have bridging details to verify on-device, and per-byte JS access can be slow. For ordinary tasks log only `remaining()` and class name. Never write raw sensitive body bytes by default. If a payload must be inspected, cap size, use authorized test data, and verify the app sees the unchanged `position()`/`limit()` before and after.

## 5. Native pointers

`NativePointer.readByteArray(length)` and string reads need safe lengths and valid lifetimes; a null check only proves a pointer is not zero, not that a range is readable. Limit all copies and prefer known struct definitions over heuristic memory dumps. Don't scan unrelated address spaces, private user data or system processes. Log module + symbol and bounded timing/count metrics instead of contents.
