#!/usr/bin/env python3
"""Read-only check of tools needed for an Android Frida lab (no installs)."""

from __future__ import annotations
import argparse
import json
import platform
import shutil
import subprocess
import sys

COMMANDS = {
    "python": [sys.executable, "--version"],
    "adb": ["adb", "version"],
    "frida": ["frida", "--version"],
    "frida_ps": ["frida-ps", "--version"],
    "node": ["node", "--version"],
    "npm": ["npm", "--version"],
}


def inspect(command: list[str]) -> dict[str, str | int | bool]:
    exists = shutil.which(command[0]) if command[0] != sys.executable else command[0]
    if not exists:
        return {"available": False, "status": "not-found"}
    try:
        run = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             timeout=8, check=False)
        return {"available": True, "status": "ok" if run.returncode == 0 else "error",
                "returncode": run.returncode, "version_line": (run.stdout.strip().splitlines() or [""])[0][:250]}
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"available": True, "status": type(exc).__name__}


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--json", action="store_true")
    args = p.parse_args()
    report = {"host_os": platform.platform(),
              "tools": {name: inspect(cmd) for name, cmd in COMMANDS.items()},
              "notice": "Host-only check; does not establish a working Android Frida session."}
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        for name, info in report["tools"].items():
            print(f"{name:10s} {info.get('status'):16s} {info.get('version_line', '')}")
        print(report["notice"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
