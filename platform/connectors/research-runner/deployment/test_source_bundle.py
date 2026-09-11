from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import build_source_bundle as bundle
from verify_source_bundle import verify


class BundleTests(unittest.TestCase):
    def test_allowlist_excludes_data_secrets_and_executables_and_verifies_hashes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            (source / "safe.py").write_text("value = 1\n", encoding="utf-8")
            for name in (".env", "market-data.json", "strategy-lab.exe", "account.db"):
                (source / name).write_text("must not ship", encoding="utf-8")
            with patch.object(bundle, "EXACT", ("safe.py",)), patch.object(bundle, "TREES", ()):
                receipt = bundle.build(source, root / "source.zip")
            self.assertEqual(receipt["files"], 1)
            with zipfile.ZipFile(root / "source.zip") as archive:
                self.assertEqual(set(archive.namelist()), {"platform/safe.py", "platform/SOURCE-MANIFEST.json"})
                archive.extractall(root / "extracted")
            extracted = root / "extracted/platform"
            self.assertEqual(verify(extracted), 1)
            (extracted / "safe.py").write_text("value = 2\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "hash differs"):
                verify(extracted)

    def test_existing_output_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "source.zip"
            output.write_bytes(b"existing")
            with self.assertRaisesRegex(ValueError, "overwrite"):
                bundle.build(Path(temporary), output)
            self.assertEqual(output.read_bytes(), b"existing")

    def test_verifier_rejects_parent_traversal(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "SOURCE-MANIFEST.json").write_text(json.dumps({
                "schemaVersion": "leo-vps-source-bundle.v1",
                "files": [{"path": "../private", "bytes": 1, "sha256": "irrelevant"}],
            }), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Unsafe"):
                verify(root)


if __name__ == "__main__":
    unittest.main()
