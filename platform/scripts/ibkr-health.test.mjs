import assert from 'node:assert/strict';
import http from 'node:http';
import Module from 'node:module';
import { dirname, resolve } from 'node:path';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import ts from 'typescript';

const sourceFile = resolve('lib/market-intelligence/ibkr-client-portal.ts');

function loadIbkrModule() {
  const source = readFileSync(sourceFile, 'utf8');
  const compiled = ts.transpileModule(source, {
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
  return loaded.exports;
}

const { checkIbkrHealth } = loadIbkrModule();

async function withMockGateway(responses, run) {
  const requests = [];
  const server = http.createServer((req, res) => {
    let body = '';
    req.setEncoding('utf8');
    req.on('data', (chunk) => {
      body += chunk;
    });
    req.on('end', () => {
      requests.push({ method: req.method, url: req.url, body });
      const response = responses[`${req.method} ${req.url}`];
      res.writeHead(response ? 200 : 404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(response ?? { error: 'not found' }));
    });
  });
  await new Promise((resolveListen) => server.listen(0, '127.0.0.1', resolveListen));
  const address = server.address();
  assert.ok(address && typeof address === 'object');

  const previous = {
    baseUrl: process.env.IBKR_BASE_URL,
    enabled: process.env.IBKR_MARKET_DATA_ENABLED,
    timeout: process.env.IBKR_TIMEOUT_MS,
  };
  process.env.IBKR_BASE_URL = `http://127.0.0.1:${address.port}/v1/api`;
  process.env.IBKR_MARKET_DATA_ENABLED = 'true';
  process.env.IBKR_TIMEOUT_MS = '2000';

  try {
    await run(requests);
  } finally {
    for (const [key, value] of [
      ['IBKR_BASE_URL', previous.baseUrl],
      ['IBKR_MARKET_DATA_ENABLED', previous.enabled],
      ['IBKR_TIMEOUT_MS', previous.timeout],
    ]) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
    await new Promise((resolveClose, rejectClose) =>
      server.close((error) => (error ? rejectClose(error) : resolveClose()))
    );
  }
}

test(
  'health accepts uppercase SSO RESULT and verifies brokerage auth with a read-only POST',
  { concurrency: false },
  async () => {
    await withMockGateway(
      {
        'GET /v1/api/sso/validate': { RESULT: true },
        'POST /v1/api/iserver/auth/status': {
          authenticated: true,
          competing: false,
          connected: true,
          message: '',
        },
        'GET /v1/api/iserver/accounts': [{ accountId: 'test-account' }],
      },
      async (requests) => {
        const health = await checkIbkrHealth();
        assert.equal(health.ok, true);
        assert.equal(health.authenticated, true);
        assert.equal(health.ssoAuthenticated, true);
        assert.equal(health.brokerageAuthenticated, true);
        assert.equal(health.brokerageConnected, true);
        assert.equal(health.accountsPrimed, true);
        assert.equal(health.executionEnabled, false);
        assert.equal(health.sessionTakeoverAttempted, false);
        assert.deepEqual(
          requests.map(({ method, url }) => `${method} ${url}`),
          [
            'GET /v1/api/sso/validate',
            'POST /v1/api/iserver/auth/status',
            'GET /v1/api/iserver/accounts',
          ]
        );
        assert.equal(requests[1].body, '{}');
      }
    );
  }
);

test(
  'valid outer SSO with unauthenticated brokerage reports status without priming or takeover',
  { concurrency: false },
  async () => {
    await withMockGateway(
      {
        'GET /v1/api/sso/validate': { RESULT: true },
        'POST /v1/api/iserver/auth/status': {
          authenticated: false,
          competing: false,
          connected: true,
          message: '',
        },
      },
      async (requests) => {
        const health = await checkIbkrHealth();
        assert.equal(health.ok, false);
        assert.equal(health.authenticated, false);
        assert.equal(health.ssoAuthenticated, true);
        assert.equal(health.brokerageAuthenticated, false);
        assert.equal(health.brokerageConnected, true);
        assert.equal(health.accountsPrimed, false);
        assert.match(health.reason, /brokerage session is not authenticated/i);
        assert.equal(health.executionEnabled, false);
        assert.equal(health.sessionTakeoverAttempted, false);
        assert.deepEqual(
          requests.map(({ method, url }) => `${method} ${url}`),
          [
            'GET /v1/api/sso/validate',
            'POST /v1/api/iserver/auth/status',
          ]
        );
        assert.ok(requests.every(({ url }) => !url.includes('ssodh/init')));
      }
    );
  }
);
