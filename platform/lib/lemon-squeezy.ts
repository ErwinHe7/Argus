import 'server-only';

import { createHash, createHmac, timingSafeEqual } from 'node:crypto';
import type { BillingPlanDefinition, BillingPlanKey } from './stripe';

const LEMON_SQUEEZY_API_URL = 'https://api.lemonsqueezy.com/v1';

const VARIANT_ENV_NAMES: Record<BillingPlanKey, string> = {
  starter: 'LEMONSQUEEZY_VARIANT_STARTER',
  pro: 'LEMONSQUEEZY_VARIANT_PRO',
  premium: 'LEMONSQUEEZY_VARIANT_PREMIUM',
  enterprise: 'LEMONSQUEEZY_VARIANT_ENTERPRISE',
};

export type LemonSqueezySubscriptionStatus =
  | 'on_trial'
  | 'active'
  | 'paused'
  | 'past_due'
  | 'unpaid'
  | 'cancelled'
  | 'expired';

export type LemonSqueezySubscriptionAttributes = {
  store_id: number;
  customer_id: number;
  order_id: number;
  order_item_id: number;
  product_id: number;
  variant_id: number;
  product_name: string;
  variant_name: string;
  user_name: string;
  user_email: string;
  status: LemonSqueezySubscriptionStatus;
  cancelled: boolean;
  trial_ends_at: string | null;
  renews_at: string | null;
  ends_at: string | null;
  urls: {
    update_payment_method?: string | null;
    customer_portal?: string | null;
    update_customer_portal?: string | null;
    customer_portal_update_subscription?: string | null;
  };
  test_mode: boolean;
  created_at: string;
  updated_at: string;
};

export type LemonSqueezySubscriptionResource = {
  type: 'subscriptions';
  id: string;
  attributes: LemonSqueezySubscriptionAttributes;
};

export type LemonSqueezyWebhookPayload = {
  meta: {
    event_name: string;
    custom_data?: Record<string, unknown>;
  };
  data: {
    type: string;
    id: string;
    attributes: Record<string, unknown>;
  };
};

function configuredApiKey(): string | null {
  return process.env.LEMONSQUEEZY_API_KEY?.trim() || null;
}

export function getLemonSqueezyStoreId(): string | null {
  const value = process.env.LEMONSQUEEZY_STORE_ID?.trim();
  return value && /^\d+$/.test(value) ? value : null;
}

export function getLemonSqueezyVariantId(plan: BillingPlanDefinition): string | null {
  const value = process.env[VARIANT_ENV_NAMES[plan.key]]?.trim();
  return value && /^\d+$/.test(value) ? value : null;
}

export function getConfiguredLemonSqueezyVariantIds(): Set<string> {
  return new Set(
    Object.values(VARIANT_ENV_NAMES)
      .map((name) => process.env[name]?.trim())
      .filter((value): value is string => Boolean(value && /^\d+$/.test(value)))
  );
}

export function getLemonSqueezyPlanKeyForVariantId(
  variantId: string
): BillingPlanKey | null {
  for (const [planKey, envName] of Object.entries(VARIANT_ENV_NAMES) as Array<
    [BillingPlanKey, string]
  >) {
    if (process.env[envName]?.trim() === variantId) return planKey;
  }
  return null;
}

export function isLemonSqueezyTestMode(): boolean {
  // Fail safe: an omitted flag creates test checkouts and can never grant live access.
  return process.env.LEMONSQUEEZY_TEST_MODE?.trim().toLowerCase() !== 'false';
}

export function isLemonSqueezyConfigured(): boolean {
  return Boolean(configuredApiKey() && getLemonSqueezyStoreId());
}

export function isLemonSqueezyCheckoutConfigured(plan: BillingPlanDefinition): boolean {
  return Boolean(
    isLemonSqueezyConfigured() &&
      process.env.LEMONSQUEEZY_WEBHOOK_SECRET?.trim() &&
      getLemonSqueezyVariantId(plan)
  );
}

async function lemonSqueezyRequest<T>(path: string, init?: RequestInit): Promise<T> {
  const apiKey = configuredApiKey();
  if (!apiKey) throw new Error('LEMONSQUEEZY_API_KEY is not configured.');

  const response = await fetch(`${LEMON_SQUEEZY_API_URL}${path}`, {
    ...init,
    headers: {
      Accept: 'application/vnd.api+json',
      'Content-Type': 'application/vnd.api+json',
      Authorization: `Bearer ${apiKey}`,
      ...init?.headers,
    },
    cache: 'no-store',
  });

  if (!response.ok) {
    // Do not echo provider response bodies: they can contain customer or account data.
    throw new Error(`Lemon Squeezy API request failed with HTTP ${response.status}.`);
  }
  return (await response.json()) as T;
}

export async function createLemonSqueezyCheckout(input: {
  plan: BillingPlanDefinition;
  user: { id: string; email: string | null; name: string };
  baseUrl: string;
}): Promise<string> {
  const storeId = getLemonSqueezyStoreId();
  const variantId = getLemonSqueezyVariantId(input.plan);
  if (!storeId || !variantId) {
    throw new Error(`Lemon Squeezy is not configured for ${input.plan.key}.`);
  }

  const response = await lemonSqueezyRequest<{
    data: { attributes: { url: string; store_id: number; variant_id: number; test_mode: boolean } };
  }>('/checkouts', {
    method: 'POST',
    body: JSON.stringify({
      data: {
        type: 'checkouts',
        attributes: {
          product_options: {
            enabled_variants: [Number(variantId)],
            redirect_url: `${input.baseUrl}/billing/success?provider=lemonsqueezy`,
            receipt_button_text: 'Open AXIO7',
            receipt_link_url: `${input.baseUrl}/billing`,
          },
          checkout_options: {
            embed: false,
            media: true,
            logo: true,
            desc: true,
            discount: true,
            subscription_preview: true,
            button_color: '#7c3aed',
          },
          checkout_data: {
            email: input.user.email || undefined,
            name: input.user.name || undefined,
            custom: {
              user_id: input.user.id,
              plan_key: input.plan.key,
            },
          },
          test_mode: isLemonSqueezyTestMode(),
        },
        relationships: {
          store: { data: { type: 'stores', id: storeId } },
          variant: { data: { type: 'variants', id: variantId } },
        },
      },
    }),
  });

  const checkoutUrl = new URL(response.data.attributes.url);
  if (checkoutUrl.protocol !== 'https:') {
    throw new Error('Lemon Squeezy returned an unsafe Checkout URL.');
  }
  return checkoutUrl.toString();
}

export async function retrieveLemonSqueezySubscription(
  subscriptionId: string
): Promise<LemonSqueezySubscriptionResource> {
  if (!/^\d+$/.test(subscriptionId)) {
    throw new Error('Invalid Lemon Squeezy subscription ID.');
  }
  const response = await lemonSqueezyRequest<{ data: LemonSqueezySubscriptionResource }>(
    `/subscriptions/${subscriptionId}`
  );
  return response.data;
}

export function verifyLemonSqueezyWebhook(rawBody: string, signature: string): boolean {
  const secret = process.env.LEMONSQUEEZY_WEBHOOK_SECRET?.trim();
  if (!secret || !/^[a-fA-F0-9]{64}$/.test(signature)) return false;

  const expected = Buffer.from(createHmac('sha256', secret).update(rawBody).digest('hex'), 'hex');
  const received = Buffer.from(signature, 'hex');
  return received.length === expected.length && timingSafeEqual(expected, received);
}

export function lemonSqueezyWebhookEventId(rawBody: string): string {
  return `ls_${createHash('sha256').update(rawBody).digest('hex')}`;
}

export function parseLemonSqueezyWebhook(rawBody: string): LemonSqueezyWebhookPayload {
  const parsed = JSON.parse(rawBody) as Partial<LemonSqueezyWebhookPayload>;
  if (
    !parsed ||
    typeof parsed !== 'object' ||
    !parsed.meta ||
    typeof parsed.meta.event_name !== 'string' ||
    !parsed.data ||
    typeof parsed.data.type !== 'string' ||
    typeof parsed.data.id !== 'string' ||
    !parsed.data.attributes ||
    typeof parsed.data.attributes !== 'object'
  ) {
    throw new Error('Malformed Lemon Squeezy webhook payload.');
  }
  return parsed as LemonSqueezyWebhookPayload;
}

export function asLemonSqueezySubscription(
  payload: LemonSqueezyWebhookPayload
): LemonSqueezySubscriptionResource | null {
  if (payload.data.type !== 'subscriptions') return null;
  return payload.data as LemonSqueezySubscriptionResource;
}
