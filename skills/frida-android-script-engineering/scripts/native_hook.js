/* Native-only agent: no Java bridge required. Read-only metadata example. */
'use strict';
let count = 0;
const MAX_EVENTS = 20;
try {
  const address = Module.getGlobalExportByName('getpid');
  Interceptor.attach(address, {
    onLeave(_retval) {
      count += 1;
      if (count <= MAX_EVENTS) {
        try { send({ event: 'native-call', symbol: 'getpid', count: count }); } catch (_) {}
      }
    }
  });
  send({ event: 'hook-installed', symbol: 'getpid', max_events: MAX_EVENTS });
} catch (_) {
  send({ event: 'hook-install-failed', symbol: 'getpid', status: 'symbol unavailable' });
}
