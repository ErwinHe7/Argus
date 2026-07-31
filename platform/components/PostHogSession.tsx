'use client';

import { useEffect } from 'react';
import { supabaseBrowser } from '@/lib/supabase-browser';
import {
  identifyUser,
  trackProductEvent,
  trackUserReturned,
} from '@/components/PostHogProvider';
import {
  ACQUISITION_ATTRIBUTION_COOKIE,
  normalizeAcquisitionAttribution,
  parseAcquisitionAttributionCookie,
} from '@/lib/observability/acquisition-attribution';

const ATTRIBUTION_STORAGE_KEY = 'axio7_acquisition_v1';
const LANDING_SESSION_KEY = 'axio7_landing_viewed_v1';

function captureFirstTouch() {
  const cookieAttribution = parseAcquisitionAttributionCookie(
    document.cookie
      .split('; ')
      .find((entry) => entry.startsWith(`${ACQUISITION_ATTRIBUTION_COOKIE}=`))
      ?.slice(ACQUISITION_ATTRIBUTION_COOKIE.length + 1)
  );
  if (Object.keys(cookieAttribution).length > 0) return cookieAttribution;

  try {
    const storedAttribution = parseAcquisitionAttributionCookie(
      window.localStorage.getItem(ATTRIBUTION_STORAGE_KEY) ?? undefined
    );
    if (Object.keys(storedAttribution).length > 0) return storedAttribution;
  } catch {}

  const params = new URLSearchParams(window.location.search);
  let referrerHost: string | undefined;
  try {
    referrerHost = document.referrer
      ? new URL(document.referrer).hostname.toLowerCase()
      : undefined;
  } catch {
    referrerHost = undefined;
  }
  const attribution = normalizeAcquisitionAttribution({
    utm_source: params.get('utm_source'),
    utm_medium: params.get('utm_medium'),
    utm_campaign: params.get('utm_campaign'),
    utm_content: params.get('utm_content'),
    utm_term: params.get('utm_term'),
    referrer_host: referrerHost,
    landing_path: window.location.pathname,
  });
  if (Object.keys(attribution).length === 0) return attribution;

  const serialized = JSON.stringify(attribution);
  try {
    window.localStorage.setItem(ATTRIBUTION_STORAGE_KEY, serialized);
  } catch {}
  const secure = window.location.protocol === 'https:' ? '; Secure' : '';
  document.cookie = `${ACQUISITION_ATTRIBUTION_COOKIE}=${encodeURIComponent(serialized)}; Path=/; Max-Age=2592000; SameSite=Lax${secure}`;
  return attribution;
}

export function PostHogSession() {
  useEffect(() => {
    trackUserReturned();

    const attribution = captureFirstTouch();
    if (
      window.location.pathname === '/' &&
      !window.sessionStorage.getItem(LANDING_SESSION_KEY)
    ) {
      window.sessionStorage.setItem(LANDING_SESSION_KEY, '1');
      trackProductEvent('acquisition_landing_viewed', attribution);
    }

    if (
      !process.env.NEXT_PUBLIC_SUPABASE_URL ||
      !process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
    ) {
      return;
    }
    supabaseBrowser().auth.getUser().then(({ data }) => {
      const u = data?.user;
      if (!u) return;
      identifyUser(u.id, {
        signup_date: u.created_at,
      });
    }).catch(() => {});
  }, []);

  return null;
}
