// Local fixture preview only; serves the built public assets on loopback.
const http = require('node:http');
const path = require('node:path');
const fs = require('node:fs/promises');
const root = path.resolve(__dirname, '../../../public');
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.png': 'image/png', '.ttf': 'font/ttf', '.wasm': 'application/wasm' };
http.createServer(async (req, res) => {
  const pathname = new URL(req.url, 'http://127.0.0.1').pathname;
  const mapped = pathname === '/' || pathname === '/strategy-auth/callback' ? '/app/research-desk/index.html' : pathname;
  const file = path.resolve(root, '.' + mapped);
  if (!file.startsWith(root + path.sep)) { res.writeHead(403); res.end(); return; }
  try { const bytes = await fs.readFile(file); res.writeHead(200, { 'Content-Type': mime[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' }); res.end(bytes); }
  catch { res.writeHead(404); res.end('Not found'); }
}).listen(3231, '127.0.0.1', () => process.stdout.write('Membership fixture preview: http://127.0.0.1:3231\n'));
