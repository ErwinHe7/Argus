/** Run: node --import tsx scripts/market-universe-refresh.ts
 * Downloads listing metadata only. No quotes, broker sessions or paid data access.
 */
import { mkdir, rename, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildMarketUniverseCatalog, fetchNasdaqDirectory } from '../lib/market-universe/ingest';

async function main() {
  if (process.argv.length !== 2) throw new Error('directory_arguments_invalid');
  const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
  const destination = resolve(root, '.quant-runtime/market-universe');
  const results = await Promise.allSettled([fetchNasdaqDirectory('nasdaq_listed'), fetchNasdaqDirectory('other_listed')]);
  const failure = results.find((result) => result.status === 'rejected');
  if (failure?.status === 'rejected') throw failure.reason;
  const texts = results.map((result) => result.status === 'fulfilled' ? result.value : '');
  const catalog = buildMarketUniverseCatalog(texts[0], texts[1], new Date().toISOString());
  if (catalog.sources.some((source) => source.rows < 1000)) throw new Error('directory_source_incomplete');
  await mkdir(destination, { recursive: true });
  // Preserve the last valid catalog unless both complete sources pass validation.
  for (const [index, source] of catalog.sources.entries()) {
    await writeFile(resolve(destination, `${source.sha256}.txt`), texts[index], 'utf8');
  }
  const temporary = resolve(destination, `catalog.${process.pid}.tmp`);
  await writeFile(temporary, JSON.stringify(catalog) + '\n', 'utf8');
  await rename(temporary, resolve(destination, 'catalog.json'));
  console.log(JSON.stringify({ status: 'READY', entries: catalog.entries.length, nasdaq_listed: catalog.entries.filter((entry) => entry.directory === 'nasdaq_listed').length,
    etfs: catalog.entries.filter((entry) => entry.security_kind === 'etf').length, generated_at: catalog.generated_at, expires_at: catalog.expires_at,
    sources: catalog.sources.map((source) => ({ url: source.url, source_creation_date: source.source_creation_date, sha256: source.sha256 })) }));
}

main().catch((error) => {
  const code = error instanceof Error && /^directory_[a-z_]+$/.test(error.message) ? error.message : 'directory_refresh_failed';
  console.error(JSON.stringify({ status: 'BLOCKED', code })); process.exitCode = 1;
});
