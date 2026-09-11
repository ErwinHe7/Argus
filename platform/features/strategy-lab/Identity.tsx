import React, { createContext, useContext, useEffect, useState } from 'react';
import type { SupabaseClient, User } from '@supabase/supabase-js';
import { completeSignIn, strategyAuth } from './auth';
import { AUTH_CALLBACK_PATH, loadPublicConfig, type PublicConfig } from './config';

type Identity = {
  config: PublicConfig | null;
  auth: SupabaseClient | null;
  user: User | null;
  loading: boolean;
  error: string;
  retry: () => void;
};
const IdentityContext = createContext<Identity | null>(null);

// One session for the welcome page, navigation and strategy workspace. Identity
// display never grants permissions; the strategy API verifies every private call.
export function IdentityProvider({ children }: { children: React.ReactNode }) {
  const [config, setConfig] = useState<PublicConfig | null>(null);
  const [auth, setAuth] = useState<SupabaseClient | null>(null);
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [attempt, setAttempt] = useState(0);
  useEffect(() => {
    let disposed = false;
    let subscription: { unsubscribe: () => void } | undefined;
    const identity = (next: User | null) => {
      if (!disposed) setUser(next?.is_anonymous ? null : next);
    };
    setLoading(true); setError('');
    void (async () => {
      try {
        const settings = await loadPublicConfig();
        if (disposed) return;
        setConfig(settings);
        if (!settings.enabled) {
          setAuth(null); setUser(null);
          if (location.pathname === AUTH_CALLBACK_PATH) {
            history.replaceState(null, '', '/#/welcome');
            window.dispatchEvent(new HashChangeEvent('hashchange'));
          }
          return;
        }
        const instance = strategyAuth(settings);
        setAuth(instance);
        subscription = instance.auth.onAuthStateChange((_event, session) => identity(session?.user ?? null)).data.subscription;
        await completeSignIn(instance);
        const { data, error: sessionError } = await instance.auth.getSession();
        if (sessionError) throw new Error('Your sign-in could not be restored. Try again.');
        identity(data.session?.user ?? null);
      } catch (reason) {
        if (!disposed) setError(reason instanceof Error ? reason.message : 'Sign-in is unavailable. Try again.');
      } finally { if (!disposed) setLoading(false); }
    })();
    return () => { disposed = true; subscription?.unsubscribe(); };
  }, [attempt]);
  return <IdentityContext.Provider value={{ config, auth, user, loading, error, retry: () => setAttempt(value => value + 1) }}>{children}</IdentityContext.Provider>;
}

export function useIdentity(): Identity {
  const identity = useContext(IdentityContext);
  if (!identity) throw new Error('Leo identity provider is missing.');
  return identity;
}
