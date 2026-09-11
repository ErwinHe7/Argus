import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';

export const legacyChunk = '_next/static/chunks/app/layout-17f5d2848155fa3a.js';
export const expectedOriginalSha256 = '42cf56fcdb8f619ae0bfece8638dd5dc38b359080b6cda6f5e3a0882ec0e98fc';
export const originalCondition = 'return"/"===l||"/research"===l||"/acceptance/research"===l||l.startsWith("/discover/market-map")?';
export const patchedCondition = 'return"/"===l||"/original"===l||"/original/"===l||"/research"===l||"/acceptance/research"===l||l.startsWith("/discover/market-map")?';
const hash = value => createHash('sha256').update(value).digest('hex');

export function patchOriginalHomeLayout(source) {
  assert.equal(source.split(originalCondition).length - 1, 1, 'Expected one exact frozen AppShell condition');
  assert.equal(source.includes(patchedCondition), false, 'AppShell alias is already patched');
  return source.replace(originalCondition, patchedCondition);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  assert.ok(process.argv[2], 'Pass the isolated release assets directory');
  const path = join(resolve(process.argv[2]), legacyChunk);
  const before = readFileSync(path, 'utf8');
  let original = before;
  if (before.includes(patchedCondition)) {
    assert.equal(before.split(patchedCondition).length - 1, 1, 'Expected one patched AppShell condition');
    original = before.replace(patchedCondition, originalCondition);
  }
  assert.equal(hash(original), expectedOriginalSha256, 'Unexpected original layout chunk; refusing patch');
  const after = patchOriginalHomeLayout(original);
  assert.equal(after.replace(patchedCondition, originalCondition), original, 'Patch changed unrelated bytes');
  if (after !== before) writeFileSync(path, after);
  console.log(JSON.stringify({path:legacyChunk, originalSha256:hash(original), patchedSha256:hash(after), changed:after!==before}));
}
