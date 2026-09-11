"""Offline installer security checks using small synthetic ZIPs; no broker calls."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile

import build_broker_tools as builder


@unittest.skipUnless(os.name == 'nt', 'PowerShell Windows installer')
class ToolkitTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='leo-kit-test-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.bundle = 'leo-strategy-connector-0.1.0-dev-windows-x64'
        self.marker = self.root / 'installer-ran'

    def fixture(self, extras=None):
        archive = self.root / (self.bundle + '.zip')
        with zipfile.ZipFile(archive, 'w') as target:
            target.writestr(self.bundle + '/package-manifest.json', json.dumps({'platform': 'windows-x64', 'paperOnly': True, 'signed': False}))
            target.writestr(self.bundle + '/scripts/install.ps1', "param([string]$InstallDir)\nSet-Content -LiteralPath (Join-Path $InstallDir 'installer-ran') -Value 'fixture'\n")
            for name, data in extras or []:
                target.writestr(name, data)
        receipt = self.root / 'receipt.json'
        receipt.write_text(json.dumps({'status': 'built_and_offline_smoke_passed', 'channel': 'unsigned-development', 'archive': {'sha256': builder.sha(archive), 'bytes': archive.stat().st_size}}))
        output = self.root / 'output'
        result = builder.build(archive, receipt, output)
        return archive, receipt, output, result

    def execute(self, output, *args):
        shell = os.environ.get('LEO_TEST_POWERSHELL') or shutil.which('pwsh') or 'powershell.exe'
        return subprocess.run([shell, '-NoProfile', '-NonInteractive', '-File', str(output / builder.BASE_NAME / 'install.ps1'), '-PartsDirectory', str(output), '-InstallDir', str(self.root), *args], capture_output=True, text=True, encoding='utf-8', errors='replace')

    def test_valid_archive_can_verify_without_executing(self):
        _, _, output, result = self.fixture()
        completed = self.execute(output, '-VerifyOnly')
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertFalse(self.marker.exists())
        self.assertEqual(sum(p['bytes'] for p in result['parts']), result['bytes'])
        self.assertEqual(builder.sha(output / result['installer']['name']), result['installer']['sha256'])

    def test_valid_archive_executes_only_after_verification(self):
        _, _, output, _ = self.fixture()
        completed = self.execute(output)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertTrue(self.marker.is_file())

    def test_tampered_part_does_not_run_installer(self):
        _, _, output, result = self.fixture()
        path = output / result['parts'][0]['name']
        data = bytearray(path.read_bytes())
        data[-1] ^= 1
        path.write_bytes(data)
        completed = self.execute(output)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn('checksum mismatch', completed.stderr)
        self.assertFalse(self.marker.exists())

    def test_receipt_mismatch_rejected_before_output(self):
        archive, receipt, _, _ = self.fixture()
        archive.write_bytes(archive.read_bytes() + b'tamper')
        with self.assertRaisesRegex(ValueError, 'differs'):
            builder.build(archive, receipt, self.root / 'bad-output')
        self.assertFalse((self.root / 'bad-output').exists())

    def test_path_traversal_rejected(self):
        _, _, output, _ = self.fixture([(self.bundle + '/../outside.ps1', b'bad')])
        completed = self.execute(output)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn('Unsafe or duplicate archive path', completed.stderr)
        self.assertFalse(self.marker.exists())

    def test_duplicate_windows_path_rejected(self):
        _, _, output, _ = self.fixture([(self.bundle + '/scripts/INSTALL.ps1', b'bad')])
        completed = self.execute(output)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn('Unsafe or duplicate archive path', completed.stderr)
        self.assertFalse(self.marker.exists())


if __name__ == '__main__':
    unittest.main()
