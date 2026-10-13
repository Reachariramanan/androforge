"""Offline synthetic fixtures validate tools without interacting with real apps."""

import importlib.util
import json
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    path = ROOT / "scripts" / f"{name}.py"
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


inventory = load("apk_inventory")
smali = load("smali_index")
compare = load("compare_inventories")


class OfflineApkTests(unittest.TestCase):
    def test_inventory_reports_dex_and_native(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "app.apk"
            with zipfile.ZipFile(path, "w") as z:
                z.writestr("AndroidManifest.xml", b"\x03\x00\x08\x00")
                z.writestr("classes.dex", b"dex\n039\x00")
                z.writestr("classes2.dex", b"dex\n039\x00")
                z.writestr("lib/arm64-v8a/libtest.so", b"SO")
                z.writestr("res/layout/main.xml", b"compiled")
                z.writestr("assets/test.txt", b"sample")
            report = inventory.analyze(path)
            self.assertTrue(report["android_manifest_at_root"])
            self.assertEqual(report["dex_files"], ["classes.dex", "classes2.dex"])
            self.assertEqual(report["abi_names"], ["arm64-v8a"])
            self.assertEqual(report["category_counts"]["asset_files"], 1)
            self.assertEqual(len(report["sha256"]), 64)
            self.assertIn("ZIP signature", " ".join(report["notes"]))

    def test_detects_unsafe_member_without_extracting(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "unsafe.apk"
            with zipfile.ZipFile(path, "w") as z:
                z.writestr("../oops.txt", "x")
            warnings = inventory.analyze(path)["warnings"]
            self.assertTrue(any("Unsafe ZIP path" in x for x in warnings))
            self.assertFalse((Path(temp).parent / "oops.txt").exists())

    def test_smali_callsite_and_line(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            p = root / "smali_classes2" / "com" / "example" / "Foo.smali"
            p.parent.mkdir(parents=True)
            p.write_text(""".class public Lcom/example/Foo;
.super Ljava/lang/Object;
.method public onBody(Ljava/nio/ByteBuffer;)V
  .locals 2
  invoke-static {p1}, Lcom/example/Logger;->record(Ljava/nio/ByteBuffer;)V
  return-void
.end method
""", encoding="utf-8")
            a = smali.scan(root, method_substr="onBody", limit=5)
            b = smali.scan(root, invoke_substr="Lcom/example/Logger;->record(", limit=5)
            self.assertEqual(a["totals"]["declared_methods"], 1)
            self.assertEqual(a["hits"][0]["line"], 3)
            self.assertEqual(b["hits"][0]["line"], 5)
            self.assertIn("Foo.smali", b["hits"][0]["file"])

    def test_truncation_count_remains_correct(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "smali" / "Foo.smali"
            path.parent.mkdir()
            path.write_text(".class public LFoo;\n" + ".method public method()V\n.end method\n" * 4)
            result = smali.scan(Path(temp), method_substr="method", limit=2)
            self.assertEqual(result["totals"]["matches"], 4)
            self.assertTrue(result["truncated"])
            self.assertEqual(len(result["hits"]), 2)

    def test_version_layout_diff(self):
        old = {"schema_version": 1, "sha256": "a", "dex_files": ["classes.dex"],
               "abi_names": ["arm64-v8a"], "category_counts": {"asset_files": 1}}
        new = {"schema_version": 1, "sha256": "b", "dex_files": ["classes.dex", "classes2.dex"],
               "abi_names": ["arm64-v8a"], "category_counts": {"asset_files": 3}}
        change = compare.compare(old, new)
        self.assertTrue(change["hash_changed"])
        self.assertEqual(change["list_changes"]["dex_files"]["added"], ["classes2.dex"])
        self.assertEqual(change["scalar_changes"]["category_counts.asset_files"]["new"], 3)


if __name__ == "__main__":
    unittest.main()
