/*
  Frida 17+ API-loaded example, requires:
    npm install frida-java-bridge frida-compile
    ./node_modules/.bin/frida-compile scripts/java_hook_agent.ts -o agent.bundle.js
    python scripts/frida_host.py --script agent.bundle.js --target com.example.ownedapp
*/
import Java from 'frida-java-bridge';

const CLASS_NAME = 'android.app.Activity';
const METHOD_NAME = 'onResume';
const MAX_EVENTS = 50;

function emitEvent(payload: Record<string, string | number>) {
  try { send(payload); } catch (_) { /* no effects on app */ }
}

emitEvent({ event: 'script-ready', stage: 'agent-loaded' });
if (!Java.available) {
  emitEvent({ event: 'script-error', status: 'Java VM unavailable' });
} else {
  Java.perform(() => {
    try {
      const Cls = Java.use(CLASS_NAME);
      const original = Cls.onResume.overload();
      let count = 0;
      original.implementation = function () {
        try {
          return original.call(this);
        } finally {
          count += 1;
          if (count <= MAX_EVENTS) {
            emitEvent({ event: 'java-invocation', class_name: CLASS_NAME,
                        method: METHOD_NAME, count });
          }
        }
      };
      emitEvent({ event: 'hook-installed', class_name: CLASS_NAME, method: METHOD_NAME });
    } catch (_) {
      emitEvent({ event: 'hook-install-failed', status: 'Check class/overload and runtime loader' });
    }
  });
}
