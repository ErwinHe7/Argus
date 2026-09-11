import { validatePublicMarketMapBundle } from '../../lib/market-map/validate';
import { isPublicUsMarketAsset } from '../../lib/market-map/public-catalog';
import { HORIZONS, sourceUrl, SYMBOLS } from './sources';

/** The general public schema also supports other markets. This production
 * service accepts only the complete, attributed HF/IEX US research bundle.
 */
export function validateUsBundle(raw: unknown, now = new Date()) {
  const bundle = validatePublicMarketMapBundle(raw, now);
  if (!bundle || bundle.snapshots.length !== SYMBOLS.length * Object.keys(HORIZONS).length) return null;
  const expected = new Set(SYMBOLS.flatMap((symbol) => Object.keys(HORIZONS).map((horizon) => `${symbol}:${horizon}`)));
  const cutoff = bundle.snapshots[0].provenance.observation_cutoff;
  for (const snapshot of bundle.snapshots) {
    if (!expected.delete(`${snapshot.asset.symbol}:${snapshot.horizon}`) || !isPublicUsMarketAsset(snapshot.asset) || snapshot.calendar !== 'exchange' ||
        snapshot.price_adjustment !== 'source_adjusted_unverified' || snapshot.bars.length !== 126 ||
        !snapshot.bars.every((bar) => bar.session === 'regular') || snapshot.provenance.observation_cutoff !== cutoff ||
        snapshot.provenance.rights.terms_url !== 'https://www.iex.io/legal/hist-data-terms' ||
        !snapshot.provenance.rights.usage_note.includes('Data provided for free by IEX.') ||
        snapshot.provenance.sources.length !== 2 ||
        !SYMBOLS.every((symbol) => snapshot.provenance.sources.some((source) => source.id === `hf-iex-${symbol.toLowerCase()}` && source.provider === 'HF Data Library / IEX Exchange HIST'))) return null;
  }
  if (expected.size || !SYMBOLS.every((symbol) => bundle.receipts.some((receipt) => receipt.url === sourceUrl(symbol)))) return null;
  // No bearer download token or auth header belongs in a served artifact.
  if (/token=|x-api-key|authorization["']?\s*:/i.test(JSON.stringify(bundle))) return null;
  return bundle;
}
