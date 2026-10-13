---
name: frida-android-script-engineering
description: >-
  Write, debug, port, and validate Frida JavaScript or TypeScript agents for authorized Android application testing and reverse engineering. Use when asked to build Frida hooks, trace Java/ART or native methods, inspect loaded classes and overload signatures, use frida-server or Gadget in an owned test build, automate attach/spawn with a Python host, troubleshoot Frida Java bridge and class-loader failures, or adapt instrumentation to changed and obfuscated APK versions. Prioritize observable, read-only hooks that preserve app behavior and emit bounded non-sensitive diagnostics.
---

# Frida Android Script Engineering

## Purpose

Produce **working, testable, explicitly scoped instrumentation** for an Android app the user owns or is authorized to study. The deliverable is not merely a snippet: supply a target-discovery rationale, a hook script, the correct host/runtime invocation, sanitized evidence, tests and a rollback path. Treat target identifiers in sample code as placeholders; never assume obfuscated class names remain constant between APK versions.

Operate only on a device/app in authorized scope. Do not build stealth, credential extraction, session-token capture, remote collection, or methods for evading integrity checks. Default to non-mutating lifecycle/function telemetry, redaction, rate limits, and a local explicit test window. Never hide lack of access to a device or pretend a snippet was run.

## Inputs and expected outputs

Discover or collect these when available: target package name, source APK/build version and SHA-256, Android API level and CPU ABI, rooted/test-device or owned debuggable app/gadget strategy, Frida host/server versions, exact desired observable behavior, permission to record any sensitive values, and whether the agent runs in the Frida **REPL** or through the Python/Node **API**.

Return an implementation bundle or a clearly marked example containing:

1. **Discovery sheet:** package/version, class or native library candidate, full method descriptor/overload, loader/module, and runtime evidence supporting hook selection.
2. **Agent:** runnable source code in the correct Frida runtime mode, preserved method semantics, scope filtering and error handling.
3. **Launch commands:** host/device preflight, attach versus spawn choice, and bridge compilation step if applicable.
4. **Validation:** proof the hook fired, app still works, finite log volume, no credentials written, and any unresolved gaps.
5. **Rollback:** unload/detach; for Gadget-only work, restore original signed test build.

## Mandatory decision tree

1. **Need Frida at all?** For broad code structure, use Apktool/JADX first; for lifecycle behavior or dynamic type discovery, continue with Frida. For permanent behavior within a patched offline APK, use separate Smali editing workflow, not a Frida hook disguised as an offline feature.
2. **Can the app/device be instrumented?** Prefer an owned debug build/emulator/rooted lab phone with compatible `frida-server`. Use Gadget only when included in an owned/authorized app build; embedding or loading a shared library is **not** evidence that its agent executed.
3. **Need ART Java methods?** Use `Java.perform`, `Java.use`, full overload resolution and class-loader diagnosis. See [references/discovery-and-hooks.md](references/discovery-and-hooks.md) and [references/java-hook-patterns.md](references/java-hook-patterns.md).
4. **Need native code?** Identify ABI/module/symbol and use `Interceptor.attach` without replacing behavior by default. See [references/native-and-buffers.md](references/native-and-buffers.md).
5. **Need a custom Python host?** Bundle an agent correctly for Frida 17+ before `session.create_script`; see [references/runtime-and-setup.md](references/runtime-and-setup.md) and [references/host-debugging.md](references/host-debugging.md).
6. **Porting a hook to a new APK?** Rediscover by functional signatures and caller/callee relationships, not only class names. See [references/version-adaptation.md](references/version-adaptation.md).

## Operational workflow

### Phase 0 — Guardrails and reproducibility

- Confirm authorized package and dedicated test device/account; prefer fixtures and mock/test data.
- Record `frida --version`, `python -m pip show frida frida-tools`, `adb devices -l`, `adb shell getprop ro.product.cpu.abilist`, Android version, and package/version. Record exact tool commands. Do not publish sensitive device IDs in shared reports.
- Start with **metadata-only** logging (method entry/count/timing with a generic event name); adding live values requires a separate explicit purpose and redaction review.
- Set a finite event budget, e.g. 100 events, and isolate hooks to an exact target or small predicate. Never enumerate or log all possible values by default.

### Phase 1 — Establish Frida communication

Follow [references/runtime-and-setup.md](references/runtime-and-setup.md). Install Frida tooling in a virtual environment and ensure Frida server/device architecture and protocol version are compatible; don't blindly follow a stale version pin. Official smoke test: `frida-ps -U`.

**Critical Frida 17+ distinction:** raw `Java.*` scripts work when loaded by the Frida CLI REPL or `frida-trace`, which supply the Java bridge. A **custom Python/Node API** agent must explicitly import `Java` from `frida-java-bridge` and be bundled with a compiler. Do **not** feed the raw REPL Java template directly to `create_script()` and assume `Java` exists. For templates see `scripts/java_hook_repl.js` and `scripts/java_hook_agent.ts`.

### Phase 2 — Build a target map before hooking

- Inspect the APK structure and obfuscated call graph using Apktool/JADX and the dedicated APK-analysis skill if provided.
- Record a candidate class descriptor, Java dotted class name, method prototype, likely loader, Java/native boundary, confidence and proof. For renamed/obfuscated classes, search distinctive interfaces, argument types, method shapes and construction/call sites.
- Dynamically enumerate a **bounded prefix-filtered subset** using `scripts/class_probe_repl.js`; never print an entire app's loaded classes into the console.
- Verify candidate class loading and exact overload **before** assigning `.implementation`.

### Phase 3 — Implement the smallest safe hook

For a class and overload already verified in this particular APK, generate a read-only starter without hand-editing the template:

```bash
python scripts/generate_java_hook.py --class com.example.demo.Calculator \
  --method sum --arg int --arg int --mode repl --out generated_sum.js
frida -U -f com.example.ownedapp -l generated_sum.js
# Or generate --mode api --out generated_sum.ts and compile its Java bridge first.
```

The generator **does not** discover classes; its inputs must come from static/runtime research. The generated script observes only count/class/method, not argument values.

- Attach to one method first, then incrementally add hooks. In Java, select `.overload('java.lang.String', 'int')` (for example) when necessary. Call the saved overload's original method and return its result unchanged; do not invoke `this.method(...)` if ambiguous/recursive.
- Use a guard on logging itself, not on the target's original call. Avoid turning benign telemetry errors into application errors. Keep callbacks small; defer expensive parsing where supported, with bounded queues/backpressure.
- Do **not** mutate input `ByteBuffer` position or limits; use `.duplicate()` and respect remaining bytes if data-copying is authorized. For native memory use size bounds, pointer validity and correct architecture-specific ABI.
- Never emit access tokens, cookies, credentials, account identifiers, raw request/response bodies, arbitrary files or PII by default. If inspection of a specific value is explicitly approved, mask or hash only that permitted field locally.
- Include a one-line readiness event plus an event counter so that “script loaded” can be separated from “method called.”

### Phase 4 — Execute and validate

For quick Java REPL experiments:

```bash
frida -U -f com.example.ownedapp -l scripts/java_hook_repl.js
# Or attach to a process already running:
frida -U -n com.example.ownedapp -l scripts/class_probe_repl.js
```

For custom API-driven hosts with **Frida 17+**, compile an agent first (exact syntax/details in [references/runtime-and-setup.md](references/runtime-and-setup.md)):

```bash
npm install frida-java-bridge frida-compile
./node_modules/.bin/frida-compile scripts/java_hook_agent.ts -o agent.bundle.js
python scripts/frida_host.py --mode attach --target com.example.ownedapp --script agent.bundle.js --duration 30 --out events.jsonl
```

- Trigger the relevant feature in a controlled app session. Distinguish readiness, hook-installed, observed-invocation and app-behavior success; all are different.
- Compare uninstrumented and instrumented runs for crashes, hangs, latency and feature correctness. Record time/version/test dataset and any negative evidence.
- Run `node --check` on JS templates, `python -m unittest discover -s tests`, and test generated TypeScript with the actual compiler whenever dependencies are installed. Syntax validation is **not** runtime validation.

### Phase 5 — Troubleshoot iteratively

Read [references/host-debugging.md](references/host-debugging.md). Prioritize compatibility, bridge availability, process choice, class loader, overload signature, eager vs late loading, native library delay and original-method recursion. For a Gadget experiment, verify (a) library mapped, (b) agent runtime ready, (c) hook installed and (d) call observed. Do not infer cause from the first signal.

## Included tools

- `scripts/frida_host.py`: bounded-duration USB/local attach/spawn driver, JSONL event output, readable runtime errors. Loads **bundled Java agents** or Java-free native JS. No remote uploads.
- `scripts/java_hook_repl.js`: readable Frida REPL Java overload-hook starter, intentionally non-sensitive and behavior-preserving; edit target class/method/signature.
- `scripts/java_hook_agent.ts`: Frida 17+ bridge-imported TypeScript starter for a custom host.
- `scripts/class_probe_repl.js`: prefix-limited loaded-class discovery with a strict maximum count.
- `scripts/native_hook.js`: non-mutating native `getpid` trace exemplar.
- `scripts/generate_java_hook.py`: emit a version-specific, metadata-only hook from a verified class and overload.
- `scripts/preflight.py`: offline environment report, no installation, device modification or download.
- `tests/`: Python/JS syntax checks and offline host logic tests. These do not replace device smoke tests.

## Historical lesson (do not overclaim)

In the user's earlier authorized Instagram/Tigon case study, a Frida Gadget `.so` was present in the process map after a patched `loadLibrary`, but **no JS agent activity or verified hook events** were observed. The experiment was reverted and the later verified response capture used **direct Smali instrumentation**, not Frida. Consequently, never claim working Frida instrumentation solely from the module appearing in `/proc/<pid>/maps`, and do not assert anti-instrumentation caused failure without corroborating evidence. See [references/version-adaptation.md](references/version-adaptation.md).

## Reference index

- [Runtime installation, REPL vs API, bridging](references/runtime-and-setup.md)
- [Class/method discovery, overloads, class loaders](references/discovery-and-hooks.md)
- [Behavior-preserving Java hooks and concurrency](references/java-hook-patterns.md)
- [Native exports, ABIs and ByteBuffer semantics](references/native-and-buffers.md)
- [Custom Python host, errors and debug rubric](references/host-debugging.md)
- [Adapting obfuscated targets across APK versions](references/version-adaptation.md)
- [Acceptance and sanitized reporting](references/validation-and-reporting.md)

Official sources, reviewed October 2026: https://frida.re/docs/android/ , https://frida.re/docs/bridges/ , https://frida.re/docs/javascript-api/ , https://frida.re/docs/modes/ . Use these when command syntax or API behavior may have changed.
