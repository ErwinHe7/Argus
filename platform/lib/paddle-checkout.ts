import 'server-only';

import type { Customer } from '@paddle/paddle-node-sdk';
import { getPaddle, paddleCustomUserId } from './paddle';
import { getPaddleEnvironment } from './paddle';
import { isSupabaseConfigured, supabaseAdmin } from './supabase';

type CheckoutUser = { id: string; email: string | null; name: string };

function validId(value: unknown, prefix: 'ctm' | 'txn'): value is string {
  return typeof value === 'string' && new RegExp(`^${prefix}_[a-z0-9]{26}$`).test(value);
}

function customValue(value: unknown, key: string): unknown {
  return value && typeof value === 'object'
    ? (value as Record<string, unknown>)[key]
    : undefined;
}

async function mirrorCheckoutCustomer(customer: Customer, userId: string): Promise<void> {
  if (!isSupabaseConfigured()) {
    throw new Error('Supabase must be configured before accepting payments.');
  }
  const environment = getPaddleEnvironment();
  const now = new Date().toISOString();
  const { error } = await supabaseAdmin().rpc('apply_paddle_customer', {
    p_environment: environment,
    p_test_mode: environment === 'sandbox',
    p_customer_id: customer.id,
    p_user_id: userId,
    p_email: customer.email,
    p_name: customer.name,
    p_status: customer.status,
    p_paddle_created_at: customer.createdAt,
    p_paddle_updated_at: customer.updatedAt,
    p_event_occurred_at: now,
  });
  if (error) throw error;
}

async function findMirroredCustomer(userId: string): Promise<Customer | null> {
  const environment = getPaddleEnvironment();
  const { data, error } = await supabaseAdmin()
    .from('paddle_customers')
    .select('customer_id')
    .eq('environment', environment)
    .eq('user_id', userId)
    .maybeSingle();
  if (error) throw error;
  if (!validId(data?.customer_id, 'ctm')) return null;
  const customer = await getPaddle().customers.get(data.customer_id);
  if (paddleCustomUserId(customer.customData) !== userId) {
    throw new Error('Paddle customer ownership metadata does not match the signed-in user.');
  }
  return customer;
}

async function findCustomerByEmail(user: CheckoutUser): Promise<Customer | null> {
  if (!user.email) return null;
  const collection = getPaddle().customers.list({
    email: [user.email],
    status: ['active'],
    perPage: 50,
  });
  for await (const customer of collection) {
    if (paddleCustomUserId(customer.customData) === user.id) return customer;
  }
  return null;
}

async function ensureCustomer(user: CheckoutUser): Promise<Customer> {
  if (!user.email) {
    throw new Error('A verified account email is required to start Paddle checkout.');
  }
  const existing =
    (await findMirroredCustomer(user.id)) ?? (await findCustomerByEmail(user));
  const customer = existing
    ? await getPaddle().customers.update(existing.id, {
        email: user.email,
        name: user.name || undefined,
        customData: { ...(existing.customData ?? {}), axio7_user_id: user.id },
      })
    : await getPaddle().customers.create({
        email: user.email,
        name: user.name || undefined,
        customData: { axio7_user_id: user.id },
      });
  await mirrorCheckoutCustomer(customer, user.id);
  return customer;
}

export async function ensurePaddleCheckoutIdentity(input: {
  user: CheckoutUser;
}): Promise<{ customerId: string }> {
  const customer = await ensureCustomer(input.user);
  if (!validId(customer.id, 'ctm')) {
    throw new Error('Paddle did not return a valid checkout customer.');
  }
  // Do not invent a postal code or persist a country-only billing address.
  // Paddle Checkout collects the complete billing address while the signed-in
  // customer's verified email remains prefilled through customerId.
  return { customerId: customer.id };
}

export async function findPaddleTransactionByAttemptToken(
  attemptToken: string
): Promise<string | null> {
  const createdAfter = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const transactions = getPaddle().transactions.list({
    'createdAt[GTE]': createdAfter,
    origin: ['api'],
    perPage: 200,
  });
  for await (const transaction of transactions) {
    if (
      customValue(transaction.customData, 'axio7_checkout_attempt') === attemptToken &&
      validId(transaction.id, 'txn')
    ) {
      return transaction.id;
    }
  }
  return null;
}
