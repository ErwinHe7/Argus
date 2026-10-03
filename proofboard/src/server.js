import { readFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { openDatabase } from './db.js';
import { createSealer } from './secrets.js';
import { assertRestrictedKey, fetchRevenueMetrics, VerificationError } from './stripe.js';
import { addPage, leaderboardPage, notFoundPage, startupPage } from './views.js';

const STYLE = readFileSync(fileURLToPath(new URL('../public/style.css', import.meta.url)));
const MAX_BODY_BYTES = 10_000;
const SUBMISSIONS_PER_HOUR = 10;
const SECURITY_HEADERS = {
  'Content-Security-Policy':
    "default-src 'none'; style-src 'self'; img-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
};

export function loadConfig(env = process.env) {
  return {
    port: Number(env.PORT || 3000),
    databasePath: env.DATABASE_PATH || 'data/proofboard.db',
    appSecret: env.APP_SECRET,
    stripeApiBase: env.STRIPE_API_BASE || 'https://api.stripe.com',
    allowTestKeys: env.ALLOW_TEST_KEYS === '1',
    trustProxy: env.TRUST_PROXY === '1',
    refreshMinutes: Number(env.REFRESH_MINUTES || 60),
    staleAfterHours: Number(env.STALE_AFTER_HOURS || 48),
    sponsorCheckoutUrl: env.SPONSOR_CHECKOUT_URL || '',
    sponsorsFile: env.SPONSORS_FILE || 'sponsors.json',
  };
}

function isHttpUrl(value) {
  try {
    return ['http:', 'https:'].includes(new URL(value).protocol);
  } catch {
    return false;
  }
}

export function loadSponsors(path) {
  let raw;
  try {
    raw = readFileSync(path, 'utf8');
  } catch {
    return [];
  }
  const sponsors = JSON.parse(raw);
  if (!Array.isArray(sponsors) || !sponsors.every((s) => s?.name && isHttpUrl(s.url))) {
    throw new Error(`${path} must be a JSON array of { name, url, tagline } with http(s) URLs.`);
  }
  return sponsors;
}

const redactKeys = (message) => String(message).replace(/[rs]k_(live|test)_\S+/g, '[key]');

function slugify(text) {
  return text.toLowerCase().normalize('NFKD').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 40);
}

function readForm(req) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > MAX_BODY_BYTES) {
        reject(new VerificationError('Submission too large.'));
        req.destroy();
      } else chunks.push(chunk);
    });
    req.on('end', () => resolve(new URLSearchParams(Buffer.concat(chunks).toString('utf8'))));
    req.on('error', reject);
  });
}

export function createApp({ db, sealer, config, sponsors = [], now = () => Date.now() }) {
  const staleAfterMs = config.staleAfterHours * 3_600_000;
  const submissions = new Map(); // ip -> timestamps of recent submissions

  const rankedStartups = () => db.ranked(new Date(now() - staleAfterMs).toISOString());

  function clientIp(req) {
    const forwarded = config.trustProxy && req.headers['x-forwarded-for'];
    return forwarded ? forwarded.split(',')[0].trim() : req.socket.remoteAddress;
  }

  function allowSubmission(ip) {
    const recent = (submissions.get(ip) ?? []).filter((t) => now() - t < 3_600_000);
    if (recent.length >= SUBMISSIONS_PER_HOUR) return false;
    submissions.set(ip, [...recent, now()]);
    return true;
  }

  async function addStartup(form) {
    const name = (form.get('name') ?? '').trim().slice(0, 60);
    const description = (form.get('description') ?? '').trim().slice(0, 120);
    const stripeKey = (form.get('stripeKey') ?? '').trim();
    const websiteInput = (form.get('website') ?? '').trim();
    if (!name) throw new VerificationError('Startup name is required.');
    if (!isHttpUrl(websiteInput)) throw new VerificationError('Website must be a valid http(s) URL.');
    const website = new URL(websiteInput);
    const hostname = website.hostname.toLowerCase().replace(/^www\./, '');
    if (db.hostnameTaken(hostname)) throw new VerificationError(`${hostname} is already listed.`);
    assertRestrictedKey(stripeKey, { allowTestKeys: config.allowTestKeys });

    const metrics = await fetchRevenueMetrics(stripeKey, { apiBase: config.stripeApiBase, now: now() });

    const base = slugify(name) || slugify(hostname) || 'startup';
    let slug = base;
    for (let n = 2; db.slugTaken(slug); n++) slug = `${base}-${n}`;
    try {
      db.insert({
        slug, name, description, hostname,
        website: website.href,
        keySealed: sealer.seal(stripeKey),
        ...metrics,
        verifiedAt: new Date(now()).toISOString(),
      });
    } catch (err) {
      if (/UNIQUE/.test(err.message)) throw new VerificationError(`${hostname} is already listed.`);
      throw err;
    }
    return slug;
  }

  async function handle(req, res) {
    const url = new URL(req.url, 'http://localhost');
    const send = (status, body, type = 'text/html; charset=utf-8', extra = {}) => {
      res.writeHead(status, { 'Content-Type': type, ...SECURITY_HEADERS, ...extra });
      res.end(body);
    };

    if (req.method === 'GET' && url.pathname === '/') {
      return send(200, leaderboardPage({
        startups: rankedStartups(), sponsors, checkoutUrl: config.sponsorCheckoutUrl, now: now(),
      }));
    }
    if (req.method === 'GET' && url.pathname === '/style.css') {
      return send(200, STYLE, 'text/css; charset=utf-8', { 'Cache-Control': 'public, max-age=3600' });
    }
    if (req.method === 'GET' && url.pathname === '/healthz') return send(200, 'ok', 'text/plain');
    if (req.method === 'GET' && url.pathname === '/api/startups') {
      const startups = rankedStartups().map((s, i) => ({ rank: i + 1, ...s }));
      return send(200, JSON.stringify({ startups }), 'application/json');
    }
    if (req.method === 'GET' && url.pathname === '/add') return send(200, addPage());
    if (req.method === 'POST' && url.pathname === '/add') {
      let form = new URLSearchParams();
      try {
        form = await readForm(req);
        if (!allowSubmission(clientIp(req))) {
          throw new VerificationError('Too many submissions. Try again in an hour.');
        }
        const slug = await addStartup(form);
        res.writeHead(303, { Location: `/s/${slug}`, ...SECURITY_HEADERS });
        return res.end();
      } catch (err) {
        if (!(err instanceof VerificationError)) throw err;
        const values = Object.fromEntries(['name', 'website', 'description'].map((k) => [k, form.get(k) ?? '']));
        return send(422, addPage({ error: redactKeys(err.message), values }));
      }
    }
    const profile = req.method === 'GET' && url.pathname.match(/^\/s\/([a-z0-9-]+)$/);
    const startup = profile && db.get(profile[1]);
    if (startup) return send(200, startupPage({ startup, staleAfterMs, now: now() }));
    return send(404, notFoundPage());
  }

  async function refreshAll() {
    for (const { slug, key_sealed: sealed } of db.sealedKeys()) {
      try {
        const metrics = await fetchRevenueMetrics(sealer.open(sealed), { apiBase: config.stripeApiBase, now: now() });
        db.updateMetrics(slug, metrics, new Date(now()).toISOString());
      } catch (err) {
        const message = redactKeys(err.message);
        db.markRefreshError(slug, message);
        console.warn(`refresh failed for ${slug}: ${message}`);
      }
    }
  }

  const server = createServer((req, res) => {
    handle(req, res).catch((err) => {
      console.error(redactKeys(err.stack ?? err));
      if (!res.headersSent) res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('Internal error');
    });
  });
  return { server, refreshAll };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const config = loadConfig();
  const sealer = createSealer(config.appSecret); // throws (fails closed) without APP_SECRET
  const app = createApp({ db: openDatabase(config.databasePath), sealer, config, sponsors: loadSponsors(config.sponsorsFile) });
  app.server.listen(config.port, () => console.log(`Proofboard listening on :${config.port}`));
  setInterval(() => app.refreshAll().catch((err) => console.error(redactKeys(err))), config.refreshMinutes * 60_000);
}
