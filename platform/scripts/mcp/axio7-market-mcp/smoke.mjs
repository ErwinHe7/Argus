// Smoke test: spawn the MCP stdio server, do an initialize handshake, then
// call tools/list and assert we see all 10 tools. Exits 0 on success.

import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const serverPath = resolve(__dirname, 'dist/index.js');

const child = spawn(process.execPath, [serverPath], {
  stdio: ['pipe', 'pipe', 'inherit'],
  env: { ...process.env },
});

const pending = new Map();
let buf = '';
let nextId = 1;

child.stdout.on('data', (chunk) => {
  buf += chunk.toString('utf8');
  let nl;
  while ((nl = buf.indexOf('\n')) !== -1) {
    const line = buf.slice(0, nl).trim();
    buf = buf.slice(nl + 1);
    if (!line) continue;
    try {
      const msg = JSON.parse(line);
      if (msg.id && pending.has(msg.id)) {
        const { resolve: r } = pending.get(msg.id);
        pending.delete(msg.id);
        r(msg);
      }
    } catch (err) {
      console.error('[smoke] parse error', err, 'line:', line);
    }
  }
});

function send(method, params) {
  const id = nextId++;
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    const frame = JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n';
    child.stdin.write(frame);
    setTimeout(() => {
      if (pending.has(id)) {
        pending.delete(id);
        reject(new Error(`timeout for ${method}`));
      }
    }, 10_000);
  });
}

async function run() {
  // 1. initialize
  const init = await send('initialize', {
    protocolVersion: '2024-11-05',
    capabilities: {},
    clientInfo: { name: 'smoke', version: '0.0.0' },
  });
  if (init.error) throw new Error(`initialize failed: ${JSON.stringify(init.error)}`);
  console.log('[smoke] initialize ok, server:', init.result?.serverInfo?.name);

  // 2. initialized notification (no id, no response)
  child.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }) + '\n');

  // 3. tools/list
  const list = await send('tools/list', {});
  if (list.error) throw new Error(`tools/list failed: ${JSON.stringify(list.error)}`);
  const tools = list.result?.tools || [];
  console.log(`[smoke] tools/list returned ${tools.length} tools`);
  for (const t of tools) {
    console.log(`  - ${t.name}`);
  }

  if (tools.length !== 10) {
    throw new Error(`expected 10 tools, got ${tools.length}`);
  }
  const expected = [
    'search_market_news',
    'get_market_signals',
    'get_ticker_brief',
    'get_options_chain',
    'get_max_pain_and_walls',
    'get_news_pulse',
    'get_macro_panel',
    'get_insider_filings',
    'get_source_health',
    'ingest_manual_event',
  ];
  const names = new Set(tools.map((t) => t.name));
  for (const e of expected) {
    if (!names.has(e)) throw new Error(`missing tool: ${e}`);
  }
  console.log('[smoke] all 10 tools present');

  child.kill('SIGTERM');
  process.exit(0);
}

run().catch((err) => {
  console.error('[smoke] FAIL:', err.message);
  child.kill('SIGTERM');
  process.exit(1);
});
