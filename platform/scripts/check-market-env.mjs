#!/usr/bin/env node
// Print which market-intelligence providers are wired up vs missing.
// Use locally or in CI as: node scripts/check-market-env.mjs

const groups = [
  {
    name: 'Required core',
    rows: [
      ['NEXT_PUBLIC_SUPABASE_URL', true],
      ['SUPABASE_SERVICE_ROLE_KEY', true],
      ['OPENAI_API_KEY', false],
      ['OPENAI_BASE_URL', false],
    ],
  },
  {
    name: 'Market data',
    rows: [
      ['SEC_USER_AGENT', false],
      ['FINNHUB_API_KEY', false],
      ['LSEG_CLIENT_ID', false],
      ['LSEG_CLIENT_SECRET', false],
      ['NEWSAPI_KEY', false],
      ['OPTIONS_FLOW_API_KEY', false],
      ['IBKR_BASE_URL', false],
      ['IBKR_MARKET_DATA_ENABLED', false],
      ['IBKR_ACCOUNT_ID', false],
      ['IBKR_SESSION_TOKEN', false],
      ['IBKR_ALLOW_INSECURE_TLS', false],
    ],
  },
  {
    name: 'Social authorized',
    rows: [
      ['X_BEARER_TOKEN', false],
      ['TRUTH_SOCIAL_PROVIDER_URL', false],
      ['TRUTH_SOCIAL_PROVIDER_KEY', false],
      ['INFLUENCER_ELON_X', false],
      ['INFLUENCER_SERENITY_X', false],
      ['INFLUENCER_BREAD_X', false],
      ['INFLUENCER_LABUBU_X', false],
    ],
  },
  {
    name: 'Ops',
    rows: [
      ['REDIS_URL', false],
      ['MARKET_CRON_SECRET', false],
      ['CRON_SECRET', false],
      ['BROKER_LIVE_ENABLED', false],
      ['PAPER_BROKER_STARTING_CASH', false],
    ],
  },
];

let missingRequired = false;
for (const group of groups) {
  console.log(`\n[${group.name}]`);
  for (const [key, required] of group.rows) {
    const v = process.env[key];
    const ok = Boolean(v && v.length);
    const mark = ok ? 'OK' : required ? 'MISSING' : 'unset';
    console.log(`  ${mark.padEnd(8)} ${key}`);
    if (required && !ok) missingRequired = true;
  }
}

if (missingRequired) {
  console.log('\nRequired env vars missing. Build will likely fail at runtime.');
  process.exit(1);
}
console.log('\nRequired env vars present. Optional providers will degrade gracefully.');
