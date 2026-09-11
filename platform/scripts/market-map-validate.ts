import { readFileSync } from 'node:fs';
import { validateMarketMapSnapshot } from '../lib/market-map/validate';

const entries = Object.values(JSON.parse(readFileSync(process.argv[2], 'utf8').replace(/^\uFEFF/, '')) as Record<string, unknown>);
if (!entries.length || entries.some((snapshot) => !validateMarketMapSnapshot(snapshot))) {
  console.error('market_map_snapshot_validation_failed');
  process.exitCode = 1;
}
