/** Run from platform: node --import tsx scripts/iv-lab-import.mjs */
import { readFile, mkdir, writeFile, rename } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { ivLabBundleSchema, ivLabEventsSchema } = require('../lib/iv-lab/types.ts');

const scriptRoot = dirname(fileURLToPath(import.meta.url));
const platformRoot = resolve(scriptRoot, '..');
const sourceRoot = resolve(platformRoot, '../../deliverables/leo-iv-research');
const artifactRoot = resolve(platformRoot, 'lib/iv-lab/artifacts');

// Both inputs must validate before any existing published artifact is replaced.
const bundleText = await readFile(resolve(sourceRoot, 'derived/iv-lab.json'), 'utf8');
const eventsText = await readFile(resolve(sourceRoot, 'events.json'), 'utf8');
const bundle = ivLabBundleSchema.parse(JSON.parse(bundleText));
ivLabEventsSchema.parse(JSON.parse(eventsText));
const schemaText = await readFile(resolve(sourceRoot, 'derived/schema.ts'), 'utf8');
await mkdir(artifactRoot, { recursive: true });
for (const [name, text] of [['iv-lab.json', bundleText], ['events.json', eventsText], ['schema.ts', schemaText]]) {
  const target = resolve(artifactRoot, name);
  const temporary = `${target}.importing`;
  await writeFile(temporary, text, 'utf8');
  await rename(temporary, target);
}
process.stdout.write(`Imported ${bundle.symbols.length} historical research symbols; source generation ${bundle.generatedAt}.\n`);
