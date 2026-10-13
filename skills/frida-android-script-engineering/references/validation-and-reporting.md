# Validation checklist and report specification

## 1. Minimum test stages

| Stage | Evidence | Pass criterion |
|---|---|---|
| Syntax | `node --check`, TypeScript compiler output | No parser errors |
| Environment | `frida --version`, `frida-ps -U` | Client reaches authorized device |
| Correct target | class/overload/module resolves | Exact signature and correct process |
| Hook activity | test action -> event | At least one deterministic event plus event count |
| Semantics | baseline vs instrumented UI/output | Original still called exactly once, output unchanged |
| Stability | duration, logcat, UX | No instrumentation-related hang/crash |
| Resource safety | event cap, memory/time counts | No unbounded volume or significant slowdown |
| Privacy | output scrub check | No credentials, identifiers, tokens or raw private data |
| Reproducibility | tool versions, SHA-256, commands | Independent operator can reproduce |

## 2. Recommended result template

```markdown
# Frida instrumentation test report

- Authorization/test scope: app/device/test data only
- APK/package/version/SHA-256: ...
- Device API/ABI: ...
- Frida client/server/compiler/bridge versions: ...
- Agent entrypoint and SHA-256: ...
- Class, method and overload: ...
- Triggering action: ...
- Readiness signal received: yes/no
- Hook installed: yes/no
- Hook invocation count: ...
- Evidence retained: bounded metadata JSONL, no payloads
- Baseline behavior / instrumented behavior: ...
- Crash/anr/latency: ...
- Known limitations and unverified inferences: ...
- Rollback: detach, uninstall owned test build when applicable
```

## 3. Failure reporting

A device connection error is **not** a code validation failure. A syntactically valid agent with zero events is **not** a successful hook. A class lookup that succeeds but never reaches the chosen code path is evidence of target selection uncertainty. Label each separately; do not collapse into one 'works' status.
