# Proofboard

A public leaderboard of startup revenue verified directly from Stripe, modeled on
the TrustMRR business model: founders connect a read-only Stripe key and get a
ranked profile plus a backlink, and the site earns money from sponsor slots.

Zero dependencies: Node 22.13+ (`node:http`, `node:sqlite`, `fetch`).

## How verification works

- Founders paste a **restricted** key (`rk_live_…`) with *Read* access to
  Subscriptions and Charges. Full secret keys (`sk_…`) and test-mode keys are rejected.
- **MRR** = active subscriptions, each item's `unit_amount × quantity` normalized
  to a month, minus subscription-level percent coupons.
- **Last 30 days** = succeeded charges created in the last 30 days, minus refunds.
- Keys are encrypted at rest (AES-256-GCM, keyed by `APP_SECRET`) and used to
  refresh every startup hourly. A startup that hasn't verified in 48 hours (e.g. the
  founder revoked the key) is hidden from the leaderboard.

Fails closed rather than guessing: non-USD revenue, tiered/metered prices, and
accounts with more than 5,000 subscriptions or charges per 30 days are rejected
with an explanation.

Known limits: verification proves the revenue belongs to *a* Stripe account the
submitter controls, not that it belongs to the listed website. Amount-off coupons are
not subtracted from MRR.

## Run locally

```sh
APP_SECRET=$(openssl rand -hex 32) ALLOW_TEST_KEYS=1 npm start   # http://localhost:3000
npm test
```

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `APP_SECRET` | — (required) | ≥32 chars; encrypts stored Stripe keys. The server refuses to start without it. |
| `PORT` | `3000` | HTTP port |
| `DATABASE_PATH` | `data/proofboard.db` | SQLite file; must sit on a persistent volume |
| `SPONSOR_CHECKOUT_URL` | — | Stripe Payment Link for the "Your product here" slot |
| `SPONSORS_FILE` | `sponsors.json` | Paid sponsors shown in the rail (see `sponsors.example.json`) |
| `TRUST_PROXY` | `0` (`1` in Docker) | Use `X-Forwarded-For` for rate limiting behind a proxy |
| `REFRESH_MINUTES` / `STALE_AFTER_HOURS` | `60` / `48` | Refresh cadence and leaderboard cutoff |
| `ALLOW_TEST_KEYS` | `0` | Accept `rk_test_` keys (local development only) |

## Deploy

Any host that runs a container with a persistent volume works. Example with Fly.io:

```sh
fly launch --no-deploy --name proofboard
fly volumes create data --size 1
# add to fly.toml:  [mounts] source = "data"  destination = "/data"
fly secrets set APP_SECRET=$(openssl rand -hex 32) SPONSOR_CHECKOUT_URL=https://buy.stripe.com/...
fly deploy
```

Run a single instance: the SQLite file and the in-process hourly refresh assume one machine.
