import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import { authRedirectOrigin } from '../lib/auth-redirect-origin.ts';
import { safeInternalRedirectPath } from '../lib/safe-internal-redirect.ts';

const read = (path) =>
  readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

test('normal internal auth redirect paths are preserved', () => {
  for (const path of [
    '/',
    '/pricing',
    '/welcome?plan=pro',
    '/quant/research#latest',
    '/nested/path//segment',
  ]) {
    assert.equal(safeInternalRedirectPath(path), path);
  }
});

test('external and protocol-relative auth redirect targets fail closed', () => {
  for (const unsafe of [
    null,
    '',
    'pricing',
    'https://example.com',
    '//example.com',
    '///example.com',
    '/\\example.com',
    '\\\\example.com',
    'javascript:alert(1)',
  ]) {
    assert.equal(safeInternalRedirectPath(unsafe), '/');
  }
});

test('auth callback and sign-out share the hardened redirect helper', () => {
  for (const route of [
    'app/auth/callback/route.ts',
    'app/auth/signout/route.ts',
  ]) {
    const source = read(route);
    assert.match(source, /safeInternalRedirectPath/);
    assert.doesNotMatch(source, /next\.startsWith\(['"]\/['"]\)/);
    assert.match(source, /authRedirectOrigin/);
  }
});

test('production auth redirects never expose the standalone server bind address', () => {
  const request = new Request(
    'https://0.0.0.0:3000/auth/callback?code=test&next=%2Fpricing',
    {
      headers: {
        'x-forwarded-host': 'axio7.com',
        'x-forwarded-proto': 'https',
      },
    }
  );

  assert.equal(
    authRedirectOrigin(request, {
      NODE_ENV: 'production',
      AXIO7_SITE_URL: 'https://axio7.com',
    }),
    'https://axio7.com'
  );
});

test('development auth redirects preserve localhost without a matching proxy', () => {
  const request = new Request('http://localhost:3000/auth/callback?code=test');

  assert.equal(
    authRedirectOrigin(request, {
      NODE_ENV: 'development',
      AXIO7_SITE_URL: 'https://axio7.com',
    }),
    'http://localhost:3000'
  );
});

test('production auth redirects fail closed without a configured public site', () => {
  const request = new Request('https://0.0.0.0:3000/auth/callback?code=test');

  assert.throws(
    () => authRedirectOrigin(request, { NODE_ENV: 'production' }),
    /AXIO7_SITE_URL is required/
  );
});
