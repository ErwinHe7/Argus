/** Compile canonical Rust for browser-local replay, then seal its source receipt. */
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFile, writeFile, mkdir, copyFile } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
export const gridSources = [
  'quant_engine_rs/src/strategy_lab/decimal.rs',
  'quant_engine_rs/src/strategy_lab/grid/mod.rs',
  'quant_engine_rs/src/strategy_lab/grid/replay.rs',
  'quant_engine_rs/grid_wasm/Cargo.toml',
  'quant_engine_rs/grid_wasm/Cargo.lock',
  'quant_engine_rs/grid_wasm/src/lib.rs',
];
export async function gridSourceHashes() {
  return Object.fromEntries(await Promise.all(gridSources.map(async path => [path,
    createHash('sha256').update(await readFile(resolve(root, path))).digest('hex')])));
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const result = spawnSync('cargo', ['build', '--manifest-path', resolve(root, 'quant_engine_rs/grid_wasm/Cargo.toml'), '--release', '--target', 'wasm32-unknown-unknown'], { cwd: root, stdio: 'inherit', shell: false });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status || 1);
  const output = resolve(root, '.quant-runtime/grid');
  await mkdir(output, { recursive: true });
  const binary = resolve(root, 'quant_engine_rs/grid_wasm/target/wasm32-unknown-unknown/release/leo_grid_wasm.wasm');
  await copyFile(binary, resolve(output, 'leo_grid_wasm.wasm'));
  await writeFile(resolve(output, 'build-receipt.json'), JSON.stringify({
    schema: 'leo-grid-build.v1', createdAt: new Date().toISOString(),
    target: 'wasm32-unknown-unknown', sourceHashes: await gridSourceHashes(),
    wasmSha256: createHash('sha256').update(await readFile(binary)).digest('hex'),
    executionAuthorized: false,
  }, null, 2));
  console.log('Built canonical Grid Research WASM and source receipt.');
}
