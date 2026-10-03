import { createServer } from 'node:http';

// Minimal stand-in for the Stripe list endpoints, with cursor pagination.
export async function startFakeStripe({ subscriptions = [], charges = [], validKey = 'rk_live_good', pageSize = 100 } = {}) {
  const requests = [];
  const server = createServer((req, res) => {
    const url = new URL(req.url, 'http://x');
    requests.push(url);
    const reply = (status, body) => {
      res.writeHead(status, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(body));
    };
    if (req.headers.authorization !== `Bearer ${state.validKey}`) {
      return reply(401, { error: { message: 'Invalid API Key provided: rk_live_****good' } });
    }
    const rows = { '/v1/subscriptions': state.subscriptions, '/v1/charges': state.charges }[url.pathname];
    if (!rows) return reply(404, { error: { message: 'Unrecognized request URL' } });
    const after = url.searchParams.get('starting_after');
    const start = after ? rows.findIndex((r) => r.id === after) + 1 : 0;
    const limit = Math.min(Number(url.searchParams.get('limit')), pageSize);
    const data = rows.slice(start, start + limit);
    reply(200, { object: 'list', data, has_more: start + limit < rows.length });
  });
  const state = { subscriptions, charges, validKey };
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  return {
    state,
    requests,
    apiBase: `http://127.0.0.1:${server.address().port}`,
    close: () => new Promise((resolve) => server.close(resolve)),
  };
}

export function sub(id, items, extra = {}) {
  return {
    id,
    currency: 'usd',
    items: {
      data: items.map(([amount, interval, quantity = 1, intervalCount = 1, currency = 'usd']) => ({
        quantity,
        price: { unit_amount: amount, currency, recurring: { interval, interval_count: intervalCount } },
      })),
    },
    ...extra,
  };
}

export function charge(id, amount, extra = {}) {
  return { id, amount, amount_refunded: 0, currency: 'usd', status: 'succeeded', paid: true, ...extra };
}
