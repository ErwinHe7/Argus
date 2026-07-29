'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { WifiOff } from 'lucide-react';
import { MobileTabBar } from './MobileTabBar';

const nativeKey = 'axio7_native_ios';

function detectNativeMode() {
  if (typeof window === 'undefined') return false;
  const params = new URLSearchParams(window.location.search);
  if (params.get('native') === 'ios') {
    window.localStorage.setItem(nativeKey, 'true');
    return true;
  }
  return window.localStorage.getItem(nativeKey) === 'true' || /AXIO7-iOS|Capacitor/i.test(window.navigator.userAgent);
}

function routeFromIncomingUrl(rawUrl: string) {
  try {
    const incoming = new URL(rawUrl);
    if (incoming.protocol === 'axio7:') {
      const path = incoming.hostname ? `/${incoming.hostname}${incoming.pathname}` : incoming.pathname;
      if (path.startsWith('/signal/')) return '/market';
      if (path === '/strategy' || path === '/market' || path === '/inbox') return path === '/strategy' ? '/market' : path;
      return '/market';
    }
    if (incoming.hostname === 'axio7.com' || incoming.hostname.endsWith('.axio7.com')) {
      return `${incoming.pathname}${incoming.search}`;
    }
  } catch {}
  return null;
}

export function NativeAppBridge() {
  const router = useRouter();
  const [native, setNative] = useState(false);
  const [offline, setOffline] = useState(false);

  useEffect(() => {
    const enabled = detectNativeMode();
    setNative(enabled);
    document.body.dataset.nativeIos = enabled ? 'true' : 'false';
  }, []);

  useEffect(() => {
    if (!native) return;

    async function setupExternalLinks() {
      document.addEventListener('click', async (event) => {
        const target = event.target as HTMLElement | null;
        const anchor = target?.closest('a[href]') as HTMLAnchorElement | null;
        if (!anchor) return;
        const href = anchor.getAttribute('href');
        if (!href || href.startsWith('#') || href.startsWith('/') || href.startsWith('mailto:') || href.startsWith('tel:')) return;

        try {
          const url = new URL(href, window.location.origin);
          const internal = url.hostname === window.location.hostname || url.hostname === 'axio7.com' || url.hostname.endsWith('.axio7.com');
          if (internal) return;
          event.preventDefault();
          const { Browser } = await import('@capacitor/browser');
          await Browser.open({ url: url.toString(), presentationStyle: 'popover' });
        } catch {}
      });
    }

    setupExternalLinks();
  }, [native]);

  useEffect(() => {
    if (!native) return;
    let cleanup: (() => void) | undefined;

    async function setupNativeEvents() {
      try {
        const [{ App }, { Network }] = await Promise.all([
          import('@capacitor/app'),
          import('@capacitor/network'),
        ]);

        const status = await Network.getStatus();
        setOffline(!status.connected);

        const networkListener = await Network.addListener('networkStatusChange', (state) => setOffline(!state.connected));
        const urlListener = await App.addListener('appUrlOpen', (event) => {
          const route = routeFromIncomingUrl(event.url);
          if (route) router.push(route);
        });

        cleanup = () => {
          networkListener.remove();
          urlListener.remove();
        };
      } catch {}
    }

    setupNativeEvents();
    return () => cleanup?.();
  }, [native, router]);

  if (!native) return null;

  return (
    <>
      {offline && (
        <div className="native-offline-banner" role="status">
          <WifiOff className="h-4 w-4" />
          <span>No connection. Check your network and retry.</span>
          <button onClick={() => window.location.reload()}>Retry</button>
        </div>
      )}
      <MobileTabBar />
    </>
  );
}
