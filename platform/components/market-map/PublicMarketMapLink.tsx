'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';

/** Keep the research entry absent until an actual, unexpired U.S. bundle exists. */
export function PublicMarketMapLink({ className }: { className?: string }) {
  const [available, setAvailable] = useState(false);
  useEffect(() => {
    const controller = new AbortController();
    let expiryTimer: ReturnType<typeof setTimeout> | undefined;
    const check = async () => {
      try {
        const response = await fetch('/api/market-map/status', { cache: 'no-store', signal: controller.signal });
        const status = response.ok ? await response.json() : null;
        if (controller.signal.aborted) return;
        clearTimeout(expiryTimer);
        const remaining = typeof status?.expires_at === 'string' ? Date.parse(status.expires_at) - Date.now() : 0;
        const valid = status?.available === true && remaining > 0;
        setAvailable(valid);
        if (valid) expiryTimer = setTimeout(() => setAvailable(false), Math.min(remaining, 2_147_483_647));
      } catch { if (!controller.signal.aborted) setAvailable(false); }
    };
    void check();
    const onVisible = () => { if (document.visibilityState === 'visible') void check(); };
    document.addEventListener('visibilitychange', onVisible);
    window.addEventListener('pageshow', onVisible);
    return () => { controller.abort(); clearTimeout(expiryTimer); document.removeEventListener('visibilitychange', onVisible); window.removeEventListener('pageshow', onVisible); };
  }, []);
  return available ? <Link href="/discover/market-map" className={className}>Market Map</Link> : null;
}
