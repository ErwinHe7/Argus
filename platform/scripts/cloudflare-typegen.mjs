import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const wrangler = fileURLToPath(new URL('../node_modules/wrangler/bin/wrangler.js', import.meta.url));
execFileSync(process.execPath, [wrangler, 'types', '--env-interface', 'CloudflareEnv', 'cloudflare-env.d.ts', '--include-runtime', 'false'], { cwd: root, stdio: 'inherit' });
const output = new URL('../cloudflare-env.d.ts', import.meta.url);
// OpenNext's generated entry imports an entire optimized server bundle. The
// website needs generated binding types, not inference over its own build output.
writeFileSync(output, readFileSync(output, 'utf8').replace(/^\s*mainModule: typeof import\("\.\/\.open-next\/worker"\);\r?\n/m, ''));
