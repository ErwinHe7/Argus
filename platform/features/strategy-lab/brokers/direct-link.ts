import type { SupabaseClient } from '@supabase/supabase-js';
import { z } from 'zod';

export const BROKER_LINK_API = 'https://leo-broker-link.axio7.workers.dev';
export const MOOMOO_START = `${BROKER_LINK_API}/oauth/moomoo/start`;
export const directLinkSchema = z.object({
  schemaVersion: z.literal('broker-link/v1'), provider: z.literal('moomoo'), configured: z.boolean(),
  state: z.enum(['disconnected', 'connected', 'reauthorization_required', 'unavailable']),
  checkedAt: z.string().datetime({ offset: true }).nullable(),
  accounts: z.array(z.object({ label: z.string().regex(/^••••[A-Za-z0-9]{1,4}$/), securityFirm: z.string().max(100), accountType: z.enum(['cash', 'margin']), markets: z.array(z.number().int()) }).strict()),
  readonly: z.literal(true), executionEnabled: z.literal(false), message: z.string().max(500),
}).strict().refine(value => value.state !== 'connected' || (value.configured && value.checkedAt !== null), 'A connected account requires verification.');
export type DirectLinkStatus = z.infer<typeof directLinkSchema>;
export function directLinkFresh(value: DirectLinkStatus, now = Date.now()): boolean {
  if (!value.checkedAt) return false;
  const checked = Date.parse(value.checkedAt);
  return value.state === 'connected' && checked <= now + 60_000 && now - checked < 300_000;
}
export async function brokerLinkToken(auth: SupabaseClient, userId: string): Promise<string> {
  const { data, error } = await auth.auth.getSession();
  if (error || !data.session || data.session.user.id !== userId || data.session.user.is_anonymous) throw new Error('Your sign-in expired. Sign in to Leo again.');
  return data.session.access_token;
}
export async function requestDirectLink(auth: SupabaseClient, userId: string, path: '/status' | '/disconnect', signal: AbortSignal): Promise<DirectLinkStatus> {
  const token = await brokerLinkToken(auth, userId);
  if (signal.aborted) throw new Error('Connection request was interrupted. Try again.');
  const response = await fetch(`${BROKER_LINK_API}${path}`, {
    method: path === '/disconnect' ? 'POST' : 'GET', headers: { Authorization: `Bearer ${token}`, ...(path === '/disconnect' ? { 'Content-Type': 'application/json' } : {}) },
    ...(path === '/disconnect' ? { body: '{}' } : {}), cache: 'no-store', redirect: 'error', credentials: 'omit', referrerPolicy: 'no-referrer', signal,
  });
  if (response.status === 401) throw new Error('Your sign-in expired. Sign in to Leo again.');
  if (!response.ok) throw new Error('The account link could not be checked. Try again.');
  return directLinkSchema.parse(await response.json());
}
