# Python host, message handling and systematic troubleshooting

## Contents
1. Host lifecycle
2. Error-to-diagnosis table
3. Gadget proof ladder
4. Runtime recovery
5. Offline testing

## 1. Host lifecycle

`scripts/frida_host.py` provides USB/local device selection, attach/spawn, agent file loading, JSONL output and finite recording duration. The Python package `frida` is imported lazily so `--help` and `--dry-run` work even if not installed. It intentionally does not autodownload libraries, invoke root or automatically install APKs.

Host implementation must install message handlers **before** loading the script. `message.type == 'send'` contains a payload. `message.type == 'error'` contains a stack/description. For explicit binaries, `data` is a separate parameter; the included host reports only binary length, not the payload. Avoid dumping arbitrary `console.log` lines containing secrets.

```bash
python scripts/frida_host.py --mode attach --target com.example.ownedapp \
  --script agent.bundle.js --device usb --duration 45 \
  --out diagnostic-events.jsonl
```

If using spawn, create a process, attach, load agent, **then** resume. If loading fails after spawning, attempt to resume or terminate the test process cleanly as appropriate; don't leave a persistent paused target silently. For long sessions use a managed stop or keyboard interrupt and `session.detach()` in `finally`.

## 2. Problems, probable causes, checks

| Symptom | Prioritized diagnosis | Next measured action |
|---|---|---|
| `frida-ps -U` fails | adb/USB connection, daemon missing, version/ABI, permissions | Check `adb devices -l`, CPU ABI, daemon stdout, Frida version |
| `ReferenceError: Java is not defined` | Raw API script missing bridge on Frida 17+ | Compile TS agent with `frida-java-bridge`; or use Frida REPL |
| Class not found | Wrong process, class not loaded, loader mismatch, renamed class | Filter loaded classes; check static xrefs; enumerate loaders |
| `has more than one overload` | Ambiguous method name | Print overload prototypes and select exact one |
| Hook installed but no events | Feature not used, different process/loader, method inlined/native implementation, hook too late | Trigger deterministic test; verify runtime call path |
| App crashes after hook | Wrapper recursion, ABI/return mismatch, side effect or excessive logging | Remove hook; use logging-only exact overload; compare logcat |
| Native module missing | `.so` not loaded yet or ABI mismatch | Inspect process modules and dynamic load timing |
| Reports contain secrets | Unbounded object stringify/headers/data | Delete output securely under user's direction, narrow logging, re-run test fixtures |
| Memory/latency grows | Chatty hooks, unbounded queue or heap enumeration | Reduce event limit, count rather than capture bytes, measure baseline |
| Session detaches | App restart, process death, USB/daemon issue | Capture exit/logcat, relaunch cleanly and revalidate |

Never attribute failure to vendor anti-Frida logic without positive evidence. A module in `/proc/pid/maps` does not mean a JS script ran.

## 3. Gadget proof ladder

1. Locate and hash correctly packaged library.
2. Confirm the target process loaded the library.
3. Confirm a Frida session or autonomous agent initialized (observable ready message/service).
4. Confirm script loaded and its first `send({event:'ready'})` reached host/log.
5. Confirm the target Java class or native export was resolved.
6. Trigger a deterministic method and observe an event.
7. Confirm target behavior and file state are unchanged.

The old Instagram case ended around (2) for its Frida experiment, and then changed approaches. Do not present stages (3)–(7) as accomplished by that experiment.

## 4. Performance and recovery

Capture `adb logcat -d` in a limited, sanitized scope when permission allows and never include auth/token lines in a shared artifact. Keep version-specific known-good scripts under source control. Revert by stopping CLI/driver or unloading a Gadget-enabled authorized test build; confirm no background agents remain.

## 5. Offline tests and their meaning

Run:

```bash
python -m unittest discover -s tests -v
node --check scripts/java_hook_repl.js
node --check scripts/class_probe_repl.js
node --check scripts/native_hook.js
python scripts/frida_host.py --script scripts/native_hook.js --target com.example.ownedapp --dry-run
```

Pass here means parsing/schema and host argument paths work. It does **not** prove Frida could connect to an actual phone, attach or execute any Android method. Require real device-based acceptance separately.
