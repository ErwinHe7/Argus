import { cookies } from 'next/headers';
import { isSupabaseConfigured, supabaseServer } from './supabase';
import { createAxioHandle, GUEST_COOKIE, normalizeAxioHandle } from './guest-identity';

export { AXIO_HANDLE_PREFIX, createAxioHandle, GUEST_COOKIE, normalizeAxioHandle } from './guest-identity';

export type CurrentUser = {
  id: string;
  name: string;
  email: string | null;
  avatar: string | null;
  /** true when a real Supabase session is present; false for guest cookie fallback. */
  authenticated: boolean;
};

const DEFAULT_ADMIN_EMAILS = ['gh2722@columbia.edu'];

function adminEmails(): string[] {
  const fromEnv = process.env.ADMIN_EMAILS;
  const configured = fromEnv
    ? fromEnv
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .filter(Boolean)
    : [];
  return Array.from(new Set([...DEFAULT_ADMIN_EMAILS, ...configured]));
}

export function isAdmin(user: CurrentUser | null | undefined): boolean {
  if (!user?.authenticated || !user.email) return false;
  return adminEmails().includes(user.email.toLowerCase());
}

/**
 * Resolve the current user:
 *   1. If Supabase is configured AND the request carries a valid session → return real user
 *   2. Else → return a stable guest identity keyed off the `axio7_guest_id` cookie
 *      (cookie is set by middleware on first request)
 *
 * Use this from:
 *   - Route handlers (POST /api/posts, etc.) to stamp the write with the real author_id
 *   - Server Components (e.g. Nav) to show auth state
 *
 * Never throws — auth failures collapse to a guest identity so the app stays usable
 * when Supabase is mis-configured.
 */
export async function getCurrentUser(): Promise<CurrentUser> {
  if (isSupabaseConfigured()) {
    try {
      const { data } = await supabaseServer().auth.getUser();
      const u = data?.user;
      if (u) {
        const meta = (u.user_metadata ?? {}) as Record<string, any>;
        const name =
          (meta.full_name as string) ||
          (meta.name as string) ||
          (u.email ? u.email.split('@')[0] : null) ||
          'User';
        const avatar = (meta.avatar_url as string) || (meta.picture as string) || null;
        return {
          id: u.id,
          name,
          email: u.email ?? null,
          avatar,
          authenticated: true,
        };
      }
    } catch {
      // fall through to guest
    }
  }

  // Guest fallback. Middleware seeds the cookie; if missing, caller gets an
  // ephemeral id per-request (fine for demo writes).
  const guestId = normalizeAxioHandle(cookies().get(GUEST_COOKIE)?.value ?? createAxioHandle());
  return {
    id: guestId,
    name: guestId,
    email: null,
    avatar: `https://api.dicebear.com/9.x/thumbs/svg?seed=${encodeURIComponent(guestId)}`,
    authenticated: false,
  };
}
