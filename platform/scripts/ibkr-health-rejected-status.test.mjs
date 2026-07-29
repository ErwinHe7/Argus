import assert from 'node:assert/strict';
import http from 'node:http';
import Module from 'node:module';
import { dirname, resolve } from 'node:path';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import ts from 'typescript';

const sourceFile = resolve('lib/market-intelligence/ibkr-client-portal.ts');
const compiled = ts.transpileModule(readFileSync(sourceFile, 'utf8'), {
  compilerOptions: {
    esModuleInterop: true,
    module: ts.ModuleKind.CommonJS,
    target: ts.ScriptTarget.ES2022,
  },
  fileName: sourceFile,
});
const loaded = new Module(sourceFile);
loaded.filename = sourceFile;
loaded.paths = Module._nodeModulePaths(dirname(sourceFile));
loaded._compile(compiled.outputText, sourceFile);

test('rejected brokerage auth status remains read-only and reports the valid outer SSO', async () => {
  const requests = [];
  const server = http.createServer((req, res) => {
    requests.push(`${req.method} ${req.url}`);
    if (req.url === '/v1/api/sso/validate') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ RESULT: true }));
      return;
    }
    res.writeHead(401, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'brokerage session not authenticated' }));
  });
  await new Promise((resolveListen) => server.listen(0, '127.0.0.1', resolveListen));
  const address = server.address();
  assert.ok(address && typeof address === 'object');
  const previousBaseUrl = process.env.IBKR_BASE_URL;
  const previousEnabled = process.env.IBKR_MARKET_DATA_ENABLED;
  process.env.IBKR_BASE_URL = `http://127.0.0.1:${address.port}/v1/api`;
  process.env.IBKR_MARKET_DATA_ENABLED = 'true';
  try {
    const health = await loaded.exports.checkIbkrHealth();
    assert.equal(health.ok, false);
    assert.equal(health.ssoAuthenticated, true);
    assert.equal(health.brokerageAuthenticated, false);
    assert.equal(health.accountsPrimed, false);
    assert.equal(health.executionEnabled, false);
    assert.equal(health.sessionTakeoverAttempted, false);
    assert.match(health.reason, /authentication endpoint rejected or could not verify/i);
    assert.deepEqual(requests, [
      'GET /v1/api/sso/validate',
      'POST /v1/api/iserver/auth/status',
    ]);
  } finally {
    if (previousBaseUrl === undefined) delete process.env.IBKR_BASE_URL;
    else process.env.IBKR_BASE_URL = previousBaseUrl;
    if (previousEnabled === undefined) delete process.env.IBKR_MARKET_DATA_ENABLED;
    else process.env.IBKR_MARKET_DATA_ENABLED = previousEnabled;
    await new Promise((resolveClose, rejectClose) =>
      server.close((error) => (error ? rejectClose(error) : resolveClose()))
    );
  }
});
