'use client';

import { useEffect } from 'react';
import { supabaseBrowser } from '@/lib/supabase-browser';
import { identifyUser, trackUserReturned } from '@/components/PostHogProvider';

export function PostHogSession() {
  useEffect(() => {
    trackUserReturned();

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
