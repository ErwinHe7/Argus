import { z } from 'zod';

export const SESSION_STORAGE_KEY = 'leo.strategy-lab.auth.v1';
export const AUTH_CALLBACK_PATH = '/strategy-auth/callback';
export const AUTH_RETURN_KEY = `${SESSION_STORAGE_KEY}.return`;
export function authReturnPath(value: string | null): '/#/home' | '/#/strategies' | '/#/membership' {
  return value === '/#/strategies' || value === '/#/membership' ? value : '/#/home';
}
const PROJECT_ORIGIN = 'https://katwbobjiyzipqlzarus.supabase.co';

export const publicConfigSchema = z.object({
  schemaVersion: z.literal('strategy-public-config/v1'),
  enabled: z.boolean(),
  supabaseUrl: z.literal(PROJECT_ORIGIN),
  publishableKey: z.string(),
  apiUrl: z.literal(`${PROJECT_ORIGIN}/functions/v1/strategy-api`),
}).strict().superRefine((value, ctx) => {
  if (!value.enabled && value.publishableKey === '') return;
  if (value.publishableKey.startsWith('sb_publishable_')) return;
  // Retained projects can use legacy anon keys. Never accept service-role JWTs.
  try {
    const payload = JSON.parse(atob(value.publishableKey.split('.')[1]!.replace(/-/g, '+').replace(/_/g, '/')));
    if (payload.role === 'anon' && payload.ref === 'katwbobjiyzipqlzarus') return;
  } catch { /* Report only the configuration field, never its value. */ }
  ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['publishableKey'], message: 'A public Supabase key is required.' });
});
export type PublicConfig = z.infer<typeof publicConfigSchema>;

export function callbackLocation(current: string): { code: string | null; failed: boolean } {
  const url = new URL(current);
  if (url.pathname !== AUTH_CALLBACK_PATH) return { code: null, failed: false };
  return { code: url.searchParams.get('code'), failed: url.searchParams.has('error') || new URLSearchParams(url.hash.slice(1)).has('error') };
}

export async function loadPublicConfig(): Promise<PublicConfig> {
  const response = await fetch('/app/research-desk/strategy-config.json', { cache: 'no-store', redirect: 'error' });
  if (!response.ok) throw new Error('Strategy connection settings are unavailable. Reload to retry.');
  const result = publicConfigSchema.safeParse(await response.json());
  if (!result.success) throw new Error('Strategy connection settings are invalid. Contact Leo support.');
  return result.data;
}
