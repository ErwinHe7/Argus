// Server-rendered HTML. Every interpolated value goes through `esc`.

export const BRAND = 'Proofboard';

export function esc(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
}

const usd = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 });
export const money = (cents) => usd.format(cents / 100);

function timeAgo(iso, now) {
  const minutes = Math.max(0, Math.round((now - Date.parse(iso)) / 60_000));
  if (minutes < 60) return `${minutes}m ago`;
  if (minutes < 48 * 60) return `${Math.round(minutes / 60)}h ago`;
  return `${Math.round(minutes / 1440)}d ago`;
}

function layout(title, body) {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
<meta name="description" content="Startup revenue you can trust, verified through read-only Stripe keys.">
<link rel="stylesheet" href="/style.css">
</head>
<body>
<header class="top"><div class="wrap">
  <a class="brand" href="/">${BRAND}<span>.</span></a>
  <a class="btn" href="/add">+ Add your startup</a>
</div></header>
<main class="wrap">${body}</main>
<footer class="wrap muted">Every number is pulled from Stripe with a read-only key and refreshed hourly. No screenshots, no self-reporting.</footer>
</body>
</html>`;
}

function sponsorRail(sponsors, checkoutUrl) {
  const cards = sponsors
    .map(
      (s) => `<a class="sponsor" href="${esc(s.url)}" rel="sponsored noopener" target="_blank">
        <strong>${esc(s.name)}</strong><span>${esc(s.tagline)}</span></a>`,
    )
    .join('');
  const cta = checkoutUrl
    ? `<a class="sponsor open" href="${esc(checkoutUrl)}" rel="noopener" target="_blank">
        <strong>Your product here</strong><span>Reach founders who check this board every day.</span></a>`
    : '';
  if (!cards && !cta) return '';
  return `<aside class="rail"><h2>Sponsors</h2>${cards}${cta}</aside>`;
}

export function leaderboardPage({ startups, sponsors, checkoutUrl, now }) {
  const total = startups.reduce((sum, s) => sum + s.mrr, 0);
  const rows = startups.length
    ? startups
        .map(
          (s, i) => `<tr>
        <td class="rank">${i + 1}</td>
        <td><a class="name" href="/s/${esc(s.slug)}">${esc(s.name)}</a>
            <div class="muted small">${esc(new URL(s.website).hostname)}${s.description ? ` · ${esc(s.description)}` : ''}</div></td>
        <td class="num">${money(s.mrr)}</td>
        <td class="num hide-sm">${money(s.revenue_30d)}</td>
        <td class="num hide-sm muted small">${timeAgo(s.verified_at, now)}</td>
      </tr>`,
        )
        .join('')
    : `<tr><td colspan="5" class="empty">No verified startups yet. <a href="/add">Be the first.</a></td></tr>`;

  return layout(
    `${BRAND} — verified startup revenue`,
    `<section class="hero">
      <h1>Startup revenue,<br>verified by Stripe.</h1>
      <p class="muted">${startups.length} startup${startups.length === 1 ? '' : 's'} · ${money(total)} combined MRR</p>
    </section>
    <div class="grid">
      <table class="board">
        <thead><tr><th>#</th><th>Startup</th><th class="num">MRR</th><th class="num hide-sm">Last 30 days</th><th class="num hide-sm">Verified</th></tr></thead>
        <tbody>${rows}</tbody>
      </table>
      ${sponsorRail(sponsors, checkoutUrl)}
    </div>`,
  );
}

export function startupPage({ startup, staleAfterMs, now }) {
  const stale = now - Date.parse(startup.verified_at) > staleAfterMs;
  const host = new URL(startup.website).hostname;
  return layout(
    `${startup.name} revenue — ${BRAND}`,
    `<article class="profile">
      <h1>${esc(startup.name)}</h1>
      <p><a href="${esc(startup.website)}" rel="noopener" target="_blank">${esc(host)} ↗</a></p>
      ${startup.description ? `<p class="muted">${esc(startup.description)}</p>` : ''}
      ${
        stale
          ? `<p class="notice">Verification lapsed ${timeAgo(startup.verified_at, now)}. These numbers are no longer current and this startup is hidden from the leaderboard.</p>`
          : ''
      }
      <div class="stats">
        <div><span class="muted small">MRR</span><strong>${money(startup.mrr)}</strong></div>
        <div><span class="muted small">Revenue, last 30 days</span><strong>${money(startup.revenue_30d)}</strong></div>
        <div><span class="muted small">Active subscriptions</span><strong>${startup.active_subscriptions}</strong></div>
      </div>
      <p class="muted small">Verified via Stripe ${timeAgo(startup.verified_at, now)} (${esc(startup.verified_at)}).</p>
    </article>`,
  );
}

export function addPage({ error = '', values = {} } = {}) {
  return layout(
    `Add your startup — ${BRAND}`,
    `<section class="form-wrap">
      <h1>Add your startup</h1>
      <p class="muted">Create a <a href="https://dashboard.stripe.com/apikeys/create" rel="noopener" target="_blank">restricted key</a>
        in Stripe with <strong>Read</strong> access to <em>Subscriptions</em> and <em>Charges</em> only. It can't move money or change anything.</p>
      ${error ? `<p class="error" role="alert">${esc(error)}</p>` : ''}
      <form method="post" action="/add">
        <label>Startup name<input name="name" required maxlength="60" value="${esc(values.name)}"></label>
        <label>Website<input name="website" type="url" required placeholder="https://" maxlength="200" value="${esc(values.website)}"></label>
        <label>One-line description<input name="description" maxlength="120" value="${esc(values.description)}"></label>
        <label>Stripe restricted key<input name="stripeKey" required autocomplete="off" placeholder="rk_live_…"></label>
        <button class="btn" type="submit">Verify revenue</button>
      </form>
      <p class="muted small">Your key is encrypted at rest and only used to refresh your numbers hourly. Revoke it in Stripe anytime to delist.</p>
    </section>`,
  );
}

export function notFoundPage() {
  return layout(`Not found — ${BRAND}`, `<section class="hero"><h1>Not found.</h1><p><a href="/">Back to the leaderboard</a></p></section>`);
}
