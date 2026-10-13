#!/usr/bin/env python3
"""Small Frida host for an authorized test app. Works without Frida for --dry-run.

For Frida 17+ custom-API Java hooks, load compiled JS from a TS source that
imports frida-java-bridge. This host deliberately stores ONLY allowlisted
telemetry, not arbitrary app payloads or binary dumps.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import sys
import time
from typing import Any

TEXT_FIELDS = {"event", "method", "class_name", "symbol", "status", "stage"}
NUMBER_FIELDS = {"count", "elapsed_ms", "max_events", "duration_ms"}


def safe_event(message: dict[str, Any], data: bytes | None = None) -> dict[str, Any]:
    """Whitelist metadata fields only. No raw args, URLs, bodies or tokens."""
    event: dict[str, Any] = {
        "timestamp_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "message_type": str(message.get("type", "unknown"))[:32],
    }
    if message.get("type") == "send":
        payload = message.get("payload")
        if isinstance(payload, dict):
            for key in sorted(TEXT_FIELDS):
                value = payload.get(key)
                if isinstance(value, str):
                    event[key] = value[:160]
            for key in sorted(NUMBER_FIELDS):
                value = payload.get(key)
                if isinstance(value, (int, float)) and not isinstance(value, bool):
                    event[key] = value
        else:
            event["status"] = "non-dict-payload-suppressed"
    elif message.get("type") == "error":
        # Do not serialize arbitrary exception descriptions (potentially sensitive).
        event["status"] = "agent-error-see-local-console"
    else:
        event["status"] = "non-telemetry-suppressed"
    if data is not None:
        event["binary_bytes_suppressed"] = len(data)
    return event


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--target", required=True, help="Owned app process/package name or PID for attach")
    p.add_argument("--script", required=True, type=Path, help="Agent JS (bundle Java bridge for custom API)")
    p.add_argument("--mode", choices=("attach", "spawn"), default="attach")
    p.add_argument("--device", choices=("usb", "local"), default="usb")
    p.add_argument("--duration", type=float, default=30.0, help="Finite capture duration in seconds")
    p.add_argument("--out", type=Path, help="Optional sanitized telemetry JSONL path")
    p.add_argument("--dry-run", action="store_true", help="Validate script/path/arguments without Frida")
    return p


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    if not args.script.is_file():
        print(f"error: script does not exist: {args.script}", file=sys.stderr)
        return 2
    if args.duration < 0.1 or args.duration > 3600:
        print("error: --duration must be between 0.1 and 3600 seconds", file=sys.stderr)
        return 2
    script_source = args.script.read_text(encoding="utf-8")
    if not script_source.strip():
        print("error: empty script", file=sys.stderr)
        return 2
    if args.dry_run:
        print(json.dumps({"status": "dry-run-ok", "target": args.target,
                          "mode": args.mode, "device": args.device,
                          "agent_bytes": len(script_source.encode("utf-8")),
                          "note": "No Frida/device execution was attempted."}, indent=2))
        return 0

    try:
        import frida  # type: ignore  # intentionally optional at --dry-run
    except ImportError:
        print("error: install Python 'frida' in your venv; --dry-run works without it", file=sys.stderr)
        return 3

    stream = None
    session = None
    device = None
    pid = None
    resumed = False
    try:
        if args.out:
            args.out.parent.mkdir(parents=True, exist_ok=True)
            stream = args.out.open("w", encoding="utf-8")

        def on_message(message: dict[str, Any], data: bytes | None) -> None:
            event = safe_event(message, data)
            line = json.dumps(event, ensure_ascii=True, separators=(",", ":"))
            print(line, flush=True)
            if stream:
                stream.write(line + "\n")
                stream.flush()

        device = frida.get_usb_device(timeout=10) if args.device == "usb" else frida.get_local_device()
        if args.mode == "spawn":
            if args.target.isdecimal():
                raise ValueError("spawn requires package/identifier, not PID")
            pid = device.spawn([args.target])
            session = device.attach(pid)
        else:
            target = int(args.target) if args.target.isdecimal() else args.target
            session = device.attach(target)
        agent = session.create_script(script_source)
        agent.on("message", on_message)
        agent.load()
        if pid is not None:
            device.resume(pid)
            resumed = True
        print(json.dumps({"status": "host-loaded", "note": "Not proof that any target hook fired."}))
        deadline = time.monotonic() + args.duration
        while time.monotonic() < deadline:
            time.sleep(min(0.2, max(0.0, deadline - time.monotonic())))
        return 0
    except KeyboardInterrupt:
        return 130
    except Exception as exc:
        print(f"error: Frida host failed: {type(exc).__name__}: {str(exc)[:240]}", file=sys.stderr)
        return 4
    finally:
        if pid is not None and device is not None and not resumed:
            # Avoid silently abandoning the app in Frida's suspended spawn state.
            try:
                device.resume(pid)
            except Exception:
                pass
        if session is not None:
            try:
                session.detach()
            except Exception:
                pass
        if stream is not None:
            stream.close()


if __name__ == "__main__":
    raise SystemExit(main())
