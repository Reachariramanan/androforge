#!/usr/bin/env python3
"""Read-only Android analysis toolchain preflight: no installations or downloads."""

from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess

BASE_COMMANDS = {
    "java": ["java", "-version"],
    "apktool": ["apktool", "--version"],
    "adb": ["adb", "version"],
    "jadx": ["jadx", "--version"],
    "aapt2": ["aapt2", "version"],
    "apksigner": ["apksigner", "--version"],
    "zipalign": ["zipalign", "-h"],
}


def probe(command: list[str]) -> dict:
    if not shutil.which(command[0]):
        return {"available": False, "status": "not-on-path"}
    try:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, errors="replace", timeout=8, check=False)
        line = next((s for s in result.stdout.splitlines() if s.strip()), "")
        return {"available": True, "status": "ok" if result.returncode == 0 else "nonzero",
                "returncode": result.returncode, "first_line": line[:220],
                "binary": shutil.which(command[0])}
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"available": True, "status": type(exc).__name__}


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--apktool-jar", type=Path, help="Use java -jar path for independent Apktool version check")
    p.add_argument("--json", action="store_true")
    args = p.parse_args()
    report = {"platform": platform.platform(),
              "java_home": os.environ.get("JAVA_HOME", "(not set)"),
              "android_home": os.environ.get("ANDROID_HOME", "(not set)"),
              "android_sdk_root": os.environ.get("ANDROID_SDK_ROOT", "(not set)"),
              "tools": {key: probe(cmd) for key, cmd in BASE_COMMANDS.items()},
              "note": "Host-only tool check, not an APK decode, rebuild or device test."}
    if args.apktool_jar:
        if not args.apktool_jar.is_file():
            report["apktool_jar"] = {"available": False, "status": "missing-file"}
        else:
            report["apktool_jar"] = probe(["java", "-jar", str(args.apktool_jar), "--version"])
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print(f"Platform: {report['platform']}")
        for name, data in report["tools"].items():
            print(f"{name:12s} {data['status']:15s} {data.get('first_line', '')}")
        if "apktool_jar" in report:
            print("apktool jar:", report["apktool_jar"])
        print(report["note"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
