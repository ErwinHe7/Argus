import { createBrowserClient } from '@supabase/ssr';

/**
 * Client-side Supabase client. Must live in its own file so it is NOT imported
 * alongside server-only modules (next/headers, service role key, etc.).
 *
 * Use from `'use client'` components only (signin page, like buttons, etc.).
 */
export function supabaseBrowser() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
  return createBrowserClient(url, anonKey);
}
