import 'server-only';

import type { AdjustmentNotification } from '@paddle/paddle-node-sdk';
import { getProviderBillingAccount, type ProviderBillingAccount } from './billing';
import { isPaddleSandbox } from './paddle';
import { isSupabaseConfigured, supabaseAdmin } from './supabase';

const PROVIDER = 'paddle' as const;
const OPEN_REFUND_STATUS = 'under_review';
const USAGE_EVENT_TYPES = [
  'research_report_generated',
  'api_call_completed',
  'export_downloaded',
  'subscription_started',
  'renewal_cancelled',
  'refund_requested',
] as const;

type UsageEventType = (typeof USAGE_EVENT_TYPES)[number];

function requiredId(value: string, prefix: 'adj' | 'ctm' | 'sub' | 'txn'): string {
  const normalized = value.trim();
  if (!new RegExp(`^${prefix}_[a-z0-9]{26}$`).test(normalized)) {
    throw new Error(`Invalid Paddle ${prefix} identifier.`);
  }
  return normalized;
}

function currentPaddleAccount(userId: string): Promise<ProviderBillingAccount | null> {
  return getProviderBillingAccount(userId, PROVIDER, isPaddleSandbox());
}

export async function recordBillingUsageEvent(input: {
  userId: string;
  eventType: UsageEventType;
  metadata?: Record<string, string | number | boolean | null>;
}): Promise<void> {
  if (!isSupabaseConfigured()) return;
  if (!USAGE_EVENT_TYPES.includes(input.eventType)) {
    throw new Error('Unsupported billing usage event type.');
  }
  const { error } = await supabaseAdmin().from('billing_usage_events').insert({
    user_id: input.userId,
    event_type: input.eventType,
    metadata: input.metadata ?? {},
  });
  if (error?.code === '42P01') return;
  if (error) throw error;
}

export async function recordBillingUsageEventBestEffort(input: {
  userId: string;
  eventType: UsageEventType;
  metadata?: Record<string, string | number | boolean | null>;
}): Promise<void> {
  try {
    await recordBillingUsageEvent(input);
  } catch (error) {
    console.error('[billing] Unable to record usage evidence', error);
  }
}

async function usageCounts(userId: string, since: string | null) {
  const counts: Record<string, number> = {};
  for (const eventType of USAGE_EVENT_TYPES) {
    let query = supabaseAdmin()
      .from('billing_usage_events')
      .select('id', { head: true, count: 'exact' })
      .eq('user_id', userId)
      .eq('event_type', eventType);
    if (since) query = query.gte('occurred_at', since);
    const { count, error } = await query;
    if (error?.code === '42P01') return {};
    if (error) throw error;
    counts[eventType] = count ?? 0;
  }
  return counts;
}

async function serviceIncidentCount(since: string | null): Promise<number | null> {
  let query = supabaseAdmin()
    .from('billing_service_incidents')
    .select('id', { head: true, count: 'exact' });
  if (since) query = query.gte('started_at', since);
  const { count, error } = await query;
  if (error?.code === '42P01') return null;
  if (error) throw error;
  return count ?? 0;
}

export async function createPaddleRefundRequest(input: {
  userId: string;
  reason: string;
}): Promise<{ id: string; created: boolean }> {
  if (!isSupabaseConfigured()) {
    throw new Error('Refund request storage is unavailable.');
  }
  const reason = input.reason.trim();
  if (reason.length < 20 || reason.length > 2_000) {
    throw new Error('Refund request reason must be between 20 and 2,000 characters.');
  }

  const account = await currentPaddleAccount(input.userId);
  if (
    !account?.provider_customer_id ||
    !account.provider_subscription_id ||
    !account.provider_order_id
  ) {
    throw new Error('No eligible Paddle transaction is attached to this account.');
  }

  const transactionId = requiredId(account.provider_order_id, 'txn');
  const { data: existing, error: existingError } = await supabaseAdmin()
    .from('billing_refund_requests')
    .select('id')
    .eq('user_id', input.userId)
    .eq('transaction_id', transactionId)
    .eq('status', OPEN_REFUND_STATUS)
    .maybeSingle();
  if (existingError && existingError.code !== '42P01') throw existingError;
  if (existing?.id) return { id: existing.id, created: false };

  const [authResult, counts, incidentCount] = await Promise.all([
    supabaseAdmin().auth.admin.getUserById(input.userId),
    usageCounts(input.userId, account.provider_created_at),
    serviceIncidentCount(account.provider_created_at),
  ]);
  if (authResult.error) throw authResult.error;

  const usageSummary = {
    evidence_source: 'server_recorded_only',
    first_login_at: authResult.data.user.created_at,
    last_sign_in_at: authResult.data.user.last_sign_in_at ?? null,
    event_counts: counts,
    service_incident_count: incidentCount,
    subscription_started_at: account.provider_created_at,
    subscription_status: account.subscription_status,
    current_period_end: account.current_period_end,
    renewal_cancelled: account.cancel_at_period_end,
    captured_at: new Date().toISOString(),
    caveat:
      'Counts include only events durably recorded by AXIO7. Missing telemetry is reported as missing, never inferred.',
  };

  const { data, error } = await supabaseAdmin()
    .from('billing_refund_requests')
    .insert({
      user_id: input.userId,
      environment: account.test_mode ? 'sandbox' : 'live',
      customer_id: requiredId(account.provider_customer_id, 'ctm'),
      subscription_id: requiredId(account.provider_subscription_id, 'sub'),
      transaction_id: transactionId,
      reason,
      usage_summary: usageSummary,
      status: OPEN_REFUND_STATUS,
    })
    .select('id')
    .single();
  if (error) throw error;

  await recordBillingUsageEventBestEffort({
    userId: input.userId,
    eventType: 'refund_requested',
    metadata: { transaction_id: transactionId },
  });
  return { id: data.id, created: true };
}

export async function syncPaddleRefundAdjustment(
  adjustment: AdjustmentNotification
): Promise<void> {
  if (adjustment.action !== 'refund') return;
  if (!isSupabaseConfigured()) {
    throw new Error('Refund adjustment storage is unavailable.');
  }

  const adjustmentId = requiredId(adjustment.id, 'adj');
  const transactionId = requiredId(adjustment.transactionId, 'txn');
  const subscriptionId = adjustment.subscriptionId
    ? requiredId(adjustment.subscriptionId, 'sub')
    : null;
  const status =
    adjustment.status === 'pending_approval'
      ? 'under_review'
      : adjustment.status === 'approved'
        ? 'approved'
        : adjustment.status === 'rejected'
          ? 'rejected'
          : adjustment.status === 'reversed'
            ? 'reversed'
            : null;
  if (!status) {
    throw new Error('Unknown Paddle refund adjustment status.');
  }

  const environment = isPaddleSandbox() ? 'sandbox' : 'live';
  const updatedAt = new Date(adjustment.updatedAt).toISOString();
  const { data: account, error: accountLookupError } = await supabaseAdmin()
    .from('billing_provider_accounts')
    .select('provider_subscription_id,lifetime_access')
    .eq('provider', PROVIDER)
    .eq('test_mode', environment === 'sandbox')
    .eq('provider_order_id', transactionId)
    .maybeSingle();
  if (accountLookupError) throw accountLookupError;
  if (!account) {
    throw new Error('Paddle refund adjustment is not attached to a known AXIO7 transaction.');
  }

  const accountSubscriptionId = account?.provider_subscription_id
    ? requiredId(account.provider_subscription_id, 'sub')
    : null;
  if (subscriptionId && accountSubscriptionId && subscriptionId !== accountSubscriptionId) {
    throw new Error('Paddle refund adjustment does not match the stored subscription.');
  }
  const resolvedSubscriptionId = subscriptionId ?? accountSubscriptionId;
  if (!resolvedSubscriptionId && !account.lifetime_access) {
    throw new Error('Paddle refund adjustment is not attached to a known subscription.');
  }

  const requestUpdate = await supabaseAdmin()
    .from('billing_refund_requests')
    .update({
      adjustment_id: adjustmentId,
      status,
      reviewed_at: status === 'under_review' ? null : updatedAt,
      updated_at: updatedAt,
    })
    .eq('environment', environment)
    .eq('transaction_id', transactionId);
  if (requestUpdate.error) throw requestUpdate.error;

  const accountUpdate = supabaseAdmin()
    .from('billing_provider_accounts')
    .update({
      refund_status: status,
      refund_transaction_id: transactionId,
      refund_subscription_id: resolvedSubscriptionId,
      refund_updated_at: updatedAt,
      updated_at: new Date().toISOString(),
    })
    .eq('provider', PROVIDER)
    .eq('test_mode', environment === 'sandbox')
    .eq('provider_order_id', transactionId);
  const { error: accountError } = await accountUpdate;
  if (accountError) throw accountError;
}
