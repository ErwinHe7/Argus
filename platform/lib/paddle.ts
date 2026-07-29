import 'server-only';

import { isIP } from 'node:net';

import {
  Environment,
  Paddle,
  type CountryCode,
  type Subscription,
  type Transaction,
} from '@paddle/paddle-node-sdk';
import {
  getConfiguredPaddlePriceIds,
  getPaddlePriceId,
  getPaddleProductId,
  PADDLE_TIERS,
  type PaddleBillingCadence,
  type PaddleTierDefinition,
} from './paddle-catalog';
import { currentPaddleCatalogPricesAreComplete } from './paddle-catalog-readiness';

export { getConfiguredPaddlePriceIds } from './paddle-catalog';

export type PaddleRuntimeEnvironment = 'sandbox' | 'live';

let paddleInstance: Paddle | null = null;
let paddleInstanceFingerprint: string | null = null;

export class PaddleCheckoutTransactionUnavailableError extends Error {
  constructor(readonly transactionId: string) {
    super(`Paddle transaction ${transactionId} is canceled and cannot be reused.`);
    this.name = 'PaddleCheckoutTransactionUnavailableError';
  }
}

export class PaddleCheckoutTransactionProcessingError extends Error {
  constructor(readonly transactionId: string) {
    super(`Paddle transaction ${transactionId} is already being processed.`);
    this.name = 'PaddleCheckoutTransactionProcessingError';
  }
}

export class PaddleCheckoutTransactionSelectionLockedError extends Error {
  constructor(readonly transactionId: string) {
    super(`Paddle transaction ${transactionId} is locked to an earlier checkout selection.`);
    this.name = 'PaddleCheckoutTransactionSelectionLockedError';
  }
}

function configuredApiKey(): string | null {
  return process.env.PADDLE_API_KEY?.trim() || null;
}

export function getPaddleEnvironment(): PaddleRuntimeEnvironment {
  const value = process.env.PADDLE_ENVIRONMENT?.trim().toLowerCase();
  if (value !== 'sandbox' && value !== 'live') {
    throw new Error('PADDLE_ENVIRONMENT must be explicitly set to "sandbox" or "live".');
  }
  if (
    value === 'live' &&
    (process.env.PADDLE_ALLOW_SANDBOX_ACCESS === 'true' ||
      process.env.PAYMENTS_ALLOW_TEST_ACCESS === 'true')
  ) {
    throw new Error('Live Paddle cannot run while Sandbox billing access is enabled.');
  }
  return value;
}

export function isPaddleSandbox(): boolean {
  return getPaddleEnvironment() === 'sandbox';
}

function apiKeyMatchesEnvironment(key: string, environment = getPaddleEnvironment()): boolean {
  return environment === 'sandbox'
    ? key.startsWith('pdl_sdbx_apikey_')
    : key.startsWith('pdl_live_apikey_');
}

export function getPaddleClientToken(): string | null {
  const token =
    process.env.PADDLE_CLIENT_TOKEN?.trim() ||
    process.env.NEXT_PUBLIC_PADDLE_CLIENT_TOKEN?.trim();
  if (!token) return null;
  const environment = getPaddleEnvironment();
  const valid = environment === 'sandbox' ? token.startsWith('test_') : token.startsWith('live_');
  if (!valid) {
    throw new Error('NEXT_PUBLIC_PADDLE_CLIENT_TOKEN does not match PADDLE_ENVIRONMENT.');
  }
  return token;
}

export function getPaddleBrowserConfig(): {
  clientToken: string;
  environment: 'sandbox' | 'production';
} {
  const environment = getPaddleEnvironment();
  const clientToken = getPaddleClientToken();
  if (!clientToken) throw new Error('NEXT_PUBLIC_PADDLE_CLIENT_TOKEN is not configured.');
  return {
    clientToken,
    environment: environment === 'sandbox' ? 'sandbox' : 'production',
  };
}

export function isPaddleConfigured(): boolean {
  const key = configuredApiKey();
  return Boolean(key && apiKeyMatchesEnvironment(key));
}

export function isPaddleCheckoutConfigured(
  tier: PaddleTierDefinition,
  cadence: PaddleBillingCadence
): boolean {
  try {
    return Boolean(
      isPaddleConfigured() &&
        getPaddleClientToken() &&
        paddleWebhookSecret() &&
        getPaddleProductId(tier) &&
        getPaddlePriceId(tier, cadence)
    );
  } catch {
    return false;
  }
}

export function getPaddle(): Paddle {
  const environment = getPaddleEnvironment();
  const key = configuredApiKey();
  if (!key) throw new Error('PADDLE_API_KEY is not configured.');
  if (!apiKeyMatchesEnvironment(key, environment)) {
    throw new Error('PADDLE_API_KEY does not match PADDLE_ENVIRONMENT.');
  }

  const fingerprint = `${environment}:${key}`;
  if (!paddleInstance || paddleInstanceFingerprint !== fingerprint) {
    paddleInstance = new Paddle(key, {
      environment: environment === 'sandbox' ? Environment.sandbox : Environment.production,
    });
    paddleInstanceFingerprint = fingerprint;
  }
  return paddleInstance;
}

export async function validateConfiguredPaddlePrice(
  tier: PaddleTierDefinition,
  cadence: PaddleBillingCadence
): Promise<string> {
  const priceId = getPaddlePriceId(tier, cadence);
  const productId = getPaddleProductId(tier);
  const price = await getPaddle().prices.get(priceId);
  const billingCycleMatches =
    tier.billingMode === 'one_time'
      ? price.billingCycle == null
      : price.billingCycle?.interval === tier.cadence && price.billingCycle.frequency === 1;
  const hasNoTrial = price.trialPeriod == null;
  const hasNoCountryPriceOverrides = (price.unitPriceOverrides?.length ?? 0) === 0;

  if (
    price.id !== priceId ||
    price.productId !== productId ||
    price.status !== 'active' ||
    !billingCycleMatches ||
    !hasNoTrial ||
    price.unitPrice.currencyCode !== 'USD' ||
    price.unitPrice.amount !== String(tier.baseUnitAmount) ||
    !hasNoCountryPriceOverrides
  ) {
    throw new Error(
      `Paddle price ${priceId} does not match the published ${tier.key}/${cadence} catalog.`
    );
  }
  return priceId;
}

function validBaseUrl(value: string): URL {
  const parsed = new URL(value);
  const localHttp =
    parsed.protocol === 'http:' &&
    (parsed.hostname === 'localhost' || parsed.hostname === '127.0.0.1');
  if (parsed.protocol !== 'https:' && !localHttp) {
    throw new Error('Paddle Checkout requires an HTTPS site URL.');
  }
  if (getPaddleEnvironment() === 'live' && parsed.protocol !== 'https:') {
    throw new Error('Live Paddle Checkout cannot use a localhost or HTTP URL.');
  }
  return parsed;
}

export async function resolvePaddleCheckoutCountryFromIp(input: {
  tier: PaddleTierDefinition;
  cadence: PaddleBillingCadence;
  customerIpAddress: string;
}): Promise<string> {
  if (isIP(input.customerIpAddress) === 0) {
    throw new Error('Vercel did not provide a valid customer IP address.');
  }
  const priceId = getPaddlePriceId(input.tier, input.cadence);
  const preview = await getPaddle().transactions.preview({
    items: [{ priceId, quantity: 1 }],
    customerIpAddress: input.customerIpAddress,
  });
  const countryCode = preview.address?.countryCode;
  if (!countryCode || !/^[A-Z]{2}$/.test(countryCode)) {
    throw new Error('Paddle could not resolve a checkout country from the visitor IP.');
  }
  return countryCode;
}

export async function createPaddleTransactionCheckout(input: {
  tier: PaddleTierDefinition;
  cadence: PaddleBillingCadence;
  user: { id: string; email: string | null; name: string };
  baseUrl: string;
  countryCode: string;
  customerId: string;
  attemptToken: string;
  existingTransactionId?: string | null;
}): Promise<string> {
  const priceId = await validateConfiguredPaddlePrice(input.tier, input.cadence);
  const checkoutPage = new URL('/checkout/paddle', validBaseUrl(input.baseUrl));
  if (!/^[A-Z]{2}$/.test(input.countryCode)) {
    throw new Error('A valid Paddle checkout country is required.');
  }
  if (!/^ctm_[a-z0-9]{26}$/.test(input.customerId)) {
    throw new Error('Invalid Paddle checkout customer ID.');
  }
  if (input.attemptToken.length < 16 || input.attemptToken.length > 128) {
    throw new Error('Invalid Paddle checkout attempt token.');
  }

  const items = [{ priceId, quantity: 1 }];
  const preview = await getPaddle().transactions.preview({
    items,
    customerId: input.customerId,
    address: { countryCode: input.countryCode as CountryCode },
  });
  if (preview.address && preview.address.countryCode !== input.countryCode) {
    throw new Error('Paddle transaction preview country does not match the visitor country.');
  }
  const transactionBody = {
    items,
    customerId: input.customerId,
    currencyCode: preview.currencyCode,
    collectionMode: 'automatic' as const,
    customData: {
      axio7_user_id: input.user.id,
      axio7_plan: input.tier.key,
      axio7_cadence: input.cadence,
      axio7_price_id: priceId,
      axio7_checkout_country: input.countryCode,
      axio7_checkout_attempt: input.attemptToken,
    },
    checkout: { url: checkoutPage.toString() },
  };
  let transaction: Transaction;
  if (input.existingTransactionId) {
    const existing = await retrievePaddleTransaction(input.existingTransactionId);
    if (paddleCustomUserId(existing.customData) !== input.user.id) {
      throw new Error('Paddle checkout transaction belongs to another AXIO7 user.');
    }
    if (paddleCustomValue(existing.customData, 'axio7_checkout_attempt') !== input.attemptToken) {
      throw new Error('Paddle checkout transaction does not match its durable attempt token.');
    }
    if (existing.status === 'canceled') {
      throw new PaddleCheckoutTransactionUnavailableError(existing.id);
    }
    if (['billed', 'paid', 'completed'].includes(existing.status)) {
      throw new PaddleCheckoutTransactionProcessingError(existing.id);
    }
    const selectionMatches =
      paddleCustomValue(existing.customData, 'axio7_plan') === input.tier.key &&
      paddleCustomValue(existing.customData, 'axio7_cadence') === input.cadence &&
      paddleCustomValue(existing.customData, 'axio7_price_id') === priceId &&
      paddleCustomValue(existing.customData, 'axio7_checkout_country') === input.countryCode &&
      existing.customerId === input.customerId &&
      existing.addressId == null &&
      existing.currencyCode === preview.currencyCode &&
      existing.items.length === 1 &&
      existing.items[0]?.price?.id === priceId;
    if (!selectionMatches) {
      // Never mutate a transaction that another tab may already have open.
      // This makes the shown price and the eventual subscription immutable.
      throw new PaddleCheckoutTransactionSelectionLockedError(existing.id);
    }
    // Draft is the expected state until Paddle Checkout collects the
    // customer's address. Paddle sets ready automatically once the required
    // billing fields exist; the API only permits callers to set billed or
    // canceled. Reuse draft, ready, and past-due transactions unchanged so a
    // retry cannot create a duplicate subscription.
    transaction = existing;
  } else {
    transaction = await getPaddle().transactions.create(transactionBody);
  }

  if (!/^txn_[a-z0-9]{26}$/.test(transaction.id)) {
    throw new Error('Paddle did not return a checkout-ready transaction.');
  }
  const previewSubtotal = preview.details.lineItems.find(
    (lineItem) => lineItem.priceId === priceId
  )?.totals.subtotal;
  const transactionSubtotal = transaction.details?.lineItems.find(
    (lineItem) => lineItem.priceId === priceId
  )?.totals?.subtotal;
  if (
    transaction.customerId !== input.customerId ||
    transaction.addressId != null ||
    transaction.currencyCode !== preview.currencyCode ||
    !transaction.items.some((item) => item.price?.id === priceId) ||
    !previewSubtotal ||
    (transactionSubtotal != null && transactionSubtotal !== previewSubtotal)
  ) {
    throw new Error('Paddle checkout transaction does not match its localized preview.');
  }
  return transaction.id;
}

export async function retrievePaddleSubscription(subscriptionId: string): Promise<Subscription> {
  if (!/^sub_[a-z0-9]{26}$/.test(subscriptionId)) {
    throw new Error('Invalid Paddle subscription ID.');
  }
  return getPaddle().subscriptions.get(subscriptionId);
}

export async function cancelPaddleFreeSubscriptionForUpgrade(input: {
  subscriptionId: string;
  customerId: string;
  freePriceId: string;
}): Promise<Subscription> {
  if (!/^ctm_[a-z0-9]{26}$/.test(input.customerId)) {
    throw new Error('Invalid Paddle customer ID.');
  }
  if (!/^pri_[a-z0-9]{26}$/.test(input.freePriceId)) {
    throw new Error('Invalid Paddle Free price ID.');
  }
  const current = await retrievePaddleSubscription(input.subscriptionId);
  const priceIds = current.items
    .map((item) => item.price?.id)
    .filter((priceId): priceId is string => Boolean(priceId));
  if (
    current.customerId !== input.customerId ||
    !['active', 'trialing'].includes(current.status) ||
    priceIds.length !== 1 ||
    priceIds[0] !== input.freePriceId
  ) {
    throw new Error('Only the authenticated active Free subscription may be replaced.');
  }

  const canceled = await getPaddle().subscriptions.cancel(input.subscriptionId, {
    effectiveFrom: 'immediately',
  });
  if (
    canceled.id !== input.subscriptionId ||
    canceled.customerId !== input.customerId ||
    canceled.status !== 'canceled'
  ) {
    throw new Error('Paddle did not confirm the Free subscription replacement.');
  }
  return canceled;
}
export async function cancelPaddleSubscriptionAtPeriodEnd(
  subscriptionId: string
): Promise<Subscription> {
  if (!/^sub_[a-z0-9]{26}$/.test(subscriptionId)) {
    throw new Error('Invalid Paddle subscription ID.');
  }
  const subscription = await getPaddle().subscriptions.cancel(subscriptionId, {
    effectiveFrom: 'next_billing_period',
  });
  if (
    subscription.id !== subscriptionId ||
    !['active', 'trialing'].includes(subscription.status) ||
    subscription.scheduledChange?.action !== 'cancel' ||
    !subscription.scheduledChange.effectiveAt
  ) {
    throw new Error('Paddle did not confirm an end-of-period cancellation.');
  }
  return subscription;
}

export async function retrievePaddleTransaction(transactionId: string): Promise<Transaction> {
  if (!/^txn_[a-z0-9]{26}$/.test(transactionId)) {
    throw new Error('Invalid Paddle transaction ID.');
  }
  return getPaddle().transactions.get(transactionId);
}

export async function cancelPaddleCheckoutTransactionForUser(input: {
  transactionId: string;
  userId: string;
  attemptToken: string;
}): Promise<void> {
  const transaction = await retrievePaddleTransaction(input.transactionId);
  if (paddleCustomUserId(transaction.customData) !== input.userId) {
    throw new Error('Paddle checkout transaction belongs to another AXIO7 user.');
  }
  if (paddleCustomValue(transaction.customData, 'axio7_checkout_attempt') !== input.attemptToken) {
    throw new Error('Paddle checkout transaction does not match its durable attempt token.');
  }
  if (transaction.status === 'canceled') return;
  if (!['draft', 'ready'].includes(transaction.status)) {
    // Checkout explicitly closed before completion may still be draft while
    // Paddle waits for required billing fields. Paid, billed, completed, or
    // past-due state remains webhook-authoritative and is never canceled here.
    throw new PaddleCheckoutTransactionProcessingError(transaction.id);
  }

  const canceled = await getPaddle().transactions.update(transaction.id, {
    status: 'canceled',
  });
  if (canceled.status !== 'canceled') {
    throw new Error('Paddle did not confirm checkout transaction cancellation.');
  }
}

export async function cancelRetiredPaddleCheckoutTransactionForUser(input: {
  transactionId: string;
  userId: string;
  attemptToken: string;
  retiredPriceId: string;
}): Promise<void> {
  const transaction = await retrievePaddleTransaction(input.transactionId);
  if (paddleCustomUserId(transaction.customData) !== input.userId) {
    throw new Error('Paddle checkout transaction belongs to another AXIO7 user.');
  }
  if (paddleCustomValue(transaction.customData, 'axio7_checkout_attempt') !== input.attemptToken) {
    throw new Error('Paddle checkout transaction does not match its durable attempt token.');
  }
  if (
    transaction.items.length !== 1 ||
    transaction.items[0]?.price?.id !== input.retiredPriceId
  ) {
    throw new Error('Paddle checkout transaction does not match the retired price.');
  }
  if (transaction.status === 'canceled') return;
  if (!['draft', 'ready'].includes(transaction.status)) {
    // A retired catalog selection can be replaced only before Paddle begins
    // collecting money. Paid, billed, completed, or past-due state remains
    // webhook-authoritative and is never mutated by catalog migration.
    throw new PaddleCheckoutTransactionProcessingError(transaction.id);
  }

  const canceled = await getPaddle().transactions.update(transaction.id, {
    status: 'canceled',
  });
  if (canceled.status !== 'canceled') {
    throw new Error('Paddle did not confirm retired checkout transaction cancellation.');
  }
}

export async function createPaddleCustomerPortalUrl(input: {
  customerId: string;
  subscriptionId: string;
}): Promise<string> {
  if (!/^ctm_[a-z0-9]{26}$/.test(input.customerId)) {
    throw new Error('Invalid Paddle customer ID.');
  }
  if (!/^sub_[a-z0-9]{26}$/.test(input.subscriptionId)) {
    throw new Error('Invalid Paddle subscription ID.');
  }

  const session = await getPaddle().customerPortalSessions.create(input.customerId, [
    input.subscriptionId,
  ]);
  const portalUrl = new URL(session.urls.general.overview);
  if (portalUrl.protocol !== 'https:') {
    throw new Error('Paddle returned an unsafe customer portal URL.');
  }
  return portalUrl.toString();
}

export function paddleCustomUserId(customData: unknown): string | null {
  return paddleCustomValue(customData, 'axio7_user_id');
}

export function paddleCustomValue(customData: unknown, key: string): string | null {
  if (!customData || typeof customData !== 'object') return null;
  const value = (customData as Record<string, unknown>)[key];
  if (typeof value !== 'string') return null;
  const normalized = value.trim();
  if (!normalized || normalized.length > 128 || /[\u0000-\u001f]/.test(normalized)) return null;
  return normalized;
}

export function paddleWebhookSecret(): string | null {
  return process.env.PADDLE_NOTIFICATION_WEBHOOK_SECRET?.trim() || null;
}

export function configuredPaddlePricesAreComplete(): boolean {
  return currentPaddleCatalogPricesAreComplete(PADDLE_TIERS, process.env);
}
