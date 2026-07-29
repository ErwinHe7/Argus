import { Environment, Paddle } from '@paddle/paddle-node-sdk';

const apiKey = process.env.PADDLE_API_KEY?.trim();
const siteUrl = process.env.NEXT_PUBLIC_SITE_URL?.trim();
if (process.env.PADDLE_ENVIRONMENT?.trim().toLowerCase() !== 'live') {
  throw new Error('This command only provisions the explicitly configured Paddle live account.');
}
if (!apiKey?.startsWith('pdl_live_apikey_')) {
  throw new Error('PADDLE_API_KEY must be a live Paddle API key.');
}
if (process.env.PADDLE_LIVE_INFRA_CONFIRM !== 'CREATE_AXIO7_LIVE_INFRA') {
  throw new Error('Set PADDLE_LIVE_INFRA_CONFIRM=CREATE_AXIO7_LIVE_INFRA to continue.');
}
if (!siteUrl) throw new Error('NEXT_PUBLIC_SITE_URL is required.');

const publicSite = new URL(siteUrl);
if (publicSite.protocol !== 'https:' || ['localhost', '127.0.0.1'].includes(publicSite.hostname)) {
  throw new Error('Live Paddle infrastructure requires a real HTTPS site URL.');
}

const paddle = new Paddle(apiKey, { environment: Environment.production });
const tokenName = 'AXIO7 live pricing page';
const configuredClientToken = process.env.NEXT_PUBLIC_PADDLE_CLIENT_TOKEN?.trim();
const destinationUrl = new URL('/api/paddle/webhook', publicSite).toString();
const destinationDescription = 'Axio7 Production Webhook';
const subscribedEvents = [
  'adjustment.created',
  'adjustment.updated',
  'subscription.created',
  'subscription.activated',
  'subscription.updated',
  'subscription.trialing',
  'subscription.past_due',
  'subscription.paused',
  'subscription.resumed',
  'subscription.canceled',
  'customer.created',
  'customer.updated',
  'transaction.completed',
];

async function listAll(collection) {
  const values = [];
  for await (const value of collection) values.push(value);
  return values;
}

const tokens = await listAll(paddle.clientTokens.list({ perPage: 200 }));
let clientToken = configuredClientToken
  ? tokens.find(
      (candidate) =>
        candidate.token === configuredClientToken && candidate.status === 'active'
    )
  : tokens.find((candidate) => candidate.name === tokenName && candidate.status === 'active');
if (configuredClientToken && !clientToken) {
  throw new Error(
    'NEXT_PUBLIC_PADDLE_CLIENT_TOKEN is not an active token in the configured Paddle live account.'
  );
}
if (!clientToken) {
  clientToken = await paddle.clientTokens.create({
    name: tokenName,
    description: 'Paddle.js token for USD pricing and checkout on axio7.com',
  });
}

const destinations = await paddle.notificationSettings.list({ active: true, perPage: 200 });
let destination = destinations.find(
  (candidate) => candidate.type === 'url' && candidate.destination === destinationUrl
);
if (destination) {
  destination = await paddle.notificationSettings.update(destination.id, {
    description: destinationDescription,
    destination: destinationUrl,
    active: true,
    subscribedEvents,
    trafficSource: 'platform',
    includeSensitiveFields: false,
  });
} else {
  destination = await paddle.notificationSettings.create({
    description: destinationDescription,
    type: 'url',
    destination: destinationUrl,
    subscribedEvents,
    trafficSource: 'platform',
    includeSensitiveFields: false,
  });
}

process.stdout.write(`NEXT_PUBLIC_PADDLE_CLIENT_TOKEN=${clientToken.token}\n`);
process.stdout.write(`PADDLE_NOTIFICATION_SETTING_ID=${destination.id}\n`);
process.stdout.write(`PADDLE_NOTIFICATION_WEBHOOK_SECRET=${destination.endpointSecretKey}\n`);
process.stdout.write(`PADDLE_NOTIFICATION_DESTINATION=${destination.destination}\n`);
