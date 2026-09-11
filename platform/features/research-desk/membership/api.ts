import type { SupabaseClient } from '@supabase/supabase-js';
import { z } from 'zod';

export const BILLING_API = 'https://leo-whop-billing.axio7.workers.dev';
// Whop's billing-portal documentation links Profile → Orders to this route.
export const WHOP_ORDERS = 'https://whop.com/@me/settings/orders/';
export const STATUS_MAX_AGE_MS = 5 * 60 * 1000;
const date = z.string().datetime({ offset: true });
export const membershipSchema = z.object({
  provider: z.literal('whop'),
  status: z.enum(['active', 'inactive', 'none', 'unavailable']),
  checkedAt: date.nullable(),
  cancelAtPeriodEnd: z.boolean(),
  renewalPeriodEnd: date.nullable(),
}).strict().refine(value => value.status !== 'active' || value.checkedAt !== null,
  'An active membership requires a verification time.');
export type MembershipStatus = z.infer<typeof membershipSchema>;

export function statusIsFresh(status: MembershipStatus, receivedAt: number, now = Date.now()): boolean {
  const checkedAt = status.checkedAt ? Date.parse(status.checkedAt) : receivedAt;
  return status.status !== 'unavailable' && checkedAt <= now + 60_000 && now - checkedAt < STATUS_MAX_AGE_MS && now - receivedAt < STATUS_MAX_AGE_MS;
}

export function checkoutUrl(value: unknown): string {
  const result = z.object({ url: z.string().url() }).strict().safeParse(value);
  if (!result.success) throw new Error('Whop checkout could not be opened. Please try again.');
  const url = new URL(result.data.url);
  if (url.origin !== 'https://whop.com' || url.username || url.password || !/^\/checkout\/[^/]+\/?$/.test(url.pathname)) {
    throw new Error('The checkout address could not be verified. Please try again.');
  }
  return url.href;
}

async function billingRequest(auth: SupabaseClient, userId: string, path: '/status' | '/checkout', signal?: AbortSignal): Promise<unknown> {
  const controller = new AbortController();
  const abort = () => controller.abort();
  signal?.addEventListener('abort', abort, { once: true });
  if (signal?.aborted) controller.abort();
  const timer = setTimeout(abort, 15_000);
  try {
    const { data, error } = await auth.auth.getSession();
    if (controller.signal.aborted) throw new Error('Membership request was interrupted. Please try again.');
    if (error || !data.session || data.session.user.id !== userId || data.session.user.is_anonymous) {
      throw new Error('Your sign-in could not be restored. Return to your account and sign in again.');
    }
    const response = await fetch(`${BILLING_API}${path}`, {
      method: path === '/checkout' ? 'POST' : 'GET',
      headers: { Authorization: `Bearer ${data.session.access_token}` },
      cache: 'no-store', redirect: 'error', credentials: 'omit', referrerPolicy: 'no-referrer', signal: controller.signal,
    });
    if (response.status === 401) throw new Error('Your sign-in expired. Return to your account and sign in again.');
    if (response.status === 409) throw new Error('Your membership may already be active. Refresh its status or manage it on Whop.');
    if (!response.ok) throw new Error(path === '/checkout' ? 'Whop checkout is temporarily unavailable. Please try again.' : 'Membership status is temporarily unavailable. Please try again.');
    return await response.json();
  } catch (error) {
    if (error instanceof Error && /^(Your |Whop checkout |Membership status )/.test(error.message)) throw error;
    throw new Error('The membership service could not be reached. Check your connection and try again.');
  } finally {
    clearTimeout(timer); signal?.removeEventListener('abort', abort);
  }
}

export async function loadMembership(auth: SupabaseClient, userId: string, signal?: AbortSignal): Promise<MembershipStatus> {
  const result = membershipSchema.safeParse(await billingRequest(auth, userId, '/status', signal));
  if (!result.success) throw new Error('Membership status could not be verified. Please try again.');
  return result.data;
}

export async function createCheckout(auth: SupabaseClient, userId: string, signal?: AbortSignal): Promise<string> {
  return checkoutUrl(await billingRequest(auth, userId, '/checkout', signal));
}
