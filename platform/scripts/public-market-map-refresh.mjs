#!/usr/bin/env node
/** Run with: node --import tsx scripts/public-market-map-refresh.mjs */
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import sourceModule from '../workers/public-market-map/sources.ts';
import wasmModule from '../workers/public-market-map/wasm.ts';
import validatorModule from '../workers/public-market-map/bundle.ts';
const { digest, fetchSourceDocument, preparePublicInputs, PublicSourceError, sourceDocumentSchema, SYMBOLS, SNAPSHOT_KEY } = sourceModule;
const { computePublicSnapshot } = wasmModule;
const { validateUsBundle } = validatorModule;

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const cache = join(root, '.quant-runtime/public-market-map-us');
const artifacts = join(root, 'lib/market-map/artifacts');
await mkdir(cache, { recursive: true });
await mkdir(artifacts, { recursive: true });
try {
  if (!process.env.HF_DATA_API_KEY?.trim()) throw new PublicSourceError('hf_api_key_missing');
  const prepared = await preparePublicInputs(async (url, ttl) => {
    const file = join(cache, `${await digest(url)}.json`);
    const raw = await readFile(file, 'utf8').then(JSON.parse).catch(() => null);
    const parsed = sourceDocumentSchema.safeParse(raw);
    if (!process.argv.includes('--force') && parsed.success && Date.parse(parsed.data.expires_at) > Date.now()) return parsed.data;
    const document = await fetchSourceDocument(url, ttl, process.env.HF_DATA_API_KEY);
    await writeFile(file, JSON.stringify(document), 'utf8');
    await writeFile(join(cache, `raw-${document.sha256}.json`), JSON.stringify(document), 'utf8');
    return document;
  });
  await writeFile(join(cache, 'inputs.json'), JSON.stringify(prepared.inputs, null, 2), 'utf8');
  if (process.argv.includes('--fetch-only')) {
    console.log(JSON.stringify({ status: 'INPUTS_READY', symbols: SYMBOLS, input_count: prepared.inputs.length, observation_cutoff: prepared.inputs[0].bars.at(-1).observed_at, receipts: prepared.receipts.length }));
  } else {
    const wasm = await WebAssembly.compile(await readFile(join(root, 'workers/public-market-map/market-map.wasm')));
    const snapshots = prepared.inputs.map((input) => computePublicSnapshot(wasm, input));
    const bundle = { mode: 'public_market', generated_at: prepared.generated_at, expires_at: prepared.expires_at, snapshots, receipts: prepared.receipts };
    if (!validateUsBundle(bundle)) throw new PublicSourceError('public_bundle_contract_invalid');
    await writeFile(join(artifacts, 'public-us-bundle.json'), JSON.stringify(bundle), 'utf8');
    await writeFile(join(artifacts, 'public-us-source-receipts.json'), JSON.stringify(prepared.receipts, null, 2), 'utf8');
    console.log(JSON.stringify({ status: 'READY', snapshots: snapshots.length, observation_cutoff: snapshots[0].provenance.observation_cutoff, expires_at: bundle.expires_at, output: 'lib/market-map/artifacts/public-us-bundle.json', kv_key: SNAPSHOT_KEY }));
  }
} catch (error) {
  console.error(JSON.stringify({ status: 'BLOCKED', code: error instanceof PublicSourceError ? error.code : 'public_market_refresh_failed' }));
  process.exitCode = 1;
}
