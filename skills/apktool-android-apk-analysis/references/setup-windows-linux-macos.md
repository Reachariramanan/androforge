# Install and verify Apktool on Windows, Linux and macOS

## Contents
1. Universal rules and download integrity
2. Windows (PowerShell / CMD / Git Bash)
3. Linux (Debian/Ubuntu and generic)
4. macOS (Homebrew/manual)
5. Android SDK and optional JADX
6. Diagnosis table and version pinning

## 1. Universal preparation

Apktool's JAR is a Java program with optional OS launcher wrapper. Requirements can change between Apktool **2.x and 3.x** releases: check the official release's specified JDK requirements and execute `java -version` before selecting a JDK. Avoid copying a Java 8 requirement from old 2.x guidance to all 3.x versions. Install a supported stable JDK from a trusted vendor and verify `java` is on PATH.

Use official download/release pages: https://apktool.org/ , https://github.com/iBotPeaches/Apktool/releases and the version-specific install docs. Download the versioned **JAR**, plus the OS wrapper if desired; inspect the wrapper script before execution. Hash your downloaded artifacts and record the source URL/version. Avoid Windows system-folder installation and prefer a per-user tools directory. No command in this skill silently downloads or executes third-party code.

Minimal verification:

```bash
java -version
java -jar /path/to/apktool.jar --version
# If a wrapper is installed:
apktool --version
apktool --help
```

## 2. Windows PowerShell

1. Install a supported JDK, reopen PowerShell and run `java -version` and `where.exe java`.
2. Create a user-owned directory such as `$env:USERPROFILE\tools\apktool`.
3. Download `apktool_<version>.jar` from the official release, rename/copy to `apktool.jar` in that directory, and save the official Windows `apktool.bat` wrapper there. **Do not overwrite unknown existing launchers.**
4. For the **current shell only**:

```powershell
$toolDir = Join-Path $env:USERPROFILE 'tools\apktool'
$env:PATH = "$toolDir;$env:PATH"
apktool --version
Get-Command apktool
java -jar (Join-Path $toolDir 'apktool.jar') --version
```

5. To persist for **new terminals**, edit user PATH via Windows Environment Variables UI or carefully update `[Environment]::SetEnvironmentVariable('Path', ..., 'User')` without losing existing entries; reopen terminal. A persistent PATH change does **not** refresh the current PowerShell/Git Bash process.

On CMD use `where apktool` and `apktool --version`. On Git Bash, `export PATH="/c/Users/<you>/tools/apktool:$PATH"` applies only to that Bash session. Paths with spaces must be quoted. If the wrapper is unavailable, `java -jar C:\Users\...\apktool.jar` works as a fallback.

## 3. Linux

Install a JDK via your distro's package manager. For a wrapper-based installation, put the official `apktool.jar` and trusted `apktool` shell wrapper together in `$HOME/.local/bin` (or `/usr/local/bin` with explicit admin permissions); mark **only the wrapper** executable if the wrapper uses `java -jar`, and verify its expected JAR location. Example user-local flow:

```bash
mkdir -p "$HOME/.local/bin"
# Copy official, verified apktool.jar and apktool wrapper here.
chmod +x "$HOME/.local/bin/apktool"
export PATH="$HOME/.local/bin:$PATH"
which apktool
apktool --version
```

A package-manager `apktool` may lag newer releases; compare `apktool --version` with the JAR/source used in your project. If Java is installed but `apktool` isn't found, run `java -jar /absolute/path/apktool.jar` explicitly. Do not assume `sudo`/root is required to decode files in a user folder.

## 4. macOS

With Homebrew installed and trusted:

```bash
brew install apktool
which apktool
apktool --version
java -version
```

Or use the official macOS shell wrapper and JAR from the release page in a user-owned PATH directory. For shells like zsh update the relevant shell config and start a new terminal. Homebrew's Java visibility and the shell's `JAVA_HOME` can differ; use `/usr/libexec/java_home -V` when diagnosing JDK selection.

## 5. Android SDK and optional companion tools

For device work install Android SDK **Platform Tools** (`adb`) and **Build Tools** (`aapt2`, `zipalign`, `apksigner`) from Android's official SDK manager. `apkanalyzer` may be available through SDK command-line tools, and `bundletool` is relevant to `.aab`/`.apks` workflows. `jadx` improves human-readable call graph navigation but decompiled Java is advisory relative to Smali.

After installation:

```bash
adb version
adb devices -l
# Use full paths or add your SDK directories to PATH:
aapt2 version
apksigner --version
zipalign -h
jadx --version
```

The report should give missing-tool guidance, not claim that every optional tool is necessary for basic decode.

## 6. Quick diagnosis

| Failure | What to verify |
|---|---|
| `'java' is not recognized` / `command not found` | Install a JDK compatible with the selected Apktool, reload PATH, verify Java executable |
| `UnsupportedClassVersionError` | JAR compiled for newer Java; use compatible JDK, don't patch the JAR |
| `apktool not found` | Wrapper missing/incorrect PATH; run `java -jar ... --version` |
| `Unable to access jarfile` | Correct file name/path; wrapper relative path; read permission |
| Running unexpected Apktool version | `where.exe apktool` / `which -a apktool`, inspect wrapper, remove shadowed copies |
| Git Bash and PowerShell show different tools | They have different processes/path mappings; print `PATH` inside the active shell |
| AAPT/resource errors | Decode resources with correct framework dependencies/tool release, try code-only as explicitly partial fallback |
| Proxy/TLS download failures | Manual verified download from official releases; avoid disabling TLS validation |

**Pin versions per project** with OS, shell, Java vendor/version, Apktool release and SHA-256, SDK build tools and JADX version. Keep source APK untouched while testing tool upgrades.
