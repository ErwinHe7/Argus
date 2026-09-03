import 'server-only';

import {
  getProviderBillingAccount,
  getProviderBillingAccountByCustomer,
  getProviderBillingAccountBySubscription,
  upsertProviderBillingAccount,
  type ProviderBillingAccount,
} from './billing';
import {
  getConfiguredLemonSqueezyVariantIds,
  getLemonSqueezyStoreId,
  isLemonSqueezyTestMode,
  type LemonSqueezySubscriptionResource,
  type LemonSqueezySubscriptionStatus,
} from './lemon-squeezy';

const PROVIDER = 'lemon_squeezy' as const;
const SUBSCRIPTION_STATUSES = new Set<LemonSqueezySubscriptionStatus>([
  'on_trial',
  'active',
  'paused',
  'past_due',
  'unpaid',
  'cancelled',
  'expired',
]);

type NormalizedLemonSubscription = {
  id: string;
  storeId: string;
  customerId: string;
  orderId: string;
  variantId: string;
  email: string | null;
  status: LemonSqueezySubscriptionStatus;
  testMode: boolean;
  cancelAtPeriodEnd: boolean;
  currentPeriodEnd: string | null;
  customerPortalUrl: string | null;
  providerCreatedAt: string | null;
  sourceUpdatedAt: string | null;
};

function numericId(value: unknown, label: string): string {
  const normalized = typeof value === 'number' ? String(value) : String(value ?? '').trim();
  if (!/^\d+$/.test(normalized)) throw new Error(`Invalid Lemon Squeezy ${label}.`);
  return normalized;
}

function optionalIsoDate(value: unknown): string | null {
  if (typeof value !== 'string' || !value.trim()) return null;
  const parsed = Date.parse(value);
  if (!Number.isFinite(parsed)) throw new Error('Invalid Lemon Squeezy subscription timestamp.');
  return new Date(parsed).toISOString();
}

function optionalHttpsUrl(value: unknown): string | null {
  if (typeof value !== 'string' || !value.trim()) return null;
  const parsed = new URL(value);
  if (parsed.protocol !== 'https:') throw new Error('Unsafe Lemon Squeezy portal URL.');
  return parsed.toString();
}

function normalizeUserId(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const normalized = value.trim();
  if (!normalized || normalized.length > 128 || /[\u0000-\u001f]/.test(normalized)) return null;
  return normalized;
}

export function lemonSqueezyCustomUserId(
  customData: Record<string, unknown> | undefined
): string | null {
  return normalizeUserId(customData?.user_id);
}

export function validateLemonSqueezySubscription(
  subscription: LemonSqueezySubscriptionResource
): NormalizedLemonSubscription {
  if (subscription.type !== 'subscriptions') {
    throw new Error('Unexpected Lemon Squeezy resource type.');
  }

  const attributes = subscription.attributes;
  const storeId = numericId(attributes.store_id, 'store ID');
  const expectedStoreId = getLemonSqueezyStoreId();
  if (!expectedStoreId || storeId !== expectedStoreId) {
    throw new Error('Lemon Squeezy store mismatch.');
  }

  const variantId = numericId(attributes.variant_id, 'variant ID');
  if (!getConfiguredLemonSqueezyVariantIds().has(variantId)) {
    throw new Error('Lemon Squeezy variant is not an AXIO7 plan.');
  }

  if (typeof attributes.test_mode !== 'boolean') {
    throw new Error('Lemon Squeezy subscription mode is missing.');
  }
  if (attributes.test_mode !== isLemonSqueezyTestMode()) {
    throw new Error('Lemon Squeezy subscription mode mismatch.');
  }

  if (!SUBSCRIPTION_STATUSES.has(attributes.status)) {
    throw new Error('Unknown Lemon Squeezy subscription status.');
  }

  const endsAt = optionalIsoDate(attributes.ends_at);
  const renewsAt = optionalIsoDate(attributes.renews_at);
  const trialEndsAt = optionalIsoDate(attributes.trial_ends_at);
  const currentPeriodEnd =
    attributes.status === 'cancelled' || attributes.status === 'expired'
      ? endsAt
      : attributes.status === 'on_trial'
        ? trialEndsAt ?? renewsAt
        : renewsAt;

  return {
    id: numericId(subscription.id, 'subscription ID'),
    storeId,
    customerId: numericId(attributes.customer_id, 'customer ID'),
    orderId: numericId(attributes.order_id, 'order ID'),
    variantId,
    email:
      typeof attributes.user_email === 'string' && attributes.user_email.trim()
        ? attributes.user_email.trim().slice(0, 320)
        : null,
    status: attributes.status,
    testMode: attributes.test_mode,
    cancelAtPeriodEnd: attributes.cancelled || attributes.status === 'cancelled',
    currentPeriodEnd,
    customerPortalUrl: optionalHttpsUrl(attributes.urls?.customer_portal),
    providerCreatedAt: optionalIsoDate(attributes.created_at),
    sourceUpdatedAt: optionalIsoDate(attributes.updated_at),
  };
}

function assertSameOwner(account: ProviderBillingAccount | null, userId: string): void {
  if (account && account.user_id !== userId) {
    throw new Error('Lemon Squeezy resource is already bound to another AXIO7 user.');
  }
}

export async function syncLemonSqueezySubscription(
  subscription: LemonSqueezySubscriptionResource,
  customUserId?: string | null
): Promise<{ userId: string; accountUpdated: boolean }> {
  const normalized = validateLemonSqueezySubscription(subscription);
  const [bySubscription, byCustomer] = await Promise.all([
    getProviderBillingAccountBySubscription(PROVIDER, normalized.id, normalized.testMode),
    getProviderBillingAccountByCustomer(PROVIDER, normalized.customerId, normalized.testMode),
  ]);

  const userId = normalizeUserId(customUserId) ?? bySubscription?.user_id ?? byCustomer?.user_id;
  if (!userId) {
    throw new Error(`No AXIO7 user is associated with Lemon Squeezy subscription ${normalized.id}.`);
  }
  assertSameOwner(bySubscription, userId);
  assertSameOwner(byCustomer, userId);

  const current = await getProviderBillingAccount(userId, PROVIDER, normalized.testMode);
  if (current?.provider_subscription_id && current.provider_subscription_id !== normalized.id) {
    const currentCreatedAt = current.provider_created_at
      ? Date.parse(current.provider_created_at)
      : Number.NEGATIVE_INFINITY;
    const incomingCreatedAt = normalized.providerCreatedAt
      ? Date.parse(normalized.providerCreatedAt)
      : Number.NEGATIVE_INFINITY;
    if (currentCreatedAt > incomingCreatedAt) {
      // A delayed event for an older subscription must not overwrite the newer
      // subscription selected for this user/provider/mode.
      return { userId, accountUpdated: false };
    }
  }

  if (
    current?.provider_subscription_id === normalized.id &&
    current.source_updated_at &&
    normalized.sourceUpdatedAt &&
    Date.parse(current.source_updated_at) > Date.parse(normalized.sourceUpdatedAt)
  ) {
    return { userId, accountUpdated: false };
  }

  await upsertProviderBillingAccount(userId, PROVIDER, {
    test_mode: normalized.testMode,
    email: normalized.email,
    provider_customer_id: normalized.customerId,
    provider_subscription_id: normalized.id,
    provider_order_id: normalized.orderId,
    provider_price_id: normalized.variantId,
    subscription_status: normalized.status,
    current_period_end: normalized.currentPeriodEnd,
    cancel_at_period_end: normalized.cancelAtPeriodEnd,
    lifetime_access: false,
    // Kept only as a snapshot for display. The portal endpoint always fetches
    // a fresh 24-hour signed URL before redirecting the customer.
    customer_portal_url: normalized.customerPortalUrl,
    provider_created_at: normalized.providerCreatedAt,
    source_updated_at: normalized.sourceUpdatedAt,
  });

  return { userId, accountUpdated: true };
}
