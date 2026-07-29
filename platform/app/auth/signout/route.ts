import { NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase';
import { authRedirectOrigin } from '@/lib/auth-redirect-origin';
import { safeInternalRedirectPath } from '@/lib/safe-internal-redirect';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

/** Sign the current user out and return them to `?next` (default: "/"). */
export async function POST(req: Request) {
  const url = new URL(req.url);
  const publicOrigin = authRedirectOrigin(req);
  const next = safeInternalRedirectPath(url.searchParams.get('next'));
  try {
    await supabaseServer().auth.signOut();
  } catch {
    // even if sign-out fails server-side, we still redirect; the middleware
    // will see the cookies as stale on next request.
  }
  const target = new URL(next, publicOrigin);
  return NextResponse.redirect(target, { status: 303 });
}

export async function GET(req: Request) {
  // allow plain-link sign-out too (e.g. `<a href="/auth/signout">Sign out</a>`)
  return POST(req);
}
