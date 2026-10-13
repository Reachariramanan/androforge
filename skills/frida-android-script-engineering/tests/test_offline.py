"""Offline tests; explicitly not claims of Frida-on-device operation."""
import importlib.util
import json
import shutil
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GEN_SPEC = importlib.util.spec_from_file_location("generate_java_hook", ROOT / "scripts/generate_java_hook.py")
GEN = importlib.util.module_from_spec(GEN_SPEC)
assert GEN_SPEC and GEN_SPEC.loader
GEN_SPEC.loader.exec_module(GEN)
SPEC = importlib.util.spec_from_file_location("frida_host", ROOT / "scripts/frida_host.py")
HOST = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(HOST)


class OfflineSkillTests(unittest.TestCase):
    def test_safe_event_never_logs_secrets_or_raw_payload(self):
        event = HOST.safe_event({"type": "send", "payload": {
            "event": "hello", "method": "sum", "token": "secret", "body": "raw-private",
            "url": "https://restricted.example", "count": 3}}, b"TOP_SECRET")
        blob = json.dumps(event)
        self.assertIn("hello", blob)
        self.assertNotIn("secret", blob)
        self.assertNotIn("raw-private", blob)
        self.assertNotIn("restricted.example", blob)
        self.assertNotIn("TOP_SECRET", blob)
        self.assertEqual(event["binary_bytes_suppressed"], 10)

    def test_safe_event_suppresses_string_messages(self):
        event = HOST.safe_event({"type": "send", "payload": "secret"})
        self.assertEqual(event["status"], "non-dict-payload-suppressed")

    def test_dry_run_no_frida_module_needed(self):
        result = subprocess.run([sys.executable, str(ROOT / "scripts/frida_host.py"),
                                 "--dry-run", "--target", "com.example.test",
                                 "--script", str(ROOT / "scripts/native_hook.js")],
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["status"], "dry-run-ok")

    def test_generator_escapes_names_and_caps_events(self):
        source = GEN.generate('com.example.Thing', 'sum', ['int', 'int'], 2, 'repl')
        self.assertIn('com.example.Thing', source)
        self.assertIn('"maxEvents": 2', source)
        self.assertIn('original.call(this, ...callArgs)', source)
        self.assertNotIn('JSON.stringify(callArgs)', source)
        with self.assertRaises(ValueError):
            GEN.generate('com.example.Thing', 'sum', [], 0, 'repl')

    @unittest.skipUnless(shutil.which("node"), "Node.js not installed")
    def test_js_syntax(self):
        for name in ("java_hook_repl.js", "class_probe_repl.js", "native_hook.js"):
            with self.subTest(name=name):
                result = subprocess.run(["node", "--check", str(ROOT / "scripts" / name)],
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
