---
name: apktool-android-apk-analysis
description: >-
  Install and troubleshoot Apktool on Windows, macOS, and Linux; triage, safely decode, and systematically understand authorized Android APKs across versions. Use when working with .apk, split APK sets, Apktool and JADX, AndroidManifest.xml, resources.arsc, smali/multidex, Java/Kotlin/JNI call graphs, native libraries, entrypoints, networking callbacks, or version-to-version reverse-engineering. Provide reproducible setup commands, SHA-256 inventory, searchable code and resource maps, cross-reference reports, explanations of Smali descriptors and register rules, and optional rebuild/sign verification for authorized test builds.
---

# Apktool Android APK Analysis

## Objective and scope

Take an **authorized** Android app artifact from opaque ZIP/Dex/XML binaries to a reproducible technical understanding of its package structure, manifest, application components, resources, Smali classes, methods, inheritance, native libraries and major data flows. Use Apktool for decode/rebuild and JADX (optional) for pseudocode. The deliverable must include actual evidence and a navigable map, not just a command list or unverified interpretation.

Do not assume Apktool outputs the original Kotlin/Java source, and never equate JADX pseudocode with source-of-truth bytecode. Treat Smali as the closer representation of Dalvik bytecode. Avoid credential extraction, removing protections, redistributing proprietary binaries, installing or modifying an APK without user authorization. Default to read-only analysis; rebuilding is an **optional separate branch**.

## Required inputs and deliverables

Identify: input path and actual container format (`.apk`, `.apks`, `.apkm`, `.xapk`, `.aab`), app/version if known, whether base/config splits are present, target OS/shell, JDK/Apktool versions, and the user's question (manifest, activity flow, methods, networking, resource IDs, native boundary, version diff). If details are missing, make an offline baseline inventory before asking for them.

Produce:

1. **Toolchain report:** executable paths, versions, OS/shell, Java environment and missing dependencies.
2. **Original inventory:** immutable file SHA-256, entry types/counts, DEX/split/ABI/signature structure, suspicious archive issues and limits.
3. **Decoded worktree:** `apktool.yml`, `AndroidManifest.xml`, `res/`, `smali*/`, `assets/`, `lib/` when present, with no edits to the original APK.
4. **Code map:** entrypoints and components, selected class hierarchy, exact method signatures, `invoke-*` call sites, resource links, native/JNI boundaries, uncertainty.
5. **Research question answer:** file paths and line anchors or exact method/class descriptors; evidence of runtime behavior only if actually observed.
6. **Optional authorized build branch:** diff, build log, signing/installation constraints, verification and rollback. Never claim a rebuilt APK equals the original signature.

## Fast-start workflow

### 0. Set up tools (do once per host)

Follow [references/setup-windows-linux-macos.md](references/setup-windows-linux-macos.md). Check JDK compatibility with the **specific Apktool release** rather than applying old version prerequisites to current releases. Prefer `apktool --version` and `java -version` in the actual terminal used for decoding. Use `scripts/tool_preflight.py` for a read-only environment report:

```bash
python scripts/tool_preflight.py --json
# If only a jar is installed:
python scripts/tool_preflight.py --apktool-jar /path/to/apktool.jar --json
```

JADX, Android SDK `adb`, `aapt2`, `apkanalyzer`, `zipalign`, `apksigner`, and optional bundletool support deeper tasks. Do not install arbitrary packages or execute a downloaded script without verifying its source.

### 1. Keep the original immutable, inventory first

```bash
mkdir -p work/original work/decoded work/reports
cp input.apk work/original/app.apk
python scripts/apk_inventory.py work/original/app.apk \
  --json work/reports/inventory.json \
  --markdown work/reports/inventory.md
```

Record SHA-256 and file size. APK is a ZIP container, but its manifest/resources are binary/compiled; raw unzip alone is not decoded source. For `.apks`, `.apkm`, `.xapk` or `.aab`, **identify the constituent APKs and correct extraction mechanism** before running `apktool d`. Do not hand a ZIP set directly to Apktool pretending it is an APK. Read [references/formats-splits-and-triage.md](references/formats-splits-and-triage.md).

### 2. Decode by Apktool, preserving a clean baseline

```bash
apktool --version
apktool d work/original/app.apk -o work/decoded/app
# Only after explicitly saving a clean original worktree:
# apktool d -f work/original/app.apk -o work/decoded/app
```

If a wrapper is unavailable but the official JAR is present, use:

```bash
java -jar /path/to/apktool.jar d work/original/app.apk -o work/decoded/app
```

**Do not use `-f` casually**: it deletes/overwrites the output directory. Decode full manifest/resources by default for understanding. If only code is needed or resources fail, use current Apktool help to choose supported selective flags, and document the limitations of the partial decode. Read [references/decoding-and-artifacts.md](references/decoding-and-artifacts.md).

### 3. Build an architecture map before code edits

Start with the manifest: package/version, `application` subclass, launcher Activity, exported components, permissions, providers, services, receivers, deep links, processes, network security config, debuggability and Android SDK levels. Distinguish **declared intent** from runtime behavior. Link referenced resource names to `res/values/*.xml`, `res/xml/*`, layouts and drawables.

Then inspect DEX partitioning (`classes.dex`, `classes2.dex`, etc.) and Smali directories (`smali/`, `smali_classes2/`, ...); map class descriptors (`Lcom/example/Foo;`) to file paths and dotted Java names. Read [references/smali-and-callgraph.md](references/smali-and-callgraph.md) for register, method prototype, invoke, inheritance and JNI interpretation.

Run searchable, bounded cross-references:

```bash
python scripts/smali_index.py work/decoded/app --class-substr 'tigon' --limit 60 \
  --markdown work/reports/smali-classes.md
python scripts/smali_index.py work/decoded/app --method-substr 'onBody' --limit 60 \
  --json work/reports/smali-methods.json
python scripts/smali_index.py work/decoded/app --invoke-substr 'Lcom/example/Foo;->bar(' \
  --limit 100 --markdown work/reports/callers.md
python scripts/smali_index.py work/decoded/app --type-ref 'Lcom/example/Foo;' \
  --limit 100 --json work/reports/type-refs.json
```

Search uses **code-aware categories**, not assumed obfuscated names; manually inspect exact line context and distinguish matches inside comments/strings from real invocations. For large apps, these passes can take minutes. Record counts, hits and truncation rather than treating no printed hits as proof of absence.

### 4. Understand a behavior, not just individual files

For a requested function (screen transition, storage, network callback, file provider, media, settings):

1. Identify its stable anchors in manifest, resources, user action, interface, native methods or known dependencies.
2. Map `entrypoint -> caller -> callee -> callback -> output`, recording Smali descriptors and source locations at every hop.
3. Use JADX to make control flow readable; confirm crucial details in Smali because decompilers may rename, fold, rearrange or omit code.
4. Determine whether the path is reachable under current feature flags and whether a callback is actually triggered **only through test observations**, not from a name alone.
5. If the new APK version differs, repeat this reasoning and compare structural features; don't copy absolute class names/offsets. See [references/version-diffs-and-networking.md](references/version-diffs-and-networking.md).
6. Summarize what is known, inferred, contradicted and not yet tested.

### 5. Optional rebuild-only branch for an owned test APK

Follow [references/rebuild-verify-and-failures.md](references/rebuild-verify-and-failures.md). A decode is **not** an editing request: only rebuild/sign when necessary and authorized. Preserve a Git diff of all edits. Build with `apktool b decoded -o unsigned.apk`, align with Android SDK `zipalign` (before `apksigner`), sign with a test keystore, verify and, if permitted, install on a dedicated device. APK signing identity changes; package update may be rejected until the original package is uninstalled, potentially deleting data. Never uninstall automatically to overcome a mismatch.

### 6. Validate and report

- Run offline tests: `python -m unittest discover -s tests -v`.
- Confirm the decode exit code, presence of `apktool.yml` and decoded manifest, DEX directories, and whether the resource table was decoded successfully.
- Distinguish static inference and actual device behavior. Map paths/lines, count unresolved candidates, and produce sanitized reproducible commands.
- Use [references/report-template.md](references/report-template.md) to create the final architecture and uncertainty report.

## Bundled resources

- `scripts/tool_preflight.py`: check PATH and tool versions without downloading/installing anything.
- `scripts/apk_inventory.py`: ZIP/APK safety flags, SHA-256, DEX/native/resource/signature counts, JSON and Markdown.
- `scripts/smali_index.py`: bounded method, class, invoke and type-use search, exact file/line provenance.
- `scripts/compare_inventories.py`: structural difference between two version inventory JSONs.
- `tests/`: synthetic APK/Smali fixtures for offline verification. Tests do not demonstrate decoding a specific third-party APK.

## Lessons from earlier authorized case

In the user's earlier Instagram/Tigon APK experiment, a class implementing a networking callback and its concrete `onBody(ByteBuffer)` proved more informative than a similarly named debug observer whose body callbacks never fired. Successful mapping relied on superclass, method descriptors, construction call sites and runtime evidence rather than lexical names. A Smali `.locals` change later collided with `p0` (`this`), illustrating why register aliases must be recalculated after edits. These are **analysis and quality-control lessons**, not evidence that the same obfuscated identifiers work on another version.

## Reference index

- [Install and verify Apktool for Windows, Linux and macOS](references/setup-windows-linux-macos.md)
- [Identify `.apk`, splits, AAB and ZIP-container risks](references/formats-splits-and-triage.md)
- [Understand decoded files, manifest and resources](references/decoding-and-artifacts.md)
- [Read Smali and navigate call graphs/JNI](references/smali-and-callgraph.md)
- [Find networking flows and port between app versions](references/version-diffs-and-networking.md)
- [Optional rebuild, signing, diagnostics and rollback](references/rebuild-verify-and-failures.md)
- [Analysis report checklist and sample](references/report-template.md)

Official sources, checked October 2026: https://apktool.org/docs/cli-parameters/ , https://apktool.org/wiki/the-basics/decoding/ , https://apktool.org/wiki/the-basics/building/ , https://developer.android.com/tools/apksigner , https://developer.android.com/tools/zipalign . Confirm options against the **installed** Apktool help for its version.
