import { build } from 'esbuild';
import { createHash } from 'node:crypto';
import { readFile, mkdir, copyFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { gridSourceHashes } from './grid-research-build.mjs';

export async function prepareGridAssets(root, output) {
  const receipt = JSON.parse(await readFile(resolve(root, '.quant-runtime/grid/build-receipt.json'), 'utf8'));
  if (JSON.stringify(await gridSourceHashes()) !== JSON.stringify(receipt.sourceHashes)) throw new Error('Grid WASM source changed. Run node scripts/grid-research-build.mjs before building the desk.');
  const binary = resolve(root, '.quant-runtime/grid/leo_grid_wasm.wasm');
  if (createHash('sha256').update(await readFile(binary)).digest('hex') !== receipt.wasmSha256) throw new Error('Grid WASM hash mismatch. Rebuild the local engine.');
  const directory = resolve(output, 'grid');
  await mkdir(directory, {recursive: true});
  await copyFile(binary, resolve(directory, 'leo_grid_wasm.wasm'));
  for (const name of ['range', 'decline', 'rally']) await copyFile(resolve(root, `features/strategy-lab/grid/fixtures/${name}.json`), resolve(directory, `${name}.json`));
  await copyFile(resolve(root, 'docs/strategy-lab/GRID-R1.md'), resolve(directory, 'GRID-R1.md'));
  await build({entryPoints: [resolve(root, 'features/strategy-lab/grid/grid.worker.ts')], outfile: resolve(directory, 'grid.worker.js'), bundle: true, platform: 'browser', format: 'esm', target: ['es2022'], minify: true});
}
