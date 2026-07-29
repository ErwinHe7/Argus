import 'server-only';

import type {
  CustomerNotification,
  Subscription,
  SubscriptionCreatedNotification,
  SubscriptionNotification,
  Transaction,
  TransactionNotification,
} from '@paddle/paddle-node-sdk';
import {
  applyPaddleBillingAccount,
  applyPaddleLifetimeBillingAccount,
  completePaddleCheckoutAttempt,
  getProviderBillingAccount,
  getProviderBillingAccountByCustomer,
  getProviderBillingAccountBySubscription,
  upsertProviderBillingAccount,
  type ProviderBillingAccount,
  type ProviderBillingAccountUpsert,
} from './billing';
import { getPaddleTierForPriceId } from './paddle-catalog';
import {
  getConfiguredPaddlePriceIds,
  isPaddleSandbox,
  paddleCustomUserId,
  retrievePaddleSubscription,
} from './paddle';
import { isSupabaseConfigured, supabaseAdmin } from './supabase';
import { recordBillingUsageEventBestEffort } from './refund-requests';

const PROVIDER = 'paddle' as const;
const SUBSCRIPTION_STATUSES = new Set([
  'trialing',
  'active',
  'past_due',
  'paused',
  'canceled',
]);

type PaddleEnvironment = 'sandbox' | 'live';
type PaddleSubscriptionLike =
  | Subscription
  | SubscriptionCreatedNotification
  | SubscriptionNotification;
type PaddleTransactionLike = Transaction | TransactionNotification;

export type PaddleCatalogDisposition = 'configured' | 'unrelated' | 'invalid';

export function paddleCatalogDisposition(resource: {
  items: Array<{ price?: { id: string } | null }>;
}): PaddleCatalogDisposition {
  const configuredPriceIds = getConfiguredPaddlePriceIds();
  const configuredItems = resource.items.filter(
    (item) => item.price?.id && configuredPriceIds.has(item.price.id)
  );
  if (configuredItems.length === 0) return 'unrelated';
  return resource.items.length === 1 && configuredItems.length === 1
    ? 'configured'
    : 'invalid';
}

type NormalizedPaddleSubscription = {
  id: string;
  customerId: string;
  transactionId: string | null;
  priceId: string;
  productId: string;
  status: string;
  environment: PaddleEnvironment;
  testMode: boolean;
  currentPeriodEnd: string | null;
  scheduledChangeAction: string | null;
  scheduledChangeAt: string | null;
  cancelAtPeriodEnd: boolean;
  providerCreatedAt: string;
  sourceUpdatedAt: string;
  eventOccurredAt: string;
};

type PaddlePortalIdentity = {
  customerId: string;
  subscriptionId: string;
};

function paddleMode(): { environment: PaddleEnvironment; testMode: boolean } {
  const testMode = isPaddleSandbox();
  return { environment: testMode ? 'sandbox' : 'live', testMode };
}

function requireId(
  value: string,
  prefix: 'sub' | 'ctm' | 'txn' | 'pri' | 'pro'
): string {
  const pattern = new RegExp(`^${prefix}_[a-z0-9]{26}$`);
  if (!pattern.test(value)) throw new Error(`Invalid Paddle ${prefix} identifier.`);
  return value;
}

function isoDate(value: string | null | undefined, label: string): string | null {
  if (!value) return null;
  const parsed = Date.parse(value);
  if (!Number.isFinite(parsed)) throw new Error(`Invalid Paddle ${label} timestamp.`);
  return new Date(parsed).toISOString();
}

function requiredIsoDate(value: string | null | undefined, label: string): string {
  const normalized = isoDate(value, label);
  if (!normalized) throw new Error(`Paddle ${label} timestamp is required.`);
  return normalized;
}

function normalizedCatalogItem(
  items: PaddleSubscriptionLike['items'] | PaddleTransactionLike['items']
): { priceId: string; productId: string } {
  if (items.length !== 1 || !items[0]?.price) {
    throw new Error('Paddle resource must contain exactly one AXIO7 price.');
  }
  const priceId = requireId(items[0].price.id, 'pri');
  if (!getConfiguredPaddlePriceIds().has(priceId)) {
    throw new Error('Paddle resource does not contain a configured AXIO7 price.');
  }
  return {
    priceId,
    productId: requireId(items[0].price.productId, 'pro'),
  };
}

function validatePaddleSubscription(
  subscription: PaddleSubscriptionLike,
  transactionId?: string | null,
  eventOccurredAt?: string
): NormalizedPaddleSubscription {
  const catalog = normalizedCatalogItem(subscription.items);
  if (!SUBSCRIPTION_STATUSES.has(subscription.status)) {
    throw new Error('Unknown Paddle subscription status.');
  }
  const mode = paddleMode();
  const createdAt = requiredIsoDate(subscription.createdAt, 'subscription created');
  const updatedAt = requiredIsoDate(subscription.updatedAt, 'subscription updated');
  const createdTransactionId =
    'transactionId' in subscription ? subscription.transactionId : null;
  const resolvedTransactionId = transactionId ?? createdTransactionId;
  const scheduledChange = subscription.scheduledChange;

  return {
    id: requireId(subscription.id, 'sub'),
    customerId: requireId(subscription.customerId, 'ctm'),
    transactionId: resolvedTransactionId
      ? requireId(resolvedTransactionId, 'txn')
      : null,
    priceId: catalog.priceId,
    productId: catalog.productId,
    status: subscription.status,
    ...mode,
    currentPeriodEnd: isoDate(
      subscription.currentBillingPeriod?.endsAt ?? subscription.nextBilledAt,
      'billing-period end'
    ),
    scheduledChangeAction: scheduledChange?.action ?? null,
    scheduledChangeAt: isoDate(scheduledChange?.effectiveAt, 'scheduled-change effective'),
    cancelAtPeriodEnd:
      scheduledChange?.action === 'cancel' || subscription.status === 'canceled',
    providerCreatedAt: createdAt,
    sourceUpdatedAt: updatedAt,
    eventOccurredAt: requiredIsoDate(
      eventOccurredAt ?? subscription.updatedAt,
      'event occurred'
    ),
  };
}

function assertSameOwner(account: ProviderBillingAccount | null, userId: string): void {
  if (account && account.user_id !== userId) {
    throw new Error('Paddle resource is already bound to another AXIO7 user.');
  }
}

async function getMirrorOwner(
  environment: PaddleEnvironment,
  field: 'customer_id' | 'subscription_id' | 'transaction_id',
  value: string
): Promise<string | null> {
  if (!isSupabaseConfigured()) return null;
  const table =
    field === 'customer_id'
      ? 'paddle_customers'
      : field === 'subscription_id'
        ? 'paddle_subscriptions'
        : 'paddle_transactions';
  const { data, error } = await supabaseAdmin()
    .from(table)
    .select('user_id')
    .eq('environment', environment)
    .eq(field, value)
    .maybeSingle();
  if (error) {
    if (error.code === '42P01') return null;
    throw error;
  }
  return typeof data?.user_id === 'string' ? data.user_id : null;
}

async function applyCustomerMirror(input: {
  environment: PaddleEnvironment;
  testMode: boolean;
  customerId: string;
  userId: string | null;
  email: string;
  name: string | null;
  status: string;
  createdAt: string;
  updatedAt: string;
  eventOccurredAt: string;
}): Promise<boolean> {
  if (!isSupabaseConfigured()) {
    throw new Error('Supabase must be configured to mirror Paddle customers.');
  }
  const { data, error } = await supabaseAdmin().rpc('apply_paddle_customer', {
    p_environment: input.environment,
    p_test_mode: input.testMode,
    p_customer_id: input.customerId,
    p_user_id: input.userId,
    p_email: input.email,
    p_name: input.name,
    p_status: input.status,
    p_paddle_created_at: input.createdAt,
    p_paddle_updated_at: input.updatedAt,
    p_event_occurred_at: input.eventOccurredAt,
  });
  if (error) throw error;
  return data === true;
}

async function applySubscriptionMirror(
  normalized: NormalizedPaddleSubscription,
  userId: string
): Promise<boolean> {
  if (!isSupabaseConfigured()) {
    throw new Error('Supabase must be configured to mirror Paddle subscriptions.');
  }
  const { data, error } = await supabaseAdmin().rpc('apply_paddle_subscription', {
    p_environment: normalized.environment,
    p_test_mode: normalized.testMode,
    p_subscription_id: normalized.id,
    p_customer_id: normalized.customerId,
    p_user_id: userId,
    p_transaction_id: normalized.transactionId,
    p_status: normalized.status,
    p_price_id: normalized.priceId,
    p_product_id: normalized.productId,
    p_current_period_end: normalized.currentPeriodEnd,
    p_scheduled_change_action: normalized.scheduledChangeAction,
    p_scheduled_change_at: normalized.scheduledChangeAt,
    p_paddle_created_at: normalized.providerCreatedAt,
    p_paddle_updated_at: normalized.sourceUpdatedAt,
    p_event_occurred_at: normalized.eventOccurredAt,
  });
  if (error) throw error;
  return data === true;
}

async function applyTransactionMirror(input: {
  environment: PaddleEnvironment;
  testMode: boolean;
  transactionId: string;
  customerId: string;
  subscriptionId: string | null;
  userId: string;
  status: string;
  priceId: string;
  productId: string;
  currencyCode: string;
  total: string | null;
  createdAt: string;
  updatedAt: string;
  eventOccurredAt: string;
}): Promise<boolean> {
  if (!isSupabaseConfigured()) {
    throw new Error('Supabase must be configured to mirror Paddle transactions.');
  }
  const { data, error } = await supabaseAdmin().rpc('apply_paddle_transaction', {
    p_environment: input.environment,
    p_test_mode: input.testMode,
    p_transaction_id: input.transactionId,
    p_customer_id: input.customerId,
    p_subscription_id: input.subscriptionId,
    p_user_id: input.userId,
    p_status: input.status,
    p_price_id: input.priceId,
    p_product_id: input.productId,
    p_currency_code: input.currencyCode,
    p_total: input.total,
    p_paddle_created_at: input.createdAt,
    p_paddle_updated_at: input.updatedAt,
    p_event_occurred_at: input.eventOccurredAt,
  });
  if (error) throw error;
  return data === true;
}

export async function syncPaddleCustomer(
  customer: CustomerNotification,
  eventOccurredAt: string
): Promise<{ userId: string | null }> {
  const mode = paddleMode();
  const customerId = requireId(customer.id, 'ctm');
  const occurredAt = requiredIsoDate(eventOccurredAt, 'event occurred');
  const userId =
    paddleCustomUserId(customer.customData) ??
    (await getMirrorOwner(mode.environment, 'customer_id', customerId)) ??
    (
      await getProviderBillingAccountByCustomer(PROVIDER, customerId, mode.testMode)
    )?.user_id ??
    null;

  const mirrorUpdated = await applyCustomerMirror({
    ...mode,
    customerId,
    userId,
    email: customer.email,
    name: customer.name,
    status: customer.status,
    createdAt: requiredIsoDate(customer.createdAt, 'customer created'),
    updatedAt: requiredIsoDate(customer.updatedAt, 'customer updated'),
    eventOccurredAt: occurredAt,
  });

  if (userId && mirrorUpdated) {
    const current = await getProviderBillingAccount(userId, PROVIDER, mode.testMode);
    if (!current?.provider_customer_id || current.provider_customer_id === customerId) {
      await upsertProviderBillingAccount(userId, PROVIDER, {
        test_mode: mode.testMode,
        email: customer.email,
        provider_customer_id: customerId,
      });
    }
  }
  return { userId };
}

export async function syncPaddleSubscription(
  subscription: PaddleSubscriptionLike,
  customUserId?: string | null,
  transactionId?: string | null,
  eventOccurredAt?: string
): Promise<{ userId: string; accountUpdated: boolean; mirrorUpdated: boolean }> {
  const normalized = validatePaddleSubscription(
    subscription,
    transactionId,
    eventOccurredAt
  );
  const [bySubscription, byCustomer, mirrorSubscriptionOwner, mirrorCustomerOwner] =
    await Promise.all([
      getProviderBillingAccountBySubscription(PROVIDER, normalized.id, normalized.testMode),
      getProviderBillingAccountByCustomer(
        PROVIDER,
        normalized.customerId,
        normalized.testMode
      ),
      getMirrorOwner(normalized.environment, 'subscription_id', normalized.id),
      getMirrorOwner(normalized.environment, 'customer_id', normalized.customerId),
    ]);

  const userId =
    customUserId ??
    paddleCustomUserId(subscription.customData) ??
    mirrorSubscriptionOwner ??
    mirrorCustomerOwner ??
    bySubscription?.user_id ??
    byCustomer?.user_id;
  if (!userId) {
    throw new Error(`No AXIO7 user is associated with Paddle subscription ${normalized.id}.`);
  }
  assertSameOwner(bySubscription, userId);
  assertSameOwner(byCustomer, userId);
  if (mirrorSubscriptionOwner && mirrorSubscriptionOwner !== userId) {
    throw new Error('Paddle subscription mirror is already bound to another AXIO7 user.');
  }
  if (mirrorCustomerOwner && mirrorCustomerOwner !== userId) {
    throw new Error('Paddle customer mirror is already bound to another AXIO7 user.');
  }

  const mirrorUpdated = await applySubscriptionMirror(normalized, userId);
  if (!mirrorUpdated) {
    // The source-timestamp guarded mirror is the ordering authority. Never let
    // an older same-resource event continue on to overwrite entitlement state.
    return { userId, accountUpdated: false, mirrorUpdated: false };
  }
  const current = await getProviderBillingAccount(userId, PROVIDER, normalized.testMode);
  if (current?.provider_subscription_id && current.provider_subscription_id !== normalized.id) {
    const currentCreatedAt = current.provider_created_at
      ? Date.parse(current.provider_created_at)
      : Number.NEGATIVE_INFINITY;
    if (currentCreatedAt > Date.parse(normalized.providerCreatedAt)) {
      return { userId, accountUpdated: false, mirrorUpdated };
    }
  }
  if (
    current?.provider_subscription_id === normalized.id &&
    current.source_updated_at &&
    Date.parse(current.source_updated_at) > Date.parse(normalized.sourceUpdatedAt)
  ) {
    return { userId, accountUpdated: false, mirrorUpdated };
  }

  const values: ProviderBillingAccountUpsert = {
    test_mode: normalized.testMode,
    provider_customer_id: normalized.customerId,
    provider_subscription_id: normalized.id,
    provider_price_id: normalized.priceId,
    subscription_status: normalized.status,
    current_period_end: normalized.currentPeriodEnd,
    cancel_at_period_end: normalized.cancelAtPeriodEnd,
    lifetime_access: false,
    customer_portal_url: null,
    provider_created_at: normalized.providerCreatedAt,
    source_updated_at: normalized.sourceUpdatedAt,
  };
  if (normalized.transactionId) values.provider_order_id = normalized.transactionId;

  const accountUpdated = await applyPaddleBillingAccount(userId, {
    ...values,
    provider_customer_id: normalized.customerId,
    provider_subscription_id: normalized.id,
    provider_price_id: normalized.priceId,
    subscription_status: normalized.status,
    provider_created_at: normalized.providerCreatedAt,
    source_updated_at: normalized.sourceUpdatedAt,
  });
  return { userId, accountUpdated, mirrorUpdated };
}

export async function syncPaddleTransaction(
  transaction: PaddleTransactionLike,
  eventOccurredAt?: string
): Promise<{ userId: string; accountUpdated: boolean; mirrorUpdated: boolean }> {
  if (transaction.status !== 'completed') {
    throw new Error(`Paddle transaction ${transaction.id} is not completed.`);
  }
  const transactionId = requireId(transaction.id, 'txn');
  const subscriptionId = transaction.subscriptionId
    ? requireId(transaction.subscriptionId, 'sub')
    : null;
  const customerId = transaction.customerId
    ? requireId(transaction.customerId, 'ctm')
    : null;
  if (!subscriptionId) {
    const publicTier = getPaddleTierForPriceId(
      normalizedCatalogItem(transaction.items).priceId
    );
    if (publicTier?.tier.billingMode !== 'one_time') {
      throw new Error(`Paddle transaction ${transactionId} has no subscription.`);
    }
  }
  if (!customerId) {
    throw new Error(`Paddle transaction ${transactionId} has no customer.`);
  }
  const catalog = normalizedCatalogItem(transaction.items);
  const occurredAt = requiredIsoDate(
    eventOccurredAt ?? transaction.updatedAt,
    'event occurred'
  );

  const mode = paddleMode();
  if (!subscriptionId) {
    const tierMatch = getPaddleTierForPriceId(catalog.priceId);
    if (tierMatch?.tier.billingMode !== 'one_time') {
      throw new Error('Only the configured Lifetime price may complete without a subscription.');
    }
    const [byCustomer, mirrorCustomerOwner, mirrorTransactionOwner] = await Promise.all([
      getProviderBillingAccountByCustomer(PROVIDER, customerId, mode.testMode),
      getMirrorOwner(mode.environment, 'customer_id', customerId),
      getMirrorOwner(mode.environment, 'transaction_id', transactionId),
    ]);
    const userId =
      paddleCustomUserId(transaction.customData) ??
      mirrorTransactionOwner ??
      mirrorCustomerOwner ??
      byCustomer?.user_id;
    if (!userId) {
      throw new Error(`No AXIO7 user is associated with Paddle transaction ${transactionId}.`);
    }
    assertSameOwner(byCustomer, userId);
    if (mirrorCustomerOwner && mirrorCustomerOwner !== userId) {
      throw new Error('Paddle customer mirror is already bound to another AXIO7 user.');
    }
    if (mirrorTransactionOwner && mirrorTransactionOwner !== userId) {
      throw new Error('Paddle transaction mirror is already bound to another AXIO7 user.');
    }

    const createdAt = requiredIsoDate(transaction.createdAt, 'transaction created');
    const updatedAt = requiredIsoDate(transaction.updatedAt, 'transaction updated');
    const mirrorUpdated = await applyTransactionMirror({
      ...mode,
      transactionId,
      customerId,
      subscriptionId: null,
      userId,
      status: transaction.status,
      priceId: catalog.priceId,
      productId: catalog.productId,
      currencyCode: transaction.currencyCode,
      total: transaction.details?.totals?.total ?? null,
      createdAt,
      updatedAt,
      eventOccurredAt: occurredAt,
    });
    const accountUpdated = mirrorUpdated
      ? await applyPaddleLifetimeBillingAccount(userId, {
          test_mode: mode.testMode,
          provider_customer_id: customerId,
          provider_order_id: transactionId,
          provider_price_id: catalog.priceId,
          provider_created_at: createdAt,
          source_updated_at: updatedAt,
        })
      : false;
    await completePaddleCheckoutAttempt({
      environment: mode.environment,
      userId,
      transactionId,
    });
    await recordBillingUsageEventBestEffort({
      userId,
      eventType: 'subscription_started',
      metadata: {
        transaction_id: transactionId,
        access_type: 'lifetime',
      },
    });
    return { userId, accountUpdated, mirrorUpdated };
  }

  const subscription = await retrievePaddleSubscription(subscriptionId);
  if (subscription.customerId !== customerId) {
    throw new Error('Paddle transaction and subscription customer mismatch.');
  }
  const subscriptionResult = await syncPaddleSubscription(
    subscription,
    paddleCustomUserId(transaction.customData),
    transactionId,
    occurredAt
  );
  const mirrorUpdated = await applyTransactionMirror({
    ...mode,
    transactionId,
    customerId,
    subscriptionId,
    userId: subscriptionResult.userId,
    status: transaction.status,
    priceId: catalog.priceId,
    productId: catalog.productId,
    currencyCode: transaction.currencyCode,
    total: transaction.details?.totals?.total ?? null,
    createdAt: requiredIsoDate(transaction.createdAt, 'transaction created'),
    updatedAt: requiredIsoDate(transaction.updatedAt, 'transaction updated'),
    eventOccurredAt: occurredAt,
  });
  await completePaddleCheckoutAttempt({
    environment: mode.environment,
    userId: subscriptionResult.userId,
    transactionId,
  });
  await recordBillingUsageEventBestEffort({
    userId: subscriptionResult.userId,
    eventType: 'subscription_started',
    metadata: {
      transaction_id: transactionId,
      subscription_id: subscriptionId,
    },
  });
  return {
    userId: subscriptionResult.userId,
    accountUpdated: subscriptionResult.accountUpdated,
    mirrorUpdated,
  };
}

export async function getPaddlePortalIdentityForUser(
  userId: string,
  testMode: boolean
): Promise<PaddlePortalIdentity | null> {
  if (!isSupabaseConfigured()) return null;
  const environment: PaddleEnvironment = testMode ? 'sandbox' : 'live';
  const { data, error } = await supabaseAdmin()
    .from('paddle_subscriptions')
    .select('customer_id,subscription_id')
    .eq('environment', environment)
    .eq('test_mode', testMode)
    .eq('user_id', userId)
    .order('paddle_updated_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) {
    // Keep already-provisioned accounts usable during a migration-first rollout.
    if (error.code === '42P01') return null;
    throw error;
  }
  if (!data?.customer_id || !data.subscription_id) return null;
  return {
    customerId: requireId(data.customer_id, 'ctm'),
    subscriptionId: requireId(data.subscription_id, 'sub'),
  };
}
