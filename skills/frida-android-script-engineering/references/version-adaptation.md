# Version-adaptive Frida discovery for obfuscated APKs

## Contents
1. Why old hooks fail
2. Porting procedure
3. Multiple architectures/versions
4. Historical Frida Gadget experiment
5. Version-specific manifest

## 1. Do not hardcode historical obfuscated names

In a large Android app, an obfuscated class like `LX/02gB;` may be renamed or even removed between builds. String search alone can yield incorrect classes. Preserve the **behavioral hypothesis** (e.g., a callback receiving `java.nio.ByteBuffer`, a known interface implementation, or an invocation from a network client) and rediscover the concrete class each version.

## 2. Provenance-driven porting process

1. **Snapshot both APKs**: SHA-256, package, versionName/versionCode, DEX count and split topology.
2. **Static discovery**: locate descriptor/inheritance/interface, method prototypes, constructor callsites, callers, invoked native methods and stable resources. Use Apktool/JADX separately; annotate all candidates.
3. **Build a crosswalk**: `old class -> old role -> new interface/method/caller -> new candidate`; confidence low/medium/high with evidence.
4. **Check runtime reality**: target process correct, class loaded in its loader, exact overload enumerated, controlled feature triggers it. Record negative results.
5. **Write the hook from the verified descriptor** rather than copy a hardcoded `Java.use('LX.02gB')` from a different version.
6. **Test read-only metadata** before any deeper logic. Measure app throughput and crashes against baseline.
7. **Do not confuse discovery of a possible stream API with proof of full request/response interception.** A callback may supply chunks, partial headers or no body; verify data semantics rather than assuming it.

Suggested manifest in the project:

```json
{
  "package": "com.example.ownedapp",
  "apk_sha256": "REPLACE_ME",
  "version": "REPLACE_ME",
  "target_role": "read-only response callback metadata",
  "java_class": "com.example.obfuscated.Candidate",
  "method": "onBody(java.nio.ByteBuffer):void",
  "loader_evidence": "Found with Java.use in test process",
  "hook_events": 0,
  "tested_on_device": false,
  "privacy_mode": "metadata-only"
}
```

## 3. Architectural changes between builds

If networking moved from Java to JNI/C++, start a **new** native discovery branch. If a package moved to split APKs or dynamic features, update the installation and loader map first. If the target method no longer exists, report that the current hook cannot be ported directly; do not manufacture a class name. Distinguish one callback per request versus pooled/reused callback objects before claiming request correlation.

## 4. Reusable lesson from earlier work

The historical user session included a Frida Gadget setup on an Instagram test APK with a loader runnable and JavaScript logger. The `.so` appeared mapped, yet runtime script execution was not observed. That code path was reverted. Later positive network evidence came from direct Smali callback instrumentation. Therefore a Frida skills package may use that history to teach **failure analysis**, but not to advertise a verified Frida capture solution. Also don't ascribe the failure to anti-Frida measures without technical confirmation.

## 5. Porting acceptance

A new APK is successfully ported only when both the agent and the relevant app workflow are tested: ready, candidate resolved, event observed at controlled action, return/exception preservation, app functionality stable, bounded logs and explicit gaps. Capture the specific version, build, matching ABI and exact Frida/toolchain versions in the report.
