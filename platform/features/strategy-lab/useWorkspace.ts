import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { StrategyStatus } from '../../../ritual-investing-api/src/domains/strategy-lab/contracts';
import { useIdentity } from './Identity';
import { StrategyApiError, StrategyClient } from './client';

export function useWorkspace() {
  const identity = useIdentity();
  const { config, auth, user, loading } = identity;
  const [snapshot, setSnapshot] = useState<StrategyStatus | null>(null);
  const [error, setError] = useState('');
  const [lastUpdated, setLastUpdated] = useState<string | null>(null);
  const [stale, setStale] = useState(false);
  const generation = useRef(0);
  const statusRequest = useRef(0);
  const api = useMemo(() => config?.enabled && auth ? new StrategyClient(config, auth) : null, [config, auth]);

  useEffect(() => {
    generation.current += 1;
    setSnapshot(null); setLastUpdated(null); setStale(false); setError('');
    return () => { generation.current += 1; };
  }, [user?.id]);

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

  // Hide a previous user's evidence during the render before effect cleanup.
  const currentSnapshot = user && snapshot?.membership.userId === user.id ? snapshot : null;
  return {config, auth, user, api, snapshot: currentSnapshot, error: identity.error || error, setError, loading, lastUpdated: currentSnapshot ? lastUpdated : null, stale, refresh};
}
