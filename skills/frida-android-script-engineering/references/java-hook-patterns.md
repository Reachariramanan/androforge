# Java hook implementation patterns

## Contents
1. Safe wrapper pattern
2. Overloads and original-method guarantees
3. Primitive, object and exception handling
4. Runtime timing and concurrency
5. Common pitfalls

## 1. Behavioral contract

For an observation-only hook, the application's method must receive **the same receiver, arguments, original invocation count, return value and exception**, aside from controlled trace overhead. Never suppress errors from the original function or retry it. Print nothing sensitive by default.

Use a preselected overload handle to call the original:

```js
Java.perform(() => {
  const Cls = Java.use('com.example.demo.Calculator');
  const original = Cls.sum.overload('int', 'int');
  let events = 0;
  original.implementation = function (x, y) {
    const start = Date.now();
    try {
      // It throws exactly once if the original throws.
      return original.call(this, x, y);
    } finally {
      // Telemetry must never throw across this boundary.
      try {
        if (events++ < 100) {
          send({event: 'method-exit', method: 'Calculator.sum', elapsed_ms: Date.now() - start});
        }
      } catch (_) { /* prevent logger errors changing app behavior */ }
    }
  };
});
```

Only use code targeting that exact class after verifying it exists in the authorized build. `this.sum(x, y)` can select a different overload and may be ambiguous in a hooked method; the explicit overload is more reliable. The host must register a `send` message handler to receive telemetry.

## 2. Overloads and Java method families

- Inspect `method.overloads` and log `argumentTypes.map(t => t.className)` **once** at setup.
- Use `Cls.foo.overload('java.lang.String', 'int')` and preserve returned Java values. Do not stringify complex objects merely to log them: `toString()` can execute app logic, incur I/O, or reveal secrets.
- `void` methods usually return `undefined` from JS; return the original return value even when void to keep the pattern consistent.
- `$init` constructors are not equivalent to ordinary instance methods; start with a regular lifecycle/event method and add constructors only with explicit need.
- `Java.registerClass` changes runtime behavior; not appropriate for a default read-only debugging skill.
- Avoid hooking generic methods like `java.lang.String.toString` globally, or broad allocators, because hook overhead, recursion and privacy exposure can be severe.

## 3. Exceptions and recursion

A safe `try/finally` runs a small logger even if the app method throws, but it **must not catch and convert the original exception into a success result**. A logger error can be swallowed; an original exception should propagate. Avoid reentering the same method from the logger. If metadata acquisition calls into the same Java method family, add an explicit reentrancy guard and explain its limits.

Never call original code twice to obtain before-and-after values. If a failure occurs in diagnostic code before calling the original, the wrapper should still make the original invocation. Keep the first probe trivial.

## 4. Performance and timing

- Start with a 50–100 event cap; log only once per sampling interval on high-frequency methods.
- Timing with `Date.now()` is coarse but adequate to estimate catastrophic slowdown; avoid excessive stack captures in hot paths.
- Don't enumerate heap instances or class loaders from each method callback; do it once at script initialization.
- JS messages are asynchronous from host perspective and may be reordered relative to app events; attach monotonic counters to telemetry. Keep outputs bounded and flush the host JSONL safely.
- Don't block Android main/UI thread with file I/O, network calls, expensive formatting or multi-megabyte binary copies. Native callbacks can run on unusual threads: avoid Java operations there unless the runtime guarantees proper attachment.
- Repeated attach cycles may layer multiple hooks across restarts; cleanly detach/unload and re-run with one agent at a time.

## 5. Testing matrix for each hook

Test class exists; selected overload matches; readiness event observed; a controlled UI action emits an invocation; return and exception behavior match baseline; app UI remains responsive; event cap respected; recorded data contains no secrets; and stopping the host causes instrumentation to detach without changing the app disk state.

Prefer a controlled local toy app with an explicitly known `sum(int,int)` method and synthetic input, then substitute the verified real target. If the target method is not callable on the actual build, state the blocker and provide a precise discovery plan, not an untested success claim.
