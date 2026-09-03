import 'server-only';

import type Stripe from 'stripe';
import { isSupabaseConfigured, supabaseAdmin } from './supabase';
import { getStripe, isStripeLiveMode } from './stripe';

export const BILLING_PROVIDERS = ['stripe', 'lemon_squeezy', 'paddle'] as const;
export type BillingProvider = (typeof BILLING_PROVIDERS)[number];

export type ProviderBillingAccount = {
  user_id: string;
  provider: BillingProvider;
  test_mode: boolean;
  email: string | null;
  provider_customer_id: string | null;
  provider_subscription_id: string | null;
  provider_order_id: string | null;
  provider_price_id: string | null;
  subscription_status: string | null;
  current_period_end: string | null;
  cancel_at_period_end: boolean;
  lifetime_access: boolean;
  customer_portal_url: string | null;
  provider_created_at: string | null;
  source_updated_at: string | null;
  refund_status: 'under_review' | 'approved' | 'rejected' | 'reversed' | null;
  refund_transaction_id: string | null;
  refund_subscription_id: string | null;
  refund_updated_at: string | null;
  created_at: string;
  updated_at: string;
};

export type ProviderBillingAccountUpsert = Partial<
  Omit<
    ProviderBillingAccount,
    'user_id' | 'provider' | 'test_mode' | 'created_at' | 'updated_at'
  >
> & {
  // Required and fail-closed: callers must explicitly identify test data so it
  // can never be stored in the live entitlement row by omission.
  test_mode: boolean;
};

export type BillingAccount = {
  user_id: string;
  email: string | null;
  stripe_customer_id: string | null;
  stripe_subscription_id: string | null;
  subscription_status: string | null;
  stripe_price_id: string | null;
  current_period_end: string | null;
  cancel_at_period_end: boolean;
  lifetime_access: boolean;
  lifetime_price_id: string | null;
  lifetime_payment_intent_id: string | null;
  stripe_livemode: boolean;
  created_at: string;
  updated_at: string;
  provider_accounts?: ProviderBillingAccount[];
};

const STRIPE_ACCESS_STATUSES = new Set(['active', 'trialing']);
const LEMON_ACCESS_STATUSES = new Set(['active', 'on_trial', 'paused', 'past_due']);
const PADDLE_ACCESS_STATUSES = new Set(['active', 'trialing']);

function isBillingProvider(value: string): value is BillingProvider {
  return BILLING_PROVIDERS.includes(value as BillingProvider);
}

function assertBillingProvider(provider: BillingProvider): void {
  if (!isBillingProvider(provider)) {
    throw new Error(`Unsupported billing provider: ${provider}`);
  }
}

function providerTestAccessIsEnabled(provider: BillingProvider): boolean {
  if (
    provider === 'paddle' &&
    process.env.PADDLE_ENVIRONMENT?.trim().toLowerCase() === 'live' &&
    (process.env.PADDLE_ALLOW_SANDBOX_ACCESS === 'true' ||
      process.env.PAYMENTS_ALLOW_TEST_ACCESS === 'true')
  ) {
    throw new Error('Live Paddle configuration must never grant Sandbox billing access.');
  }
  if (process.env.PAYMENTS_ALLOW_TEST_ACCESS === 'true') return true;
  if (provider === 'stripe') return process.env.STRIPE_ALLOW_SANDBOX_ACCESS === 'true';
  if (provider === 'lemon_squeezy') {
    return process.env.LEMON_SQUEEZY_ALLOW_TEST_ACCESS === 'true';
  }
  return process.env.PADDLE_ALLOW_SANDBOX_ACCESS === 'true';
}

export function providerBillingAccountHasAccess(
  account: ProviderBillingAccount | null,
  now = Date.now()
): boolean {
  if (!account) return false;
  if (account.test_mode && !providerTestAccessIsEnabled(account.provider)) return false;
  const freePaddlePriceId = process.env.PADDLE_PRICE_FREE_MONTH?.trim();
  if (
    account.provider === 'paddle' &&
    freePaddlePriceId &&
    account.provider_price_id === freePaddlePriceId
  ) {
    // Free is a real Paddle subscription for catalog and lifecycle purposes,
    // but it is intentionally read-only and must never unlock paid research.
    return false;
  }
  if (
    account.refund_status === 'approved' &&
    (
      (account.lifetime_access &&
        account.refund_transaction_id === account.provider_order_id) ||
      (account.refund_subscription_id != null &&
        account.refund_subscription_id === account.provider_subscription_id)
    )
  ) {
    return false;
  }
  if (account.lifetime_access) return true;
  const status = account.subscription_status;
  if (!status) return false;

  if (account.provider === 'lemon_squeezy') {
    // Lemon Squeezy considers paused and past-due subscriptions valid while it
    // manages collection/retries. Unpaid and expired fail closed. Cancelled
    // subscriptions remain paid only through the explicit ends_at timestamp.
    if (LEMON_ACCESS_STATUSES.has(status)) return true;
    if (status !== 'cancelled' || !account.cancel_at_period_end) return false;
    if (!account.current_period_end) return false;
    const graceEnd = Date.parse(account.current_period_end);
    return Number.isFinite(graceEnd) && graceEnd > now;
  }

  if (account.provider === 'paddle') {
    // Paddle keeps a subscription active while a scheduled cancellation waits
    // for its effective date. A scheduled change never revokes access by itself.
    // Active/trialing grant immediately; past_due gets only the already-paid
    // period, while paused/canceled fail closed.
    return paddleSubscriptionGrantsAccess(
      { status, currentPeriodEnd: account.current_period_end },
      now
    );
  }

  if (!STRIPE_ACCESS_STATUSES.has(status)) return false;
  if (!account.current_period_end) return true;
  const periodEnd = Date.parse(account.current_period_end);
  return Number.isFinite(periodEnd) && periodEnd > now;
}

export function paddleSubscriptionGrantsAccess(
  subscription: { status: string | null; currentPeriodEnd: string | null },
  now = Date.now()
): boolean {
  if (subscription.status && PADDLE_ACCESS_STATUSES.has(subscription.status)) return true;
  if (subscription.status !== 'past_due' || !subscription.currentPeriodEnd) return false;
  const periodEnd = Date.parse(subscription.currentPeriodEnd);
  return Number.isFinite(periodEnd) && periodEnd > now;
}

export function billingAccountHasAccess(account: BillingAccount | null): boolean {
  if (account?.provider_accounts?.some((entry) => providerBillingAccountHasAccess(entry))) {
    return true;
  }

  const modeCanGrantAccess =
    Boolean(account?.stripe_livemode) || process.env.STRIPE_ALLOW_SANDBOX_ACCESS === 'true';
  if (!modeCanGrantAccess) return false;

  return Boolean(
    account?.lifetime_access ||
      (account?.subscription_status && STRIPE_ACCESS_STATUSES.has(account.subscription_status))
  );
}

function isMissingRelationError(error: unknown): boolean {
  return Boolean(
    error &&
      typeof error === 'object' &&
      'code' in error &&
      (error as { code?: unknown }).code === '42P01'
  );
}

export async function assertProviderBillingStorageReady(): Promise<void> {
  if (!isSupabaseConfigured()) {
    throw new Error('Supabase must be configured before accepting payments.');
  }
  const [accounts, events] = await Promise.all([
    supabaseAdmin().from('billing_provider_accounts').select('user_id', { head: true, count: 'exact' }),
    supabaseAdmin().from('payment_webhook_events').select('event_id', { head: true, count: 'exact' }),
  ]);
  if (accounts.error) throw accounts.error;
  if (events.error) throw events.error;
}

export async function assertPaddleBillingStorageReady(): Promise<void> {
  await assertProviderBillingStorageReady();
  const { data, error } = await supabaseAdmin().rpc('paddle_billing_storage_ready');
  if (error) throw error;
  if (data !== true) throw new Error('Paddle billing storage migration is not ready.');
}

async function getProviderBillingAccountsForUser(
  userId: string
): Promise<ProviderBillingAccount[]> {
  if (!isSupabaseConfigured()) return [];
  const { data, error } = await supabaseAdmin()
    .from('billing_provider_accounts')
    .select('*')
    .eq('user_id', userId)
    .order('test_mode', { ascending: true })
    .order('updated_at', { ascending: false });

  if (error) {
    // Keep the existing Stripe integration deployable before migration 018 is
    // applied. Provider writes still fail loudly rather than losing purchases.
    if (isMissingRelationError(error)) return [];
    throw error;
  }
  return (data as ProviderBillingAccount[] | null) ?? [];
}

function synthesizeBillingAccount(
  userId: string,
  providerAccounts: ProviderBillingAccount[]
): BillingAccount | null {
  const primary =
    providerAccounts.find((account) => providerBillingAccountHasAccess(account)) ??
    providerAccounts[0];
  if (!primary) return null;
  const isStripe = primary.provider === 'stripe';

  return {
    user_id: userId,
    email: primary.email,
    stripe_customer_id: isStripe ? primary.provider_customer_id : null,
    stripe_subscription_id: isStripe ? primary.provider_subscription_id : null,
    subscription_status: primary.subscription_status,
    stripe_price_id: isStripe ? primary.provider_price_id : null,
    current_period_end: primary.current_period_end,
    cancel_at_period_end: primary.cancel_at_period_end,
    lifetime_access: primary.lifetime_access,
    lifetime_price_id: isStripe && primary.lifetime_access ? primary.provider_price_id : null,
    lifetime_payment_intent_id: isStripe ? primary.provider_order_id : null,
    stripe_livemode: isStripe && !primary.test_mode,
    created_at: primary.created_at,
    updated_at: primary.updated_at,
    provider_accounts: providerAccounts,
  };
}

export async function getBillingAccount(userId: string): Promise<BillingAccount | null> {
  if (!isSupabaseConfigured()) return null;
  const [legacyResult, providerAccounts] = await Promise.all([
    supabaseAdmin()
      .from('billing_accounts')
      .select('*')
      .eq('user_id', userId)
      .maybeSingle(),
    getProviderBillingAccountsForUser(userId),
  ]);

  if (legacyResult.error && !isMissingRelationError(legacyResult.error)) {
    throw legacyResult.error;
  }

  const legacy = (legacyResult.data as BillingAccount | null) ?? null;
  if (legacy) return { ...legacy, provider_accounts: providerAccounts };
  return synthesizeBillingAccount(userId, providerAccounts);
}

export async function getProviderBillingAccount(
  userId: string,
  provider: BillingProvider,
  testMode?: boolean
): Promise<ProviderBillingAccount | null> {
  if (!isSupabaseConfigured()) return null;
  assertBillingProvider(provider);

  let query = supabaseAdmin()
    .from('billing_provider_accounts')
    .select('*')
    .eq('user_id', userId)
    .eq('provider', provider);
  if (typeof testMode === 'boolean') query = query.eq('test_mode', testMode);

  const { data, error } = await query
    // With no explicit mode, prefer a live record and then the newest test row.
    .order('test_mode', { ascending: true })
    .order('updated_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) {
    if (isMissingRelationError(error)) return null;
    throw error;
  }
  return (data as ProviderBillingAccount | null) ?? null;
}

export async function getProviderBillingAccountBySubscription(
  provider: BillingProvider,
  subscriptionId: string,
  testMode?: boolean
): Promise<ProviderBillingAccount | null> {
  if (!isSupabaseConfigured()) return null;
  assertBillingProvider(provider);
  if (!subscriptionId.trim()) return null;

  let query = supabaseAdmin()
    .from('billing_provider_accounts')
    .select('*')
    .eq('provider', provider)
    .eq('provider_subscription_id', subscriptionId);
  if (typeof testMode === 'boolean') query = query.eq('test_mode', testMode);

  const { data, error } = await query
    .order('test_mode', { ascending: true })
    .order('updated_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) {
    if (isMissingRelationError(error)) return null;
    throw error;
  }
  return (data as ProviderBillingAccount | null) ?? null;
}

export async function getProviderBillingAccountByCustomer(
  provider: BillingProvider,
  customerId: string,
  testMode?: boolean
): Promise<ProviderBillingAccount | null> {
  if (!isSupabaseConfigured()) return null;
  assertBillingProvider(provider);
  if (!customerId.trim()) return null;

  let query = supabaseAdmin()
    .from('billing_provider_accounts')
    .select('*')
    .eq('provider', provider)
    .eq('provider_customer_id', customerId);
  if (typeof testMode === 'boolean') query = query.eq('test_mode', testMode);

  const { data, error } = await query
    .order('test_mode', { ascending: true })
    .order('updated_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) {
    if (isMissingRelationError(error)) return null;
    throw error;
  }
  return (data as ProviderBillingAccount | null) ?? null;
}

export async function upsertProviderBillingAccount(
  userId: string,
  provider: BillingProvider,
  values: ProviderBillingAccountUpsert
): Promise<void> {
  if (!isSupabaseConfigured()) {
    throw new Error('Supabase must be configured before accepting payments.');
  }
  assertBillingProvider(provider);

  const { error } = await supabaseAdmin()
    .from('billing_provider_accounts')
    .upsert(
      {
        user_id: userId,
        provider,
        ...values,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'user_id,provider,test_mode' }
    );
  if (error) throw error;
}

export async function applyPaddleBillingAccount(
  userId: string,
  values: ProviderBillingAccountUpsert & {
    provider_customer_id: string;
    provider_subscription_id: string;
    provider_price_id: string;
    subscription_status: string;
    provider_created_at: string;
    source_updated_at: string;
  }
): Promise<boolean> {
  if (!isSupabaseConfigured()) {
    throw new Error('Supabase must be configured before accepting payments.');
  }

  const { data, error } = await supabaseAdmin().rpc('apply_paddle_billing_account', {
    p_user_id: userId,
    p_test_mode: values.test_mode,
    p_provider_customer_id: values.provider_customer_id,
    p_provider_subscription_id: values.provider_subscription_id,
    p_provider_order_id: values.provider_order_id ?? null,
    p_provider_price_id: values.provider_price_id,
    p_subscription_status: values.subscription_status,
    p_current_period_end: values.current_period_end ?? null,
    p_cancel_at_period_end: values.cancel_at_period_end ?? false,
    p_provider_created_at: values.provider_created_at,
    p_source_updated_at: values.source_updated_at,
  });
  if (error) throw error;
  return data === true;
}

export async function applyPaddleLifetimeBillingAccount(
  userId: string,
  values: {
    test_mode: boolean;
    provider_customer_id: string;
    provider_order_id: string;
    provider_price_id: string;
    provider_created_at: string;
    source_updated_at: string;
  }
): Promise<boolean> {
  if (!isSupabaseConfigured()) {
    throw new Error('Supabase must be configured before accepting payments.');
  }

  const { data, error } = await supabaseAdmin().rpc('apply_paddle_lifetime_billing_account', {
    p_user_id: userId,
    p_test_mode: values.test_mode,
    p_provider_customer_id: values.provider_customer_id,
    p_provider_order_id: values.provider_order_id,
    p_provider_price_id: values.provider_price_id,
    p_provider_created_at: values.provider_created_at,
    p_source_updated_at: values.source_updated_at,
  });
  if (error) throw error;
  return data === true;
}

async function getBillingAccountByCustomer(customerId: string): Promise<BillingAccount | null> {
  if (!isSupabaseConfigured()) return null;
  const { data, error } = await supabaseAdmin()
    .from('billing_accounts')
    .select('*')
    .eq('stripe_customer_id', customerId)
    .maybeSingle();
  if (error) throw error;
  return (data as BillingAccount | null) ?? null;
}

async function upsertBillingAccount(
  userId: string,
  values: Partial<
    Omit<BillingAccount, 'user_id' | 'created_at' | 'updated_at' | 'provider_accounts'>
  >
): Promise<void> {
  if (!isSupabaseConfigured()) {
    throw new Error('Supabase must be configured before accepting Stripe payments.');
  }

  const { error } = await supabaseAdmin()
    .from('billing_accounts')
    .upsert(
      {
        user_id: userId,
        ...values,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'user_id' }
    );
  if (error) throw error;

  const has = (key: keyof typeof values) => Object.prototype.hasOwnProperty.call(values, key);
  const providerValues: ProviderBillingAccountUpsert = {
    test_mode: !(values.stripe_livemode ?? isStripeLiveMode()),
  };
  if (has('email')) providerValues.email = values.email;
  if (has('stripe_customer_id')) providerValues.provider_customer_id = values.stripe_customer_id;
  if (has('stripe_subscription_id')) {
    providerValues.provider_subscription_id = values.stripe_subscription_id;
  }
  if (has('subscription_status')) providerValues.subscription_status = values.subscription_status;
  if (has('stripe_price_id') && values.stripe_price_id) {
    providerValues.provider_price_id = values.stripe_price_id;
  } else if (has('lifetime_price_id')) {
    providerValues.provider_price_id = values.lifetime_price_id;
  } else if (has('stripe_price_id')) {
    providerValues.provider_price_id = values.stripe_price_id;
  }
  if (has('lifetime_payment_intent_id')) {
    providerValues.provider_order_id = values.lifetime_payment_intent_id;
  }
  if (has('current_period_end')) providerValues.current_period_end = values.current_period_end;
  if (has('cancel_at_period_end')) {
    providerValues.cancel_at_period_end = values.cancel_at_period_end;
  }
  if (has('lifetime_access')) providerValues.lifetime_access = values.lifetime_access;

  try {
    await upsertProviderBillingAccount(userId, 'stripe', providerValues);
  } catch (providerError) {
    // Migration 018 can be applied immediately after a backward-compatible
    // Stripe deploy. Never suppress other errors such as cross-user ID reuse.
    if (!isMissingRelationError(providerError)) throw providerError;
  }
}

function resetValuesForModeChange(account: BillingAccount | null, livemode: boolean) {
  if (!account || Boolean(account.stripe_livemode) === livemode) return {};
  return {
    stripe_customer_id: null,
    stripe_subscription_id: null,
    subscription_status: null,
    stripe_price_id: null,
    current_period_end: null,
    cancel_at_period_end: false,
    lifetime_access: false,
    lifetime_price_id: null,
    lifetime_payment_intent_id: null,
  } satisfies Partial<BillingAccount>;
}

function isMissingStripeResource(error: unknown): boolean {
  return Boolean(
    error &&
      typeof error === 'object' &&
      'code' in error &&
      (error as { code?: unknown }).code === 'resource_missing'
  );
}

function customerId(customer: string | Stripe.Customer | Stripe.DeletedCustomer | null): string | null {
  if (!customer) return null;
  return typeof customer === 'string' ? customer : customer.id;
}

function paymentIntentId(
  paymentIntent: string | Stripe.PaymentIntent | null
): string | null {
  if (!paymentIntent) return null;
  return typeof paymentIntent === 'string' ? paymentIntent : paymentIntent.id;
}

function subscriptionPeriodEnd(subscription: Stripe.Subscription): string | null {
  const ends = subscription.items.data
    .map((item) => item.current_period_end)
    .filter((value): value is number => Number.isFinite(value));
  if (!ends.length) return null;
  return new Date(Math.max(...ends) * 1000).toISOString();
}

async function userIdForCustomer(customer: string | Stripe.Customer | Stripe.DeletedCustomer | null) {
  const id = customerId(customer);
  if (!id) return null;

  const account = await getBillingAccountByCustomer(id);
  if (account?.user_id) return account.user_id;

  const stripe = getStripe();
  const resolved =
    typeof customer === 'string'
      ? await stripe.customers.retrieve(customer)
      : customer;
  if (!resolved) return null;
  if ('deleted' in resolved && resolved.deleted) return null;
  return resolved.metadata.axio7_user_id || null;
}

export async function ensureStripeCustomer(user: {
  id: string;
  email: string | null;
  name: string;
}): Promise<string> {
  const stripe = getStripe();
  const account = await getBillingAccount(user.id);
  const livemode = isStripeLiveMode();

  if (account?.stripe_customer_id && Boolean(account.stripe_livemode) === livemode) {
    try {
      const customer = await stripe.customers.retrieve(account.stripe_customer_id);
      if (!('deleted' in customer && customer.deleted)) return customer.id;
    } catch (error) {
      // IDs are isolated by Stripe account and mode. A stale ID must never be
      // reused after switching from a sandbox key to a live key (or accounts).
      if (!isMissingStripeResource(error)) throw error;
    }
  }

  const safeUserId = user.id.replace(/[^a-zA-Z0-9_-]/g, '');
  const existing = await stripe.customers.search({
    query: `metadata['axio7_user_id']:'${safeUserId}'`,
    limit: 1,
  });

  const customer =
    existing?.data[0] ??
    (await stripe.customers.create(
      {
        email: user.email ?? undefined,
        name: user.name || undefined,
        metadata: { axio7_user_id: user.id },
      },
      { idempotencyKey: `axio7_customer_${livemode ? 'live' : 'test'}_${safeUserId}` }
    ));

  await upsertBillingAccount(user.id, {
    ...resetValuesForModeChange(account, livemode),
    email: user.email,
    stripe_customer_id: customer.id,
    stripe_livemode: livemode,
  });
  return customer.id;
}

export async function syncStripeSubscription(subscription: Stripe.Subscription): Promise<void> {
  const userId =
    subscription.metadata.axio7_user_id || (await userIdForCustomer(subscription.customer));
  if (!userId) throw new Error(`No AXIO7 user is associated with subscription ${subscription.id}.`);

  const item = subscription.items.data[0];
  const account = await getBillingAccount(userId);
  await upsertBillingAccount(userId, {
    ...resetValuesForModeChange(account, subscription.livemode),
    stripe_customer_id: customerId(subscription.customer),
    stripe_subscription_id: subscription.id,
    subscription_status: subscription.status,
    stripe_price_id: item?.price.id ?? null,
    current_period_end: subscriptionPeriodEnd(subscription),
    cancel_at_period_end: subscription.cancel_at_period_end,
    stripe_livemode: subscription.livemode,
  });
}

export async function syncStripeInvoice(invoice: Stripe.Invoice): Promise<void> {
  const subscriptionRef = invoice.parent?.subscription_details?.subscription;
  if (!subscriptionRef) return;

  const subscription =
    typeof subscriptionRef === 'string'
      ? await getStripe().subscriptions.retrieve(subscriptionRef)
      : subscriptionRef;
  await syncStripeSubscription(subscription);
}

export async function syncStripeCheckoutSession(session: Stripe.Checkout.Session): Promise<void> {
  const userId = session.metadata?.axio7_user_id || session.client_reference_id;
  if (!userId) throw new Error(`No AXIO7 user is associated with Checkout Session ${session.id}.`);

  const account = await getBillingAccount(userId);
  await upsertBillingAccount(userId, {
    ...resetValuesForModeChange(account, session.livemode),
    email: session.customer_details?.email ?? session.customer_email ?? null,
    stripe_customer_id: customerId(session.customer),
    stripe_livemode: session.livemode,
  });

  if (session.mode === 'subscription' && session.subscription) {
    const subscription =
      typeof session.subscription === 'string'
        ? await getStripe().subscriptions.retrieve(session.subscription)
        : session.subscription;
    await syncStripeSubscription(subscription);
    return;
  }

  if (
    session.mode === 'payment' &&
    (session.payment_status === 'paid' || session.payment_status === 'no_payment_required')
  ) {
    await upsertBillingAccount(userId, {
      lifetime_access: true,
      lifetime_price_id: session.metadata?.stripe_price_id ?? null,
      lifetime_payment_intent_id: paymentIntentId(session.payment_intent),
    });
  }
}

export async function revokeLifetimeAccessForPaymentIntent(paymentIntent: string): Promise<void> {
  if (!isSupabaseConfigured()) return;
  const { error } = await supabaseAdmin()
    .from('billing_accounts')
    .update({ lifetime_access: false, updated_at: new Date().toISOString() })
    .eq('lifetime_payment_intent_id', paymentIntent);
  if (error) throw error;

  const { error: providerError } = await supabaseAdmin()
    .from('billing_provider_accounts')
    .update({ lifetime_access: false, updated_at: new Date().toISOString() })
    .eq('provider', 'stripe')
    .eq('provider_order_id', paymentIntent);
  if (providerError && !isMissingRelationError(providerError)) throw providerError;
}

export type ProcessedPaymentEvent = {
  id: string;
  type: string;
  test_mode: boolean;
  processed_at?: string;
};

export async function hasProcessedPaymentEvent(
  provider: BillingProvider,
  eventId: string
): Promise<boolean> {
  if (!isSupabaseConfigured()) return false;
  assertBillingProvider(provider);
  if (!eventId.trim()) return false;

  const { data, error } = await supabaseAdmin()
    .from('payment_webhook_events')
    .select('event_id')
    .eq('provider', provider)
    .eq('event_id', eventId)
    .maybeSingle();
  if (error) {
    if (isMissingRelationError(error)) return false;
    throw error;
  }
  return Boolean(data);
}

export async function recordProcessedPaymentEvent(
  provider: BillingProvider,
  event: ProcessedPaymentEvent
): Promise<void> {
  if (!isSupabaseConfigured()) {
    throw new Error('Supabase must be configured to record payment webhook events.');
  }
  assertBillingProvider(provider);
  if (!event.id.trim() || !event.type.trim()) {
    throw new Error('Payment webhook event id and type are required.');
  }

  const { error } = await supabaseAdmin()
    .from('payment_webhook_events')
    .upsert(
      {
        provider,
        event_id: event.id,
        event_type: event.type,
        test_mode: event.test_mode,
        processed_at: event.processed_at ?? new Date().toISOString(),
      },
      { onConflict: 'provider,event_id', ignoreDuplicates: true }
    );
  if (error) throw error;
}

export type PaddleCheckoutClaim = {
  state: 'claimed' | 'ready' | 'completed' | 'busy' | 'recover';
  attemptToken: string;
  transactionId: string | null;
};

function normalizePaddleCheckoutClaim(value: unknown): PaddleCheckoutClaim {
  if (!value || typeof value !== 'object') {
    throw new Error('Invalid Paddle checkout claim response.');
  }
  const record = value as Record<string, unknown>;
  const state = record.state;
  const attemptToken = record.attempt_token;
  const transactionId = record.transaction_id;
  if (
    !['claimed', 'ready', 'completed', 'busy', 'recover'].includes(String(state)) ||
    typeof attemptToken !== 'string' ||
    (transactionId != null && typeof transactionId !== 'string')
  ) {
    throw new Error('Invalid Paddle checkout claim response.');
  }
  return {
    state: state as PaddleCheckoutClaim['state'],
    attemptToken,
    transactionId: typeof transactionId === 'string' ? transactionId : null,
  };
}

export async function claimPaddleCheckoutAttempt(input: {
  environment: 'sandbox' | 'live';
  testMode: boolean;
  userId: string;
  attemptToken: string;
}): Promise<PaddleCheckoutClaim> {
  if (!isSupabaseConfigured()) {
    throw new Error('Supabase must be configured before accepting payments.');
  }
  const { data, error } = await supabaseAdmin().rpc('claim_paddle_checkout_attempt', {
    p_environment: input.environment,
    p_test_mode: input.testMode,
    p_user_id: input.userId,
    p_attempt_token: input.attemptToken,
  });
  if (error) throw error;
  return normalizePaddleCheckoutClaim(data);
}

export async function resetPaddleCheckoutAttempt(input: {
  environment: 'sandbox' | 'live';
  userId: string;
  previousToken: string;
  attemptToken: string;
}): Promise<boolean> {
  const { data, error } = await supabaseAdmin().rpc('reset_paddle_checkout_attempt', {
    p_environment: input.environment,
    p_user_id: input.userId,
    p_previous_token: input.previousToken,
    p_attempt_token: input.attemptToken,
  });
  if (error) throw error;
  return data === true;
}

export async function rotatePaddleReadyCheckoutAttempt(input: {
  environment: 'sandbox' | 'live';
  userId: string;
  expectedToken: string;
  expectedTransactionId: string;
  attemptToken: string;
}): Promise<boolean> {
  const { data, error } = await supabaseAdmin().rpc('rotate_paddle_ready_checkout_attempt', {
    p_environment: input.environment,
    p_user_id: input.userId,
    p_expected_token: input.expectedToken,
    p_expected_transaction_id: input.expectedTransactionId,
    p_attempt_token: input.attemptToken,
  });
  if (error) throw error;
  return data === true;
}

export type PaddleCheckoutAttemptRecord = {
  state: 'creating' | 'ready' | 'completed' | 'abandoned';
  attemptToken: string;
  transactionId: string | null;
};

export async function getPaddleCheckoutAttemptForUser(input: {
  environment: 'sandbox' | 'live';
  userId: string;
}): Promise<PaddleCheckoutAttemptRecord | null> {
  if (!isSupabaseConfigured()) {
    throw new Error('Supabase must be configured before accepting payments.');
  }
  const { data, error } = await supabaseAdmin()
    .from('paddle_checkout_attempts')
    .select('state,attempt_token,transaction_id')
    .eq('environment', input.environment)
    .eq('user_id', input.userId)
    .maybeSingle();
  if (error) throw error;
  if (!data) return null;
  if (
    !['creating', 'ready', 'completed', 'abandoned'].includes(data.state) ||
    typeof data.attempt_token !== 'string' ||
    (data.transaction_id != null && typeof data.transaction_id !== 'string')
  ) {
    throw new Error('Invalid Paddle checkout attempt record.');
  }
  return {
    state: data.state as PaddleCheckoutAttemptRecord['state'],
    attemptToken: data.attempt_token,
    transactionId: data.transaction_id,
  };
}

export async function abandonPaddleCheckoutAttempt(input: {
  environment: 'sandbox' | 'live';
  userId: string;
  attemptToken: string;
  transactionId: string;
}): Promise<boolean> {
  const { data, error } = await supabaseAdmin().rpc('abandon_paddle_checkout_attempt', {
    p_environment: input.environment,
    p_user_id: input.userId,
    p_attempt_token: input.attemptToken,
    p_transaction_id: input.transactionId,
  });
  if (error) throw error;
  return data === true;
}

export async function finalizePaddleCheckoutAttempt(input: {
  environment: 'sandbox' | 'live';
  userId: string;
  attemptToken: string;
  transactionId: string;
}): Promise<void> {
  const { error } = await supabaseAdmin().rpc('finalize_paddle_checkout_attempt', {
    p_environment: input.environment,
    p_user_id: input.userId,
    p_attempt_token: input.attemptToken,
    p_transaction_id: input.transactionId,
  });
  if (error) throw error;
}

export async function completePaddleCheckoutAttempt(input: {
  environment: 'sandbox' | 'live';
  userId: string;
  transactionId: string;
}): Promise<void> {
  const { error } = await supabaseAdmin().rpc('complete_paddle_checkout_attempt', {
    p_environment: input.environment,
    p_user_id: input.userId,
    p_transaction_id: input.transactionId,
  });
  if (error) throw error;
}

export type PaddleWebhookClaim = 'claimed' | 'processed' | 'busy';

export type PaddleWebhookDelivery = {
  environment: 'sandbox' | 'live';
  testMode: boolean;
  eventId: string;
  notificationId: string | null;
  eventType: string;
  claimToken: string;
  occurredAt: string;
};

export async function claimPaddleWebhookEvent(
  event: PaddleWebhookDelivery
): Promise<PaddleWebhookClaim> {
  if (!isSupabaseConfigured()) {
    throw new Error('Supabase must be configured to process Paddle webhooks.');
  }
  const { data, error } = await supabaseAdmin().rpc('claim_paddle_webhook_event', {
    p_environment: event.environment,
    p_test_mode: event.testMode,
    p_event_id: event.eventId,
    p_notification_id: event.notificationId,
    p_event_type: event.eventType,
    p_claim_token: event.claimToken,
    p_occurred_at: event.occurredAt,
  });
  if (error) throw error;
  if (data !== 'claimed' && data !== 'processed' && data !== 'busy') {
    throw new Error('Unexpected Paddle webhook claim result.');
  }
  return data;
}

export async function completePaddleWebhookEvent(
  environment: PaddleWebhookDelivery['environment'],
  eventId: string,
  claimToken: string
): Promise<void> {
  if (!isSupabaseConfigured()) {
    throw new Error('Supabase must be configured to process Paddle webhooks.');
  }
  const { error } = await supabaseAdmin().rpc('complete_paddle_webhook_event', {
    p_environment: environment,
    p_event_id: eventId,
    p_claim_token: claimToken,
  });
  if (error) throw error;
}

export async function failPaddleWebhookEvent(
  environment: PaddleWebhookDelivery['environment'],
  eventId: string,
  claimToken: string,
  errorMessage: string
): Promise<void> {
  if (!isSupabaseConfigured()) return;
  const { error } = await supabaseAdmin().rpc('fail_paddle_webhook_event', {
    p_environment: environment,
    p_event_id: eventId,
    p_claim_token: claimToken,
    p_error: errorMessage,
  });
  if (error) throw error;
}

export async function hasProcessedStripeEvent(eventId: string): Promise<boolean> {
  if (!isSupabaseConfigured()) return false;
  if (await hasProcessedPaymentEvent('stripe', eventId)) return true;
  const { data, error } = await supabaseAdmin()
    .from('stripe_webhook_events')
    .select('event_id')
    .eq('event_id', eventId)
    .maybeSingle();
  if (error) {
    if (error.code === '42P01') return false;
    throw error;
  }
  return Boolean(data);
}

export async function recordProcessedStripeEvent(event: Stripe.Event): Promise<void> {
  if (!isSupabaseConfigured()) {
    throw new Error('Supabase must be configured to record Stripe webhook events.');
  }

  try {
    await recordProcessedPaymentEvent('stripe', {
      id: event.id,
      type: event.type,
      test_mode: !event.livemode,
    });
  } catch (providerError) {
    if (!isMissingRelationError(providerError)) throw providerError;
  }

  const { error } = await supabaseAdmin().from('stripe_webhook_events').upsert({
    event_id: event.id,
    event_type: event.type,
    livemode: event.livemode,
    processed_at: new Date().toISOString(),
  });
  if (error) throw error;
}
