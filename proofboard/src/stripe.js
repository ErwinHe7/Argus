// Reads revenue metrics from a founder's Stripe account using a restricted,
// read-only key. All amounts are in minor units (cents).

const STRIPE_VERSION = '2024-06-20'; // pinned so `subscription.discount` keeps its shape
const MAX_PAGES = 50; // 5,000 records per list; larger accounts fail closed
const INTERVALS_PER_MONTH = { day: 365.25 / 12, week: 52.1775 / 12, month: 1, year: 1 / 12 };

export class VerificationError extends Error {}

export function assertRestrictedKey(key, { allowTestKeys = false } = {}) {
  if (typeof key !== 'string' || !/^rk_(live|test)_[A-Za-z0-9]+$/.test(key.trim())) {
    throw new VerificationError(
      'Use a restricted key (rk_live_…) with read access to Subscriptions and Charges. Secret keys (sk_…) are not accepted.',
    );
  }
  if (key.startsWith('rk_test_') && !allowTestKeys) {
    throw new VerificationError('Test-mode keys cannot verify real revenue. Use a live restricted key.');
  }
}

async function stripeGet(apiBase, key, path, params) {
  const url = new URL(path, apiBase);
  for (const [name, value] of params) url.searchParams.append(name, value);
  let res;
  try {
    res = await fetch(url, {
      headers: { Authorization: `Bearer ${key}`, 'Stripe-Version': STRIPE_VERSION },
      signal: AbortSignal.timeout(15_000),
    });
  } catch {
    throw new VerificationError('Could not reach Stripe. Try again in a minute.');
  }
  const body = await res.json().catch(() => ({}));
  if (!res.ok) throw new VerificationError(body.error?.message || `Stripe returned HTTP ${res.status}.`);
  return body;
}

async function listAll(apiBase, key, path, params) {
  const rows = [];
  let startingAfter;
  for (let page = 0; page < MAX_PAGES; page++) {
    const pageParams = [...params, ['limit', '100']];
    if (startingAfter) pageParams.push(['starting_after', startingAfter]);
    const body = await stripeGet(apiBase, key, path, pageParams);
    if (!Array.isArray(body.data)) throw new VerificationError('Unexpected response from Stripe.');
    rows.push(...body.data);
    if (!body.has_more || body.data.length === 0) return rows;
    startingAfter = body.data.at(-1).id;
  }
  throw new VerificationError('Account has too many records to verify automatically.');
}

function subscriptionMonthlyAmount(sub) {
  let total = 0;
  for (const item of sub.items?.data ?? []) {
    const price = item.price;
    const interval = price?.recurring?.interval;
    if (price?.unit_amount == null || !(interval in INTERVALS_PER_MONTH)) {
      throw new VerificationError(
        `Subscription ${sub.id} uses pricing that cannot be verified yet (tiered or metered).`,
      );
    }
    const perMonth = INTERVALS_PER_MONTH[interval] / (price.recurring.interval_count || 1);
    total += price.unit_amount * (item.quantity ?? 1) * perMonth;
  }
  const coupon = sub.discount?.coupon;
  if (coupon?.percent_off) total *= 1 - coupon.percent_off / 100;
  return Math.max(0, total);
}

export async function fetchRevenueMetrics(key, { apiBase = 'https://api.stripe.com', now = Date.now() } = {}) {
  const since = Math.floor(now / 1000) - 30 * 24 * 60 * 60;
  const [subscriptions, charges] = await Promise.all([
    listAll(apiBase, key, '/v1/subscriptions', [['status', 'active']]),
    listAll(apiBase, key, '/v1/charges', [['created[gte]', String(since)]]),
  ]);

  const currencies = new Set([...subscriptions, ...charges].map((row) => row.currency).filter(Boolean));
  if ([...currencies].some((c) => c !== 'usd')) {
    throw new VerificationError('Only USD revenue is supported for now.');
  }

  const mrr = subscriptions.reduce((sum, sub) => sum + subscriptionMonthlyAmount(sub), 0);
  const revenue30d = charges
    .filter((charge) => charge.status === 'succeeded' && charge.paid)
    .reduce((sum, charge) => sum + charge.amount - (charge.amount_refunded ?? 0), 0);

  return {
    currency: 'usd',
    mrr: Math.round(mrr),
    revenue30d,
    activeSubscriptions: subscriptions.length,
  };
}
