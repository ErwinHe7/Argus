import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { SupabaseClient, User } from '@supabase/supabase-js';
import type { StrategyStatus } from '../../../ritual-investing-api/src/domains/strategy-lab/contracts';
import { completeSignIn, strategyAuth } from './auth';
import { loadPublicConfig, type PublicConfig } from './config';
import { StrategyApiError, StrategyClient } from './client';

export function useWorkspace() {
  const [config, setConfig] = useState<PublicConfig | null>(null);
  const [auth, setAuth] = useState<SupabaseClient | null>(null);
  const [user, setUser] = useState<User | null>(null);
  const [snapshot, setSnapshot] = useState<StrategyStatus | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const [lastUpdated, setLastUpdated] = useState<string | null>(null);
  const [stale, setStale] = useState(false);
  const generation = useRef(0);
  const statusRequest = useRef(0);
  const activeUser = useRef<string | null>(null);
  const api = useMemo(() => config?.enabled && auth ? new StrategyClient(config, auth) : null, [config, auth]);

  useEffect(() => {
    let disposed = false;
    let subscription: {unsubscribe: () => void} | undefined;
    const identity = (next: User | null) => {
      if (disposed) return;
      const real = next?.is_anonymous ? null : next;
      if (activeUser.current !== (real?.id ?? null)) {
        generation.current += 1;
        activeUser.current = real?.id ?? null;
        setSnapshot(null); setLastUpdated(null); setStale(false);
      }
      setUser(real);
    };
    void (async () => {
      try {
        const settings = await loadPublicConfig();
        if (disposed) return;
        setConfig(settings);
        if (!settings.enabled) {
          if (location.pathname === '/strategy-auth/callback') history.replaceState(null, '', '/#/strategies');
          return;
        }
        const instance = strategyAuth(settings);
        setAuth(instance);
        subscription = instance.auth.onAuthStateChange((_event, session) => identity(session?.user ?? null)).data.subscription;
        await completeSignIn(instance);
        const {data, error: sessionError} = await instance.auth.getSession();
        if (sessionError) throw new Error('Your sign-in could not be restored. Sign in again.');
        identity(data.session?.user ?? null);
      } catch (reason) { if (!disposed) setError(reason instanceof Error ? reason.message : 'Strategy settings could not be loaded.'); }
      finally { if (!disposed) setLoading(false); }
    })();
    return () => { disposed = true; generation.current += 1; subscription?.unsubscribe(); };
  }, []);

  const refresh = useCallback(async () => {
    if (!api || !user) return;
    const version = generation.current;
    const request = ++statusRequest.current;
    try {
      const next = await api.status();
      if (version !== generation.current || request !== statusRequest.current) return;
      if (next.membership.userId !== user.id) throw new StrategyApiError(403, 'The server identity did not match this session. Sign out and sign in again.');
      setSnapshot(next); setLastUpdated(new Date().toISOString()); setStale(false); setError('');
    } catch (reason) {
      if (version !== generation.current || request !== statusRequest.current) return;
      setStale(true);
      if (reason instanceof StrategyApiError && [401, 403].includes(reason.status)) { setSnapshot(null); setLastUpdated(null); }
      setError(reason instanceof StrategyApiError ? reason.message : 'The strategy response could not be validated. Last reported values are preserved.');
    }
  }, [api, user]);

  useEffect(() => {
    if (!api || !user) return;
    let running = false;
    const poll = async () => { if (running) return; running = true; try { await refresh(); } finally { running = false; } };
    void poll();
    const timer = setInterval(() => { void poll(); }, 5_000);
    return () => { clearInterval(timer); };
  }, [api, user, refresh]);

  return {config, auth, user, api, snapshot, error, setError, loading, lastUpdated, stale, refresh};
}
