# Smali bytecode: classes, signatures, registers and call graphs

## Contents
1. Classes and types
2. Methods and calls
3. Register layouts and common traps
4. Inheritance/callback tracing
5. Java/Native boundary
6. Systematic call graph record

## 1. Class and type descriptors

Smali uses Dalvik descriptors:

| Descriptor | Meaning |
|---|---|
| `Lcom/example/Widget;` | class `com.example.Widget` |
| `I`, `J`, `Z`, `V` | int, long, boolean, void |
| `B`, `S`, `C`, `F`, `D` | byte, short, char, float, double |
| `[B` | byte array |
| `Ljava/lang/String;` | Java `String` |
| `Ljava/nio/ByteBuffer;` | Java NIO `ByteBuffer` |
| `[Ljava/lang/String;` | String array |

A file `decoded/smali_classes2/X/AbC.smali` with `.class ... LX/AbC;` declares an obfuscated Java class `X.AbC`; the folder tells where it was disassembled from. `.super` specifies superclass, `.implements` interfaces, `.field` members and `.method` methods. `.source` may be absent or misleading.

## 2. Method prototypes and invokes

Consider:

```smali
.method public onBody(Ljava/nio/ByteBuffer;)V
    .locals 2
    invoke-virtual {p1}, Ljava/nio/ByteBuffer;->remaining()I
    move-result v0
    return-void
.end method
```

This is an instance method `void onBody(ByteBuffer)`; `p0` is the receiver and `p1` is the buffer. `invoke-static`, `invoke-virtual`, `invoke-interface`, `invoke-direct`, and `invoke-super` have different dispatch meaning. `move-result*` must immediately follow the invoke whose result it consumes. A constructor is `<init>`, class initializer is `<clinit>`.

For call sites search `->onBody(Ljava/nio/ByteBuffer;)V` or exact containing descriptor and use `scripts/smali_index.py --invoke-substr`. For object creation search `new-instance`, `invoke-direct <init>`, fields carrying the instance, interface dispatch, and method passed into third-party/native code. A class existing in DEX is not evidence it is called.

## 3. Registers: a critical editing/analysis rule

Dalvik registers are physical `v0 ... vN`; `p0 ...` are convenient aliases of trailing parameter registers. With `.locals L`, **an instance method** puts `p0` at `vL`, and the next parameters follow, with `long` (`J`) and `double` (`D`) consuming **two** 32-bit slots. If `.locals 6` in an instance method, then `p0 == v6` and `p1 == v7` for a single-width first explicit parameter. Writing to `v6` overwrites `this`! Increasing locals can move aliases; review all `v` registers and `p` uses after any change. With `.registers R`, the method declares total registers (locals plus all parameter slots), so calculate differently.

Certain instruction encodings accept only small register indices (e.g., some `invoke-kind {v0, ...}` forms encode argument registers in 4-bit fields limited to v0–v15). If parameters migrate above that limit after increasing locals, use a correct supported invoke/range pattern or restructure the method instead of blindly adding `.locals`. Wide registers also need alignment in argument ordering. Smali assembler errors can be register-encoding issues even when the human-readable code looks correct.

Read `.catch`, `.catchall`, `monitor-enter`/`monitor-exit`, `.line`, `goto`, labels and all control-flow edges before editing. Exception handling can be compiler-generated and easy to break. For a read-only analysis workflow, **identify** these constraints without altering instructions.

## 4. Follow a callback under obfuscation

1. Find base interface/abstract superclass by known library descriptor, not current obfuscated child name.
2. Use `.super` / `.implements` to enumerate implementations.
3. Identify concrete candidate method prototypes and their per-request or shared lifecycle.
4. Find `new-instance`/constructor sites and service/factory `makeCallbacks(...)` or equivalent.
5. Trace invoke call chain and native entry points as far as static evidence allows.
6. Confirm the chosen implementation actually runs with a controlled authorized test before drawing behavioral conclusions.

An observer/debug class may have the right-looking `onBody()` declaration but be gated off at runtime; an unconditional concrete callback can be a better explanation. The prior project demonstrated precisely this discrepancy; this is a **methodology lesson**, not a guarantee for future builds.

## 5. Native and JNI boundaries

Inspect `.method native` and `System.loadLibrary`/`Runtime.load` strings, then match libraries under `lib/<abi>/*.so`. JNI registration may be dynamic via `RegisterNatives` so lack of a `Java_...` export does not disprove a JNI call. A native `sendRequest` may pass callback objects into C++ and invoke them later. APK resource and Smali analysis cannot fully reconstruct compiled native logic without separate disassembly and runtime evidence.

## 6. Evidence ledger

```text
Symbol: Lcom/example/Foo;->bar(Ljava/lang/String;)V
Role: candidate transition method
Declaring file/line: smali_classes2/com/example/Foo.smali:83
Superclass/interfaces: ...
Invokers: caller path:line, opcode and target
Objects/fields involved: ...
Outputs/callees: ...
Reachability status: static only / runtime confirmed
Uncertainty: overload ambiguity, native callback, feature flag, split loader
```

Do not turn an observed correlation into a causal claim without tracing and validation. Use JADX pseudocode alongside exact Smali anchors where possible.
