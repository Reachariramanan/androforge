/* REPL-only class discovery; limit emitted names to avoid log explosions. */
'use strict';
const PREFIX = 'com.example.'; // EDIT for authorized app; do not print all names
const MAX_RESULTS = 40;

function emit(payload) { try { send(payload); } catch (_) {} }
if (typeof Java === 'undefined' || !Java.available) {
  emit({ event: 'probe-error', status: 'Java VM/bridge unavailable' });
} else {
  Java.perform(function () {
    try {
      const names = Java.enumerateLoadedClassesSync();
      let totalMatching = 0;
      let emitted = 0;
      for (const name of names) {
        if (!name.startsWith(PREFIX)) continue;
        totalMatching += 1;
        if (emitted < MAX_RESULTS) {
          emitted += 1;
          emit({ event: 'loaded-class', class_name: name, count: emitted });
        }
      }
      emit({ event: 'probe-complete', count: totalMatching, max_events: MAX_RESULTS });
    } catch (_) { emit({ event: 'probe-error', status: 'Enumeration failed' }); }
  });
}
