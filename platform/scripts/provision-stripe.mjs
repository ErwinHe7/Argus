import { spawnSync } from 'node:child_process';
import Stripe from 'stripe';

const secretKey = process.env.STRIPE_SECRET_KEY?.trim();
const publishableKey =
  process.env.STRIPE_PUBLISHABLE_KEY?.trim() ||
  process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY?.trim();
const vercelEnvironment = process.env.VERCEL_ENVIRONMENT?.trim() || 'production';

if (!secretKey || !/^[sr]k_(test|live)_/.test(secretKey)) {
  throw new Error('STRIPE_SECRET_KEY must be a valid secret or restricted Stripe key.');
}
if (!publishableKey || !/^pk_(test|live)_/.test(publishableKey)) {
  throw new Error('STRIPE_PUBLISHABLE_KEY must be a valid test or live publishable key.');
}

const mode = secretKey.includes('_live_') ? 'live' : 'test';
if (!publishableKey.startsWith(`pk_${mode}_`)) {
  throw new Error('The Stripe publishable and secret keys must use the same mode.');
}

const stripe = new Stripe(secretKey, {
  apiVersion: '2026-06-24.dahlia',
  appInfo: { name: 'AXIO7', version: '1.0.0', url: 'https://axio7.com' },
});

const account = await stripe.accounts.retrieve();
if (
  mode === 'live' &&
  (!account.details_submitted || !account.charges_enabled || !account.payouts_enabled)
) {
  throw new Error(
    'Stripe live account is not ready: finish business verification and enable charges/payouts before deployment.'
  );
}

const plans = [
  {
    key: 'starter',
    name: 'AXIO7 Starter',
    description: 'Core educational lessons, source-reading exercises, and review notes for one learner.',
    amount: 5_990,
    env: 'STRIPE_PRICE_STARTER',
  },
  {
    key: 'pro',
    name: 'AXIO7 Pro',
    description: 'Guided learning workspaces, historical case reviews, and source-comparison exercises.',
    amount: 15_990,
    env: 'STRIPE_PRICE_PRO',
  },
  {
    key: 'premium',
    name: 'AXIO7 Premium',
    description: 'The complete AXIO7 learning library with advanced source-reading and review modules.',
    amount: 29_990,
    env: 'STRIPE_PRICE_PREMIUM',
  },
  {
    key: 'enterprise',
    name: 'AXIO7 Enterprise',
    description: 'Team-scale learning access, priority onboarding, and invoicing.',
    amount: 299_990,
    env: 'STRIPE_PRICE_ENTERPRISE',
  },
];

function setVercelEnvironmentVariable(name, value, sensitive) {
  const vercelScript = 'C:\\Users\\hegua\\AppData\\Roaming\\npm\\vercel.ps1';
  const sensitivity = sensitive ? '--sensitive' : '--no-sensitive';
  const command = `& '${vercelScript}' env add ${name} ${vercelEnvironment} --force --yes ${sensitivity}`;
  const result = spawnSync(
    'powershell.exe',
    ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', command],
    { cwd: process.cwd(), input: `${value}\n`, encoding: 'utf8' }
  );

  if (result.status !== 0) {
    throw new Error(`Unable to set Vercel variable ${name}: ${result.stderr || result.stdout}`);
  }
}

const existingProducts = await stripe.products.list({ limit: 100, active: true });
const configuredPlans = [];

for (const plan of plans) {
  let product = existingProducts.data.find(
    (item) => item.metadata?.axio7_plan === plan.key && item.metadata?.axio7_environment === mode
  );

  if (!product) {
    product = await stripe.products.create({
      name: plan.name,
      description: plan.description,
      url: 'https://axio7.com/pricing',
      metadata: { axio7_plan: plan.key, axio7_environment: mode },
    });
  } else if (product.name !== plan.name || product.description !== plan.description) {
    product = await stripe.products.update(product.id, {
      name: plan.name,
      description: plan.description,
      url: 'https://axio7.com/pricing',
    });
  }

  const prices = await stripe.prices.list({ product: product.id, active: true, limit: 100 });
  let price = prices.data.find(
    (item) =>
      item.currency === 'usd' &&
      item.unit_amount === plan.amount &&
      item.recurring?.interval === 'month'
  );

  if (!price) {
    price = await stripe.prices.create({
      product: product.id,
      unit_amount: plan.amount,
      currency: 'usd',
      recurring: { interval: 'month' },
      lookup_key: `axio7_${plan.key}_monthly`,
      metadata: { axio7_plan: plan.key, axio7_environment: mode },
    });
  }

  configuredPlans.push({ ...plan, productId: product.id, priceId: price.id });
}

const webhookUrl = 'https://axio7.com/api/stripe/webhook';
const webhookDescription = `AXIO7 ${mode} billing webhook managed by provision-stripe`;
const webhookEndpoints = await stripe.webhookEndpoints.list({ limit: 100 });
const priorManagedEndpoints = webhookEndpoints.data.filter(
  (endpoint) => endpoint.url === webhookUrl && endpoint.description === webhookDescription
);

// Stripe only reveals a webhook signing secret once. Replace only endpoints
// created by this script so reruns can safely refresh the Vercel secret.
for (const endpoint of priorManagedEndpoints) {
  await stripe.webhookEndpoints.del(endpoint.id);
}

const webhook = await stripe.webhookEndpoints.create({
  url: webhookUrl,
  description: webhookDescription,
  enabled_events: [
    'checkout.session.completed',
    'checkout.session.async_payment_succeeded',
    'checkout.session.async_payment_failed',
    'customer.subscription.created',
    'customer.subscription.updated',
    'customer.subscription.deleted',
    'invoice.paid',
    'invoice.payment_failed',
    'invoice.finalization_failed',
    'charge.refunded',
  ],
});

const portalParams = {
  name: `AXIO7 ${mode} customer portal`,
  default_return_url: 'https://axio7.com/billing',
  business_profile: {
    headline: 'Manage your AXIO7 subscription and invoices',
    privacy_policy_url: 'https://axio7.com/privacy',
    terms_of_service_url: 'https://axio7.com/terms',
  },
  features: {
    customer_update: { enabled: true, allowed_updates: ['address', 'email', 'name'] },
    invoice_history: { enabled: true },
    payment_method_update: { enabled: true },
    subscription_cancel: {
      enabled: true,
      mode: 'at_period_end',
      cancellation_reason: {
        enabled: true,
        options: ['too_expensive', 'missing_features', 'unused', 'other'],
      },
    },
  },
  metadata: { axio7_environment: mode, axio7_managed: 'true' },
};

const portalConfigurations = await stripe.billingPortal.configurations.list({ limit: 100 });
const existingPortal = portalConfigurations.data.find(
  (configuration) =>
    configuration.metadata?.axio7_environment === mode &&
    configuration.metadata?.axio7_managed === 'true'
);
const portalConfiguration = existingPortal
  ? await stripe.billingPortal.configurations.update(existingPortal.id, portalParams)
  : await stripe.billingPortal.configurations.create(portalParams);

setVercelEnvironmentVariable('STRIPE_SECRET_KEY', secretKey, true);
setVercelEnvironmentVariable('STRIPE_WEBHOOK_SECRET', webhook.secret, true);
setVercelEnvironmentVariable('STRIPE_PORTAL_CONFIGURATION_ID', portalConfiguration.id, false);
setVercelEnvironmentVariable('NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY', publishableKey, false);
setVercelEnvironmentVariable('STRIPE_ALLOW_SANDBOX_ACCESS', 'false', false);
for (const plan of configuredPlans) {
  setVercelEnvironmentVariable(plan.env, plan.priceId, false);
}

const deploySetting = process.env.VERCEL_DEPLOY_AFTER_PROVISION?.trim();
const shouldDeploy = deploySetting === 'true' || (mode === 'live' && deploySetting !== 'false');
let deploymentTriggered = false;
if (shouldDeploy) {
  const vercelScript = 'C:\\Users\\hegua\\AppData\\Roaming\\npm\\vercel.ps1';
  const deploy = spawnSync(
    'powershell.exe',
    ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', "& '" + vercelScript + "' --prod --yes"],
    { cwd: process.cwd(), encoding: 'utf8' }
  );
  if (deploy.status !== 0) {
    throw new Error('Stripe was provisioned, but Vercel deployment failed: ' + (deploy.stderr || deploy.stdout));
  }
  deploymentTriggered = true;
}

console.log(
  JSON.stringify(
    {
      mode,
      account: {
        id: account.id,
        detailsSubmitted: account.details_submitted,
        chargesEnabled: account.charges_enabled,
        payoutsEnabled: account.payouts_enabled,
      },
      deploymentTriggered,
      products: configuredPlans.map(({ key, name, amount, productId, priceId }) => ({
        key,
        name,
        amount,
        productId,
        priceId,
      })),
      webhook: { id: webhook.id, url: webhook.url, status: webhook.status },
      customerPortal: { id: portalConfiguration.id, active: portalConfiguration.active },
      vercelEnvironment,
    },
    null,
    2
  )
);
