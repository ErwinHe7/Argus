import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { AUTH_CALLBACK_PATH, callbackLocation, SESSION_STORAGE_KEY, type PublicConfig } from './config';

let client: SupabaseClient | null = null;
let callbackExchange: Promise<void> | null = null;

export function strategyAuth(config: PublicConfig): SupabaseClient {
  if (!config.enabled) throw new Error('Strategy connections have not been enabled for this release.');
  client ??= createClient(config.supabaseUrl, config.publishableKey, {
    auth: { flowType: 'pkce', storageKey: SESSION_STORAGE_KEY, detectSessionInUrl: false, persistSession: true, autoRefreshToken: true },
  });
  return client;
}

export function completeSignIn(auth: SupabaseClient): Promise<void> {
  if (callbackExchange) return callbackExchange;
  const callback = callbackLocation(location.href);
  if (location.pathname !== AUTH_CALLBACK_PATH) return Promise.resolve();
  // Remove single-use codes and provider errors before any further requests.
  history.replaceState(null, '', '/#/strategies');
  callbackExchange = (async () => {
    if (callback.failed || !callback.code) throw new Error('Google sign-in was interrupted. Choose Sign in with Google to try again.');
    const { error } = await auth.auth.exchangeCodeForSession(callback.code);
    if (error) throw new Error('This sign-in link expired or belongs to another browser. Sign in again here.');
  })();
  return callbackExchange;
}

export async function signIn(auth: SupabaseClient): Promise<void> {
  const { error } = await auth.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: `${location.origin}${AUTH_CALLBACK_PATH}` } });
  if (error) throw new Error('Google sign-in could not start. Try again.');
}
