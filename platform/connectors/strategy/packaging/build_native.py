"""Build one host-native, unsigned development package. Never publish or run orders."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tarfile
import tomllib
import uuid
import xml.etree.ElementTree as ET
import zipfile

HERE = Path(__file__).resolve().parent
CONNECTOR = HERE.parent
REPO = HERE.parents[3]
ENGINE = REPO / 'platform/quant_engine_rs'


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def run(command, receipt, *, cwd=REPO, input_text=None):
    completed = subprocess.run([str(c) for c in command], cwd=cwd, text=True, input=input_text, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    record = {'command': [str(c) for c in command], 'exitCode': completed.returncode, 'output': completed.stdout}
    if input_text is not None:
        record['syntheticOfflineInput'] = input_text
    receipt['commands'].append(record)
    print(completed.stdout[-2500:], flush=True)
    if completed.returncode:
        raise RuntimeError(f'Command failed with exit code {completed.returncode}: {command[0]}')
    return completed.stdout


def collect_notices(bundle, receipt):
    notices = bundle / 'licenses'
    notices.mkdir()
    python_license = next((p for p in [Path(sys.base_prefix) / 'LICENSE.txt', Path(sys.base_prefix) / 'LICENSE', Path(sys.base_prefix) / 'lib/python3.12/LICENSE.txt'] if p.is_file()), None)
    if python_license:
        shutil.copy2(python_license, notices / 'CPython-LICENSE.txt')
    else:
        # Python.org license is version-specific; preserve its source URL in the receipt.
        import urllib.request
        url = f'https://raw.githubusercontent.com/python/cpython/v{platform.python_version()}/LICENSE'
        with urllib.request.urlopen(url, timeout=30) as response:
            (notices / 'CPython-LICENSE.txt').write_bytes(response.read())
        receipt['pythonLicenseSource'] = url
    distributions = []
    for dist in sorted(importlib.metadata.distributions(), key=lambda d: d.metadata['Name'].lower()):
        entry = {'name': dist.metadata['Name'], 'version': dist.version, 'license': dist.metadata.get('License-Expression') or dist.metadata.get('License'), 'homePage': dist.metadata.get('Home-page'), 'noticeFiles': []}
        for file in dist.files or []:
            if not any(part.lower().startswith(('license', 'copying', 'notice', 'authors')) for part in file.parts):
                continue
            source = Path(dist.locate_file(file))
            if source.is_file():
                relative = Path('python') / f"{entry['name']}-{entry['version']}" / Path(*file.parts)
                if '..' in relative.parts:
                    continue
                target = notices / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
                entry['noticeFiles'].append(relative.as_posix())
        distributions.append(entry)
    write_json(bundle / 'python-dependencies.json', distributions)
    registry = Path(os.environ.get('CARGO_HOME', str(Path.home() / '.cargo'))) / 'registry/src'
    crates, missing = [], []
    packages = {}
    for lock in [CONNECTOR / 'Cargo.lock', ENGINE / 'Cargo.lock']:
        shutil.copy2(lock, bundle / ('connector-Cargo.lock' if lock.parent == CONNECTOR else 'engine-Cargo.lock'))
        for package in tomllib.loads(lock.read_text())['package']:
            if package.get('source', '').startswith('registry+'):
                packages[(package['name'], package['version'])] = package
    for (name, version), package in sorted(packages.items()):
        sources = list(registry.glob(f'*/{name}-{version}'))
        found = []
        license_expression = None
        if sources:
            source = sources[0]
            metadata = tomllib.loads((source / 'Cargo.toml').read_text())
            license_expression = metadata['package'].get('license')
            for path in source.iterdir():
                if path.is_file() and path.name.lower().startswith(('license', 'copying', 'notice', 'authors')):
                    target = notices / 'rust' / f'{name}-{version}' / path.name
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, target)
                    found.append(target.relative_to(notices).as_posix())
        if not found:
            missing.append(f'{name}-{version}')
        crates.append({'name': name, 'version': version, 'registryChecksum': package.get('checksum'), 'license': license_expression, 'noticeFiles': found})
    write_json(bundle / 'rust-dependencies.json', crates)
    receipt['licenseReview'] = {'status': 'development_inventory_not_public_release_clearance', 'rustLockEntriesWithoutLocalNotice': missing, 'pythonDependencyCount': len(distributions), 'rustLockEntryCount': len(crates)}


def make_msi(bundle, output, wix, receipt):
    ns = 'http://schemas.microsoft.com/wix/2006/wi'
    ET.register_namespace('', ns)
    def element(parent, tag, **attrs):
        return ET.SubElement(parent, '{' + ns + '}' + tag, attrs)
    root = ET.Element('{' + ns + '}Wix')
    product_code = str(uuid.uuid4()).upper()
    product = element(root, 'Product', Id=product_code, Name='Leo Strategy Connector (Unsigned Development)', Language='1033', Version='0.1.0', Manufacturer='Leo', UpgradeCode='2246E16A-A38D-49C7-BA90-547C242EC83B')
    element(product, 'Package', InstallerVersion='500', Compressed='yes', InstallScope='perUser', Platform='x64', Description='SIMULATE-only unsigned development connector')
    element(product, 'MediaTemplate', EmbedCab='yes', CompressionLevel='high')
    element(product, 'MajorUpgrade', DowngradeErrorMessage='A newer Leo development package is already installed.', AllowSameVersionUpgrades='yes', Schedule='afterInstallInitialize')
    element(product, 'Property', Id='ARPNOMODIFY', Value='1')
    install_property = element(product, 'Property', Id='INSTALLFOLDER', Secure='yes')
    element(install_property, 'RegistrySearch', Id='LocateInstalledLeoDirectory', Root='HKCU', Key='Software\\Leo\\StrategyConnectorDev', Name='InstallDirectory', Type='raw', Win64='yes')
    condition = element(product, 'Condition', Message='This development package requires Windows x64 and per-user installation. Windows 11 x64 is the supported validation target.')
    condition.text = 'VersionNT64 AND NOT ALLUSERS'
    directory = element(product, 'Directory', Id='TARGETDIR', Name='SourceDir')
    local = element(directory, 'Directory', Id='LocalAppDataFolder')
    programs = element(local, 'Directory', Id='ProgramsFolder', Name='Programs')
    install = element(programs, 'Directory', Id='INSTALLFOLDER', Name='LeoStrategyConnectorMsiDev')
    directories = {'': install}
    removal_directories = set()
    feature = element(product, 'Feature', Id='MainFeature', Title='Leo Strategy Connector Development', Level='1')
    installation_component = element(install, 'Component', Id='PersistInstallationDirectory', Guid='6A6074F0-14A7-4F38-8DDA-0E86E945E4CB', Win64='yes')
    element(installation_component, 'RegistryValue', Root='HKCU', Key='Software\\Leo\\StrategyConnectorDev', Name='InstallDirectory', Type='string', Value='[INSTALLFOLDER]', KeyPath='yes')
    element(feature, 'ComponentRef', Id='PersistInstallationDirectory')
    for file in sorted(p for p in bundle.rglob('*') if p.is_file()):
        relative = file.relative_to(bundle)
        cursor = Path()
        parent = install
        for part in relative.parts[:-1]:
            cursor /= part
            key = cursor.as_posix()
            if key not in directories:
                directories[key] = element(parent, 'Directory', Id='d' + hashlib.sha256(key.encode()).hexdigest()[:24], Name=part)
            parent = directories[key]
        identity = hashlib.sha256(relative.as_posix().encode()).hexdigest()[:24]
        component = element(parent, 'Component', Id='c' + identity, Guid=str(uuid.uuid5(uuid.NAMESPACE_URL, 'leo-dev-0.1.0/' + relative.as_posix())).upper(), Win64='yes')
        # HKCU key paths keep this a per-user package; state lives outside INSTALLFOLDER.
        element(component, 'RegistryValue', Root='HKCU', Key='Software\\Leo\\StrategyConnectorDev\\Files', Name=identity, Type='integer', Value='1', KeyPath='yes')
        element(component, 'File', Id='f' + identity, Source=str(file), Name=file.name)
        if parent.attrib['Id'] not in removal_directories:
            element(component, 'RemoveFolder', Id='r' + identity, Directory=parent.attrib['Id'], On='uninstall')
            removal_directories.add(parent.attrib['Id'])
        element(feature, 'ComponentRef', Id='c' + identity)
    # Intermediate directories can contain only subdirectories, so they do not
    # inherit the file-component cleanup above. ICE64 requires those paths too.
    for directory_node in directories.values():
        directory_id = directory_node.attrib['Id']
        if directory_id in removal_directories:
            continue
        identity = hashlib.sha256(directory_id.encode()).hexdigest()[:24]
        cleanup = element(directory_node, 'Component', Id='cleanup' + identity, Guid=str(uuid.uuid5(uuid.NAMESPACE_URL, 'leo-dev-directory/' + directory_id)).upper(), Win64='yes')
        element(cleanup, 'RegistryValue', Root='HKCU', Key='Software\\Leo\\StrategyConnectorDev\\Directories', Name=identity, Type='integer', Value='1', KeyPath='yes')
        element(cleanup, 'RemoveFolder', Id='remove' + identity, On='uninstall')
        element(feature, 'ComponentRef', Id='cleanup' + identity)
    # Programs is a shared parent: only remove this directory if it is empty.
    parent_component = element(programs, 'Component', Id='ProgramsCleanup', Guid='F398B9AC-C197-4F0F-9D96-4841E9E600C8', Win64='yes')
    element(parent_component, 'RegistryValue', Root='HKCU', Key='Software\\Leo\\StrategyConnectorDev', Name='ProgramsCleanup', Type='integer', Value='1', KeyPath='yes')
    element(parent_component, 'RemoveFolder', Id='ProgramsCleanupFolder', On='uninstall')
    element(feature, 'ComponentRef', Id='ProgramsCleanup')
    source = output / 'leo-strategy-connector.wxs'
    ET.indent(root)
    ET.ElementTree(root).write(source, encoding='utf-8', xml_declaration=True)
    obj = output / 'leo-strategy-connector.wixobj'
    msi = output / (bundle.name + '.msi')
    run([wix / 'candle.exe', '-nologo', '-arch', 'x64', '-out', obj, source], receipt)
    # ICE38/64 stay enabled. ICE91 warns about per-machine behavior; the launch
    # condition explicitly prohibits that installation scope for this package.
    run([wix / 'light.exe', '-nologo', '-sice:ICE91', '-out', msi, obj], receipt)
    receipt['msi'] = {'path': str(msi), 'productCode': product_code, 'status': 'built_unsigned_not_installed', 'sha256': digest(msi)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--skip-build', action='store_true')
    parser.add_argument('--sidecar', type=Path)
    parser.add_argument('--profile', choices=['release', 'debug'], default='release')
    parser.add_argument('--wix-dir', type=Path)
    args = parser.parse_args()
    machine = platform.machine().lower()
    arch = {'amd64': 'x64', 'x86_64': 'x64', 'arm64': 'arm64', 'aarch64': 'arm64'}.get(machine)
    os_name = {'Windows': 'windows', 'Darwin': 'macos', 'Linux': 'linux'}.get(platform.system())
    if (os_name, arch) not in [('windows', 'x64'), ('macos', 'x64'), ('macos', 'arm64'), ('linux', 'x64')]:
        raise RuntimeError('Unsupported build host; cross-compilation is not a native validation')
    if os_name == 'macos':
        if int(platform.mac_ver()[0].split('.')[0]) < 14:
            raise RuntimeError('The native macOS target requires macOS 14 or newer')
        os.environ.setdefault('MACOSX_DEPLOYMENT_TARGET', '14.0')
    if os_name == 'linux':
        distribution = platform.freedesktop_os_release()
        if distribution.get('ID') != 'ubuntu' or distribution.get('VERSION_ID') not in ('22.04', '24.04'):
            raise RuntimeError('Build separately on Ubuntu 22.04 or 24.04; glibc compatibility is not inferred')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    bundle = output / f'leo-strategy-connector-0.1.0-dev-{os_name}-{arch}'
    if bundle.exists():
        raise RuntimeError('Output bundle already exists; use a new output directory')
    receipt = {'schemaVersion': 1, 'product': 'leo-strategy-connector', 'channel': 'unsigned-development', 'startedAt': datetime.now(timezone.utc).isoformat(), 'host': platform.platform(), 'architecture': machine, 'python': {'version': platform.python_version(), 'executable': sys.executable, 'basePrefix': sys.base_prefix}, 'commands': [], 'notRun': ['OpenD installation/authentication', 'broker connection/entitlement', 'actual paper order lifecycle', 'cross-platform installation', 'Windows production signing', 'macOS Developer ID signing/notarization', 'Apple Silicon vendor OpenD/Rosetta verification', 'control service pairing', 'credential store integration']}
    receipt_file = output / 'native-build-receipt.json'
    try:
        input_files = set()
        for directory in [CONNECTOR / 'src', CONNECTOR / 'adapter', HERE, ENGINE / 'src/strategy_lab']:
            input_files.update(p for p in directory.rglob('*') if p.is_file() and p.suffix in ['.rs', '.py', '.ps1', '.sh', '.md', '.txt'])
        input_files.update([CONNECTOR / 'Cargo.toml', CONNECTOR / 'Cargo.lock', CONNECTOR / 'README.md', ENGINE / 'Cargo.toml', ENGINE / 'Cargo.lock', ENGINE / 'src/bin/strategy-lab.rs'])
        receipt['sourceHashes'] = {p.relative_to(REPO).as_posix(): digest(p) for p in sorted(input_files)}
        run(['rustc', '--version'], receipt)
        if not args.skip_build:
            for crate, binary in [(CONNECTOR, 'leo-strategy-connector'), (ENGINE, 'strategy-lab')]:
                command = ['cargo', 'build', '--locked', '--manifest-path', crate / 'Cargo.toml', '--bin', binary]
                if args.profile == 'release':
                    command.append('--release')
                run(command, receipt)
        sidecar = args.sidecar
        if sidecar is None:
            run([sys.executable, '-m', 'pip', 'install', '-r', CONNECTOR / 'adapter/requirements.txt', 'pyinstaller==6.16.0'], receipt)
            sidecar_dist = output / 'sidecar-build'
            run([sys.executable, '-m', 'PyInstaller', '--noconfirm', '--clean', '--noupx', '--onedir', '--name', 'leo-paper-sdk', '--collect-all', 'moomoo', '--collect-all', 'exchange_calendars', '--collect-all', 'tzdata', '--copy-metadata', 'moomoo-api', '--copy-metadata', 'exchange-calendars', '--distpath', sidecar_dist, '--workpath', output / 'pyinstaller-work', '--specpath', output, CONNECTOR / 'adapter/broker_sdk.py'], receipt)
            sidecar = sidecar_dist / 'leo-paper-sdk'
        extension = '.exe' if os_name == 'windows' else ''
        (bundle / 'bin').mkdir(parents=True)
        for crate, binary in [(CONNECTOR, 'leo-strategy-connector'), (ENGINE, 'strategy-lab')]:
            target = Path(os.environ['CARGO_TARGET_DIR']).resolve() if os.environ.get('CARGO_TARGET_DIR') else crate / 'target'
            shutil.copy2(target / args.profile / (binary + extension), bundle / 'bin' / (binary + extension))
        shutil.copytree(sidecar.resolve(), bundle / 'adapter/leo-paper-sdk')
        shutil.copytree(HERE / ('windows' if os_name == 'windows' else 'unix'), bundle / 'scripts')
        shutil.copy2(CONNECTOR / 'adapter/requirements.txt', bundle / 'adapter-requirements.txt')
        shutil.copy2(CONNECTOR / 'README.md', bundle / 'README.md')
        shutil.copy2(CONNECTOR / 'adapter/IBKR.md', bundle / 'IBKR.md')
        shutil.copy2(HERE / 'THIRD-PARTY-NOTICES.md', bundle / 'THIRD-PARTY-NOTICES.md')
        if os_name != 'windows':
            for script in (bundle / 'scripts').glob('*.sh'):
                script.chmod(0o755)
        collect_notices(bundle, receipt)
        write_json(bundle / 'package-manifest.json', {'product': 'leo-strategy-connector', 'version': '0.1.0', 'channel': 'unsigned-development', 'platform': os_name + '-' + arch, 'profile': args.profile, 'paperOnly': True, 'separateEngine': True, 'bundledPythonSidecar': True, 'openDBundled': False, 'signed': False, 'notarized': False, 'stateRemovedOnUninstall': False})
        run([bundle / 'bin' / ('leo-strategy-connector' + extension), 'doctor'], receipt)
        engine_result = run([bundle / 'bin' / ('strategy-lab' + extension)], receipt, input_text='{"operation":"stop","strategy":"MR-v1","first_fill_price":"100","signal_atr":"2"}')
        if json.loads(engine_result).get('initial_stop') != '96.000000':
            raise RuntimeError('Separate engine synthetic arithmetic smoke failed')
        run([bundle / 'adapter/leo-paper-sdk' / ('leo-paper-sdk' + extension), '--self-check'], receipt)
        run([bundle / 'adapter/leo-paper-sdk' / ('leo-paper-sdk' + extension), '--broker', 'ibkr-gateway', '--self-check'], receipt)
        checksum_lines = [f'{digest(p)}  {p.relative_to(bundle).as_posix()}\n' for p in sorted(bundle.rglob('*')) if p.is_file()]
        (bundle / 'SHA256SUMS').write_text(''.join(checksum_lines), encoding='utf-8')
        receipt['bundle'] = {'path': str(bundle), 'fileCount': len(checksum_lines) + 1, 'bytes': sum(p.stat().st_size for p in bundle.rglob('*') if p.is_file()), 'checksumManifestSha256': digest(bundle / 'SHA256SUMS')}
        if os_name == 'windows':
            archive = output / (bundle.name + '.zip')
            # Registry crate notices may retain reproducible 1970 timestamps.
            # ZIP dates start in 1980; clamp metadata while preserving file bytes.
            with zipfile.ZipFile(archive, 'x', zipfile.ZIP_DEFLATED, compresslevel=6, strict_timestamps=False) as zipped:
                for path in sorted(bundle.rglob('*')):
                    if path.is_file():
                        zipped.write(path, path.relative_to(bundle.parent).as_posix())
        else:
            archive = output / (bundle.name + '.tar.gz')
            with tarfile.open(archive, 'x:gz') as tar:
                tar.add(bundle, arcname=bundle.name)
        receipt['archive'] = {'path': str(archive), 'sha256': digest(archive), 'bytes': archive.stat().st_size}
        if args.wix_dir:
            if os_name != 'windows':
                raise RuntimeError('MSI requires a native Windows host')
            make_msi(bundle, output, args.wix_dir.resolve(), receipt)
        receipt['status'] = 'built_and_offline_smoke_passed'
    except Exception as error:
        receipt['status'] = 'failed'
        receipt['error'] = str(error)
        raise
    finally:
        receipt['finishedAt'] = datetime.now(timezone.utc).isoformat()
        write_json(receipt_file, receipt)
        artifacts = [p for p in output.iterdir() if p.is_file() and p.suffix in ['.zip', '.gz', '.msi']]
        (output / 'ARTIFACT-SHA256SUMS').write_text(''.join(f'{digest(p)}  {p.name}\n' for p in sorted(artifacts)), encoding='utf-8')


if __name__ == '__main__':
    main()
