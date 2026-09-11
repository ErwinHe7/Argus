"""Build a small Windows installer kit plus hash-verified static asset parts.

No deployment, broker connection, installation or order submission occurs here.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import zipfile

HERE = Path(__file__).resolve().parent
PART_BYTES = 20 * 1024 * 1024  # Below Cloudflare Workers' 25 MiB per-asset limit.
BASE_NAME = 'leo-broker-tools-windows-x64'


def sha(path: Path) -> str:
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def build(archive: Path, receipt_path: Path, output: Path) -> dict:
    receipt = json.loads(receipt_path.read_text(encoding='utf-8'))
    if receipt.get('status') != 'built_and_offline_smoke_passed' or receipt.get('channel') != 'unsigned-development':
        raise ValueError('Require a successful unsigned-development native build receipt.')
    if archive.stat().st_size != receipt['archive']['bytes'] or sha(archive) != receipt['archive']['sha256']:
        raise ValueError('Native archive differs from its build receipt.')
    if not archive.name.endswith('-windows-x64.zip'):
        raise ValueError('This installer kit only supports a native Windows x64 archive.')
    if not 0 < archive.stat().st_size <= 250 * 1024 * 1024:
        raise ValueError('Native archive exceeds the installer size limit.')
    if output.exists():
        raise ValueError('Use a new output directory; old artifacts are never overwritten.')
    output.mkdir(parents=True)
    bundle_name = archive.stem
    with zipfile.ZipFile(archive) as package:
        native = json.loads(package.read(bundle_name + '/package-manifest.json'))
    if native.get('platform') != 'windows-x64' or native.get('paperOnly') is not True or native.get('signed') is not False:
        raise ValueError('Native manifest disagrees with development distribution.')
    checksum = sha(archive)
    parts = []
    with archive.open('rb') as source:
        for index in range(20):
            data = source.read(PART_BYTES)
            if not data:
                break
            name = f'leo-native-{checksum[:16]}.part{index:03}.bin'
            path = output / name
            path.write_bytes(data)
            parts.append({'name': name, 'bytes': len(data), 'sha256': sha(path)})
        if source.read(1):
            raise ValueError('Native archive exceeds supported part count.')
    manifest = {'schemaVersion': 1, 'product': 'leo-broker-tools', 'channel': 'unsigned-development', 'platform': 'windows-x64', 'paperOnly': True, 'signed': False, 'bundle': bundle_name, 'bytes': archive.stat().st_size, 'sha256': checksum, 'parts': parts}
    toolkit = output / BASE_NAME
    toolkit.mkdir()
    write_json(toolkit / 'native-package.json', manifest)
    shutil.copy2(HERE / 'install.ps1', toolkit)
    shutil.copy2(HERE / 'README.md', toolkit)
    connector = HERE.parents[1]
    shutil.copy2(connector / 'setup/broker_readiness.py', toolkit)
    # TWS inspection remains source-only; the separately licensed vendor SDK is not redistributed.
    shutil.copy2(connector / 'adapter/ibkr_sdk.py', toolkit)
    shutil.copy2(connector / 'adapter/IBKR.md', toolkit)
    zipped = output / (BASE_NAME + '.zip')
    with zipfile.ZipFile(zipped, 'x', zipfile.ZIP_DEFLATED) as target:
        for file in sorted(toolkit.iterdir()):
            target.write(file, BASE_NAME + '/' + file.name)
    release = {**manifest, 'createdAt': datetime.now(timezone.utc).isoformat(), 'installer': {'name': zipped.name, 'bytes': zipped.stat().st_size, 'sha256': sha(zipped)}, 'verification': 'offline checks only; no broker entry/hold/exit evidence', 'nativeBuildReceiptSha256': sha(receipt_path)}
    write_json(output / (BASE_NAME + '.json'), release)
    return release


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--receipt', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build(args.archive.resolve(), args.receipt.resolve(), args.output.resolve()), indent=2))
