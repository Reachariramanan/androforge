# Frida setup, device connectivity and runtime modes

## Contents
1. Preparation and compatibility
2. Host installation and test device
3. CLI execution
4. Java bridge change in Frida 17+
5. Bundled agents and Python hosts
6. Recordkeeping

## 1. Prepare an authorized lab

Use an Android emulator, owned debug build, or consented test device. Confirm USB debugging and `adb devices -l`. Use only USB/loopback for the instrumentation endpoint; avoid exposing a Frida service to an untrusted network. Prefer a controlled dummy account and no sensitive background apps.

Check:

```bash
python --version
python -m pip --version
adb version
adb devices -l
adb shell getprop ro.product.cpu.abilist
adb shell getprop ro.build.version.sdk
adb shell getprop ro.build.version.release
```

On Windows PowerShell, use `py -m venv .venv` and `.\.venv\Scripts\Activate.ps1`; on macOS/Linux use `python3 -m venv .venv` and `. .venv/bin/activate`. In a shell whose policy blocks activation, run the venv `python` directly. Then:

```bash
python -m pip install --upgrade pip
python -m pip install frida-tools frida
frida --version
python -m pip show frida frida-tools
frida-ls-devices
```

This installs **host utilities**. It does not itself provide a running Frida service inside the Android phone.

## 2. Configure the device side

For the official rooted-device route (use only with permission):

1. Read the Android ABI (not the desktop CPU). Choose a **matching** Frida Android server asset from https://github.com/frida/frida/releases. Check whether local host/target Frida versions are compatible; using the same core version is the least ambiguous starting point.
2. Download from the official release page, verify release identity and SHA-256 if published, decompress (often XZ), and name the executable `frida-server`.
3. Push to the device, mark executable and start it with the permissions required by the particular test device:

```bash
adb push frida-server /data/local/tmp/frida-server
adb shell chmod 755 /data/local/tmp/frida-server
# Only when the test device allows this:
adb shell su -c '/data/local/tmp/frida-server >/dev/null 2>&1 &'
frida-ps -U
```

On an `adb root`-capable emulator, the daemon may be started directly with `adb shell`. If `su` is unavailable and the app cannot be instrumented through authorized debuggability, **report it as a blocker**; do not provide exploit steps to elevate privileges. Root is not universally necessary for Frida when using an explicitly authorized embedded Gadget or debug setup, but that is a different deployment mode.

The server process exiting instantly does not establish that the app has anti-instrumentation protections. First verify binary ABI/version, executable bit, root privileges, SELinux logs and connection. Note that 32-bit-only apps on 64-bit devices can require extra care in native symbol/ABI assumptions.

## 3. Start with the CLI

```bash
frida-ps -Uai                     # installed apps when supported
frida-ps -U                       # current processes
frida -U -n com.example.ownedapp  # attach to running process by name
frida -U -f com.example.ownedapp  # spawn for earlier instrumentation
frida -U -f com.example.ownedapp -l scripts/java_hook_repl.js
```

Use `-p <pid>` if package/process names are ambiguous (apps may spawn `:remote`/`:webview` secondary processes). Determine the correct process by current `frida-ps -U` output rather than guessing. Start by instrumenting a trivial Android lifecycle method on a toy app, then move to its own methods. Detached processes, killed apps and sessions can invalidate hooks; rerun after crashes.

## 4. Critical: Frida 17+ Java bridge in custom agents

Frida v17+ no longer bundles the Java/ObjC/Swift language bridges in raw GumJS when you load a script using the Python/Node API. The **Frida REPL** and `frida-trace` include bridges for compatibility. Therefore:

- `frida -U -f ... -l scripts/java_hook_repl.js` can use global `Java`.
- A `session.create_script(source)` custom host cannot assume global `Java` without bundling `frida-java-bridge` or using another supported compiled entrypoint.
- A precompiled TypeScript/ES module agent should contain `import Java from 'frida-java-bridge';` and be compiled to a single JS bundle for injection.

Create project-local dependencies in an owned tools workspace:

```bash
npm init -y
npm install --save-dev frida-compile
npm install frida-java-bridge
./node_modules/.bin/frida-compile scripts/java_hook_agent.ts -o agent.bundle.js
node --check agent.bundle.js
python scripts/frida_host.py --mode attach --target com.example.ownedapp --script agent.bundle.js --duration 30
```

Native-only GumJS `Interceptor` hooks do **not** require the Java bridge. Running `node --check` on a TypeScript file containing TypeScript syntax or `import` may need an appropriate JS module/compiler configuration; compile TS first and check the output.

Always read the active Frida bridge docs when switching a project's major version: https://frida.re/docs/bridges/ . The REPL may do automatic TypeScript compilation in some workflows, but custom hosts still need a correctly prepared agent.

## 5. Gadget is a separate architecture

Official options include injected (`frida-server`) and embedded (`frida-gadget`), see https://frida.re/docs/modes/ and https://frida.re/docs/gadget/ . Embed Gadget only into an app for which the user has modification authorization, observing ABI, library loading, packaging and signing. On a signed third-party APK, recomposition may break the original signing identity, self-checks and update compatibility.

Distinguish separate events: (a) `.so` located on disk, (b) loader mapped `.so`, (c) Gadget runtime initialized, (d) agent delivered a readiness event, (e) hook installed, (f) hook actually fired. A debugger or process maps can confirm (b), not (c)–(f).

## 6. Produce reproducible log

Include shell, OS, Android API, ABI, `frida`/`frida-tools` versions, package/version, attach/spawn mode, process ID at time of test (redacted before sharing), script SHA-256, and sanitized number of hook events. Record the exact working command and the first non-secret error if a test fails.
