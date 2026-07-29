'use client';

import { useEffect, useRef } from 'react';
import posthog from 'posthog-js';
import { PostHogProvider as PHProvider } from 'posthog-js/react';

const posthogKey = process.env.NEXT_PUBLIC_POSTHOG_KEY;
const posthogHost = process.env.NEXT_PUBLIC_POSTHOG_HOST || 'https://app.posthog.com';

let initialized = false;

function initPostHog() {
  if (initialized || !posthogKey || typeof window === 'undefined') return;
  posthog.init(posthogKey, {
    api_host: posthogHost,
    capture_pageview: true,
    capture_pageleave: true,
    autocapture: false,
    person_profiles: 'identified_only',
  });
  initialized = true;
}

export function PostHogProvider({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    initPostHog();
  }, []);

  if (!posthogKey) return <>{children}</>;
  initPostHog();
  return <PHProvider client={posthog}>{children}</PHProvider>;
}

// --- Event helpers (call from client components) ---

export function trackPostCreated(payload: {
  user_id: string;
  post_id: string;
  post_length: number;
  has_image: boolean;
}) {
  if (!posthogKey || typeof window === 'undefined') return;
  try {
    posthog.capture('post_created', payload);
  } catch {}
}

export function trackReplyViewed(payload: {
  user_id: string;
  post_id: string;
  agent_name: string;
}) {
  if (!posthogKey || typeof window === 'undefined') return;
  try {
    posthog.capture('reply_viewed', payload);
  } catch {}
}

export function identifyUser(userId: string, traits: { signup_date?: string }) {
  if (!posthogKey || typeof window === 'undefined') return;
  try {
    posthog.identify(userId, traits);
  } catch {}
}

export function trackUserReturned() {
  if (!posthogKey || typeof window === 'undefined') return;
  try {
    const lastSeen = localStorage.getItem('axio7_last_seen');
    const now = Date.now();
    if (lastSeen && now - Number(lastSeen) > 24 * 60 * 60 * 1000) {
      posthog.capture('user_returned');
    }
    localStorage.setItem('axio7_last_seen', String(now));
  } catch {}
}
