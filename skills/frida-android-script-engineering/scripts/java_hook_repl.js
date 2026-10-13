/*
  Frida REPL-only example: frida -U -f com.example.ownedapp -l scripts/java_hook_repl.js
  The REPL provides Java bridge. If using Python/Node API under Frida 17+,
  use the separate TypeScript bridge-imported agent and compile it first.
  No arguments, results, headers, identifiers or payloads are logged.
*/
'use strict';

const CONFIG = {
  className: 'android.app.Activity',
  methodName: 'onResume',
  argTypes: [],
  maxEvents: 50
};

function emitSafe(event) {
  try { send(event); } catch (_) { /* telemetry failure must not harm app */ }
}
emitSafe({ event: 'script-ready', status: 'bridge-not-yet-checked' });

if (typeof Java === 'undefined' || !Java.available) {
  emitSafe({ event: 'script-error', status: 'Java bridge or VM unavailable' });
} else {
  Java.perform(function () {
    try {
      const klass = Java.use(CONFIG.className);
      const method = klass[CONFIG.methodName];
      const original = method.overload.apply(method, CONFIG.argTypes);
      let count = 0;
      original.implementation = function () {
        const args = Array.prototype.slice.call(arguments);
        try {
          return original.call(this, ...args);
        } finally {
          try {
            count += 1;
            if (count <= CONFIG.maxEvents) {
              emitSafe({ event: 'java-invocation', class_name: CONFIG.className,
                         method: CONFIG.methodName, count: count });
            }
          } catch (_) {}
        }
      };
      emitSafe({ event: 'hook-installed', class_name: CONFIG.className,
                 method: CONFIG.methodName, max_events: CONFIG.maxEvents });
    } catch (e) {
      emitSafe({ event: 'hook-install-failed', status: String(e).slice(0, 100) });
    }
  });
}
