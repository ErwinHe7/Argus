import 'server-only';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { isMarketUniverseFresh, validateMarketUniverseCatalog } from './catalog';
import type { MarketUniverseLoadResult } from './types';

/** Local catalog is populated by the explicit refresh command, never a request-time vendor fetch. */
export async function loadMarketUniverse(now = new Date()): Promise<MarketUniverseLoadResult> {
  let text: string;
  try { text = await readFile(resolve(process.cwd(), '.quant-runtime/market-universe/catalog.json'), 'utf8'); }
  catch { return { available: false, reason: 'directory_missing' }; }
  if (Buffer.byteLength(text, 'utf8') > 16_000_000) return { available: false, reason: 'directory_invalid' };
  let raw: unknown;
  try { raw = JSON.parse(text); } catch { return { available: false, reason: 'directory_invalid' }; }
  const catalog = validateMarketUniverseCatalog(raw, now);
  if (!catalog) return { available: false, reason: 'directory_invalid' };
  if (!isMarketUniverseFresh(catalog, now)) return { available: false, reason: 'directory_stale' };
  return { available: true, catalog };
}
