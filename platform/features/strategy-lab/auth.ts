import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { AUTH_CALLBACK_PATH, AUTH_RETURN_KEY, authReturnPath, callbackLocation, SESSION_STORAGE_KEY, type PublicConfig } from './config';

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
  let destination = authReturnPath(null);
  try { destination = authReturnPath(sessionStorage.getItem(AUTH_RETURN_KEY)); sessionStorage.removeItem(AUTH_RETURN_KEY); } catch { /* Public Picks is the safe default when browser storage is blocked. */ }
  // Remove single-use codes and provider errors before exchanging the code.
  // Keep the callback screen mounted until exchange completes; it contains no charts.
  history.replaceState(null, '', '/#/welcome');
  callbackExchange = (async () => {
    if (callback.failed || !callback.code) throw new Error('Google sign-in was interrupted. Choose Sign in with Google to try again.');
    const { error } = await auth.auth.exchangeCodeForSession(callback.code);
    if (error) throw new Error('This sign-in link expired or belongs to another browser. Sign in again here.');
    history.replaceState(null, '', destination);
  })().finally(() => { callbackExchange = null; window.dispatchEvent(new HashChangeEvent('hashchange')); });
  return callbackExchange;
}

export async function signIn(auth: SupabaseClient, returnTo: '/#/home' | '/#/strategies' = '/#/strategies'): Promise<void> {
  try { sessionStorage.setItem(AUTH_RETURN_KEY, authReturnPath(returnTo)); } catch { /* OAuth still works; return to public Picks. */ }
  const { error } = await auth.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: `${location.origin}${AUTH_CALLBACK_PATH}` } });
  if (error) throw new Error('Google sign-in could not start. Try again.');
}
