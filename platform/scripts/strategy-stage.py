"""Prepare a fresh static overlay; never deploy or rebuild the retained backend."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil


def manifest(root: Path, exclude_assets: bool = False) -> dict[str, str]:
    result = {}
    for path in sorted(root.rglob('*')):
        relative = path.relative_to(root)
        if path.is_file() and not (exclude_assets and relative.parts[0] == 'assets'):
            with path.open('rb') as stream:
                result[relative.as_posix()] = hashlib.file_digest(stream, 'sha256').hexdigest()
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True, help='Verified prior static-overlay release')
    parser.add_argument('--destination', type=Path, required=True, help='New, nonexistent release directory')
    parser.add_argument('--shortlist-feed', action='store_true', help='Bind the separately deployed read-only shortlist feed')
    parser.add_argument('--event-radar', action='store_true', help='Bind the separately deployed official-calendar radar')
    args = parser.parse_args()
    source, destination = args.source.resolve(), args.destination.resolve()
    platform = Path(__file__).resolve().parents[1]
    if destination.exists() or source == destination or source in destination.parents:
        raise SystemExit('Use a new destination outside the source release; nothing was overwritten.')
    if not (source / '.open-next/worker.js').is_file():
        raise SystemExit('Source has no frozen OpenNext Worker.')
    config = json.loads((source / 'wrangler.jsonc').read_text(encoding='utf-8-sig'))
    if config.get('main') != 'features/research-desk/worker-entry.mjs' or config.get('name') != 'leo':
        raise SystemExit('Source is not the retained Astra homepage overlay.')
    public_config = json.loads((platform / 'public/app/research-desk/strategy-config.json').read_text())
    before = manifest(source / '.open-next', exclude_assets=True)
    before_assets = manifest(source / '.open-next/assets')
    destination.mkdir(parents=True)
    shutil.copytree(source / '.open-next', destination / '.open-next')
    shutil.copy2(source / 'wrangler.jsonc', destination / 'wrangler.jsonc')
    if args.shortlist_feed:
        services = config.setdefault('services', [])
        existing = [item for item in services if item.get('binding') == 'SHORTLIST_FEED']
        if existing and existing != [{'binding': 'SHORTLIST_FEED', 'service': 'leo-shortlist-feed'}]:
            raise SystemExit('Conflicting shortlist binding; no deployment performed.')
        if not existing:
            services.append({'binding': 'SHORTLIST_FEED', 'service': 'leo-shortlist-feed'})
        route = '/app/research-desk/data/shortlist-feed/current.json'
        first = config['assets'].get('run_worker_first', [])
        if first is not True:
            config['assets']['run_worker_first'] = list(dict.fromkeys((first or []) + [route]))
    if args.event_radar:
        services = config.setdefault('services', [])
        existing = [item for item in services if item.get('binding') == 'EVENT_RADAR']
        if existing and existing != [{'binding': 'EVENT_RADAR', 'service': 'leo-event-radar'}]:
            raise SystemExit('Conflicting radar binding; no deployment performed.')
        if not existing:
            services.append({'binding': 'EVENT_RADAR', 'service': 'leo-event-radar'})
        route = '/app/research-desk/data/event-radar.json'
        first = config['assets'].get('run_worker_first', [])
        if first is not True:
            config['assets']['run_worker_first'] = list(dict.fromkeys((first or []) + [route]))
    (destination / 'wrangler.jsonc').write_text(json.dumps(config, indent=2) + '\n', encoding='utf-8')
    target_feature = destination / 'features/research-desk'
    target_feature.mkdir(parents=True)
    for name in ('worker-entry.mjs', 'worker-routing.ts'):
        shutil.copy2(platform / 'features/research-desk' / name, target_feature / name)
    # Runtime publication is read through the service binding. Do not freeze a
    # local heartbeat into static release assets or package convenience files.
    shutil.copytree(platform / 'public/app/research-desk', destination / '.open-next/assets/app/research-desk', dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns('shortlist-feed'))
    after = manifest(destination / '.open-next', exclude_assets=True)
    after_assets = manifest(destination / '.open-next/assets')
    if before != after:
        raise SystemExit('FAIL: frozen backend differs. Stage is not releasable.')
    unrelated = lambda records: {k: v for k, v in records.items() if not k.startswith('app/research-desk/')}
    if unrelated(before_assets) != unrelated(after_assets):
        raise SystemExit('FAIL: unrelated static assets differ. Stage is not releasable.')
    receipt = {
        'schema': 'leo-strategy-stage/v1', 'createdAt': datetime.now(timezone.utc).isoformat(),
        'source': str(source), 'status': 'prepared-not-deployed',
        'backendUnchanged': True, 'backendFileCount': len(before),
        'unrelatedAssetsUnchanged': True, 'workerConfigurationUnchanged': not (args.shortlist_feed or args.event_radar),
        'shortlistFeedBindingAdded': args.shortlist_feed,
        'eventRadarBindingAdded': args.event_radar,
        'hostnameUnchanged': config['name'] == 'leo',
        'strategyConnectionsEnabled': public_config['enabled'],
        'changedAssets': [key for key in after_assets if before_assets.get(key) != after_assets[key]],
        'removedAssets': [key for key in before_assets if key not in after_assets],
        'externalPrerequisites': ['strategy-api and database deployment', 'Google callback allowlist',
            'public connection configuration', 'native OS and OpenD integration receipts',
            'distribution signing/notarization', 'entitled market data', 'paper lifecycle and recovery evidence'],
    }
    for name, data in [('backend-manifest.json', after), ('assets-manifest.json', after_assets), ('stage-receipt.json', receipt)]:
        (destination / name).write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(receipt, indent=2))


if __name__ == '__main__':
    main()
