# Frida discovery: target method, overload and loader

## Contents
1. Inputs and static-to-runtime crosswalk
2. Class discovery
3. Method signatures and overloads
4. Class loaders, delayed loads and nested processes
5. Native symbols
6. Selection record

## 1. Map APK evidence to Frida types

From decompiled Smali `Lcom/example/demo/Store;->save(Ljava/lang/String;I)Z`, Frida expects Java class `com.example.demo.Store`, method `save`, and overload `('java.lang.String', 'int')`, returning boolean. Do not include return type in `.overload(...)`; use it to verify the selected overload's expected behavior.

A class named `LX/abc;` in a specific APK may move in another version. Reconstruct function by an interface implementation, method signature, call sites, native boundary or constant resource name. If an APK has `smali_classes2/` etc., those are physical DEX partitions, not Java packages.

## 2. Investigate the loaded classes with bounded queries

Use `scripts/class_probe_repl.js` after editing `PREFIX` and `MAX_RESULTS` for your own app's package. Execute in Frida REPL:

```bash
frida -U -n com.example.ownedapp -l scripts/class_probe_repl.js
```

`Java.enumerateLoadedClassesSync()` only shows loaded classes, not everything packaged in `classes.dex`. A missing name can mean wrong process, not-yet-loaded dex, isolated class loader, spelling or refactoring. For production-scale apps, filter in the VM if possible and print only short summaries; never dump the entire class set.

Alternative method discovery using Frida's `Java.enumerateMethods()` with a **narrow** pattern:

```js
Java.perform(() => {
  const matches = Java.enumerateMethods('com.example.demo.*!on*');
  console.log(JSON.stringify(matches.slice(0, 10)));
});
```

For large apps, `Java.enumerateMethods` may still be expensive; select the package/module and avoid repeated scans in hot paths. The method glob syntax and return structure can vary with bridge version; validate against the active JavaScript API.

## 3. Overload correctness

Once a class is found:

```js
Java.perform(() => {
  const Widget = Java.use('com.example.demo.Widget');
  Widget.update.overloads.forEach((o) => {
    const a = o.argumentTypes.map(t => t.className).join(', ');
    console.log('update(' + a + ') -> ' + o.returnType.className);
  });
});
```

For `.overload('int', 'java.lang.String')` types use Java runtime type labels, not Smali `I` or `Ljava/lang/String;`. Distinguish primitives (`boolean`, `int`, `long`) from boxed types (`java.lang.Integer`). Arrays use `['[B', '[Ljava.lang.String;']` notation when the bridge expects a JVM name; test against actual enumerated argument types.

Static vs instance method matters. For a non-static method the receiver is `this`; for a static method original calls can use the class wrapper. Constructors use `$init` and require special caution; do not prototype on constructors until a simple regular method is proven.

## 4. Class-loader mismatch

A custom ClassLoader, split APK, or dynamic dex can hide app classes from the default Java factory. Record `Java.enumerateClassLoaders()` results and use `Java.ClassFactory.get(loader).use(name)` for a known loader when verified. Do not permanently switch a shared factory loader without explaining impact on other hooks.

Lifecycle timing matters: `Java.perform` schedules when the app loader is available, while `Java.performNow` attaches immediately and should only be used when app loader access is not needed. For modules dynamically loaded later, install a bounded event-driven hook/monitor in a controlled debug session or rerun after the feature is activated. Avoid hooking broad class loading callbacks in production-sized apps unless performance is measured.

Inspect secondary process names (such as `com.example.ownedapp:remote`) and select the process actually executing the target. A valid hook in the wrong process produces no events.

## 5. Native code

Map `.so` names to architectures under `lib/<abi>/` and note whether the function is JNI-exported (`Java_com_example_Foo_bar`), a named native export, or a stripped internal symbol. `Process.findModuleByName('libdemo.so')` may return `null` before dlopen. For a known visible export use `module.findExportByName('foo')` or current documented process/module API, then `Interceptor.attach` only after checking for `null`. JNI signature, calling convention and pointer lifetime must be verified with static analysis; never infer parameter layout only from a decompiler guess.

## 6. Record the final target selection

```text
App/version/sha256: ...
Process + ABI: ...
Candidate Java dotted name or native module/export: ...
Method overload (arguments and return): ...
Loader or module base: ...
Static evidence (file + line/caller): ...
Dynamic evidence (class/overload exists): ...
Hook purpose and sensitivity: metadata-only
Fallback if renamed: interface/call-chain/signature anchor
Confidence / remaining ambiguities: ...
```
