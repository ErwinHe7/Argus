'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { Apple, Loader2, LogIn, Mail } from 'lucide-react';
import { supabaseBrowser } from '@/lib/supabase-browser';
import { safeInternalRedirectPath } from '@/lib/safe-internal-redirect';

export const dynamic = 'force-dynamic';

const EMAIL_COOLDOWN_MS = 60_000;

function friendlyAuthError(message: string | null) {
  if (!message) return null;
  const lower = message.toLowerCase();
  if (lower.includes('unsupported provider') || lower.includes('provider is not enabled')) {
    return 'That sign-in method is temporarily unavailable. Continue with Google or email.';
  }
  if (lower.includes('rate limit')) {
    return 'Too many email sign-in links were requested. Please wait about a minute, then try again, or continue with Google.';
  }
  if (lower.includes('pkce') || lower.includes('code verifier')) {
    return 'That sign-in link was opened in a different browser session. Request a new email link here, then open it in this same browser. If QQ Mail opens its own browser, copy the link into Chrome/Safari.';
  }
  return message;
}

function cooldownKey(email: string) {
  return `axio7_magic_link_last_sent:${email.toLowerCase()}`;
}

export default function SignInPage() {
  const params = useSearchParams();
  const next = safeInternalRedirectPath(params.get('next'));
  const initialError = params.get('error');

  const [email, setEmail] = useState('');
  const [emailLoading, setEmailLoading] = useState(false);
  const [googleLoading, setGoogleLoading] = useState(false);
  const [appleLoading, setAppleLoading] = useState(false);
  const [appleAvailable, setAppleAvailable] = useState(false);
  const [providerAvailabilityLoaded, setProviderAvailabilityLoaded] = useState(false);
  const [error, setError] = useState<string | null>(friendlyAuthError(initialError));
  const [sentTo, setSentTo] = useState<string | null>(null);
  const [cooldownUntil, setCooldownUntil] = useState(0);
  const [now, setNow] = useState(Date.now());

  useEffect(() => {
    const id = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(id);
  }, []);

  useEffect(() => {
    let active = true;

    void fetch('/api/auth/providers', {
      cache: 'no-store',
      credentials: 'same-origin',
    })
      .then(async (response) => {
        const payload = (await response.json().catch(() => null)) as
          | { apple?: unknown }
          | null;
        if (active) setAppleAvailable(response.ok && payload?.apple === true);
      })
      .catch(() => {
        if (active) setAppleAvailable(false);
      })
      .finally(() => {
        if (active) setProviderAvailabilityLoaded(true);
      });

    return () => {
      active = false;
    };
  }, []);

  const secondsRemaining = Math.max(0, Math.ceil((cooldownUntil - now) / 1000));

  async function signInWithGoogle() {
    setError(null);
    setGoogleLoading(true);
    try {
      const supabase = supabaseBrowser();
      const redirectTo = `${window.location.origin}/auth/callback?next=${encodeURIComponent(next)}`;
      const { error } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: { redirectTo },
      });
      if (error) throw error;
    } catch (err: any) {
      setError(friendlyAuthError(err?.message) ?? 'Google sign-in failed.');
      setGoogleLoading(false);
    }
  }

  async function signInWithApple() {
    setError(null);
    setAppleLoading(true);
    try {
      const supabase = supabaseBrowser();
      const redirectTo = `${window.location.origin}/auth/callback?next=${encodeURIComponent(next)}`;
      const { error } = await supabase.auth.signInWithOAuth({
        provider: 'apple',
        options: { redirectTo },
      });
      if (error) throw error;
    } catch (err: any) {
      setError(friendlyAuthError(err?.message) ?? 'Apple sign-in failed.');
      setAppleLoading(false);
    }
  }

  async function signInWithEmail(e: React.FormEvent) {
    e.preventDefault();
    const normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail) return;

    const lastSent = Number(window.localStorage.getItem(cooldownKey(normalizedEmail)) ?? 0);
    const waitMs = lastSent + EMAIL_COOLDOWN_MS - Date.now();
    if (waitMs > 0) {
      const seconds = Math.ceil(waitMs / 1000);
      setCooldownUntil(lastSent + EMAIL_COOLDOWN_MS);
      setError(`Please wait ${seconds} seconds before requesting another email link.`);
      return;
    }

    setError(null);
    setEmailLoading(true);
    try {
      const supabase = supabaseBrowser();
      const emailRedirectTo = `${window.location.origin}/auth/callback?next=${encodeURIComponent(next)}`;
      const { error } = await supabase.auth.signInWithOtp({
        email: normalizedEmail,
        options: { emailRedirectTo },
      });
      if (error) throw error;
      const sentAt = Date.now();
      window.localStorage.setItem(cooldownKey(normalizedEmail), String(sentAt));
      setCooldownUntil(sentAt + EMAIL_COOLDOWN_MS);
      setSentTo(normalizedEmail);
    } catch (err: any) {
      const message = friendlyAuthError(err?.message) ?? 'Magic link failed.';
      if (message.toLowerCase().includes('too many email sign-in links')) {
        setCooldownUntil(Date.now() + EMAIL_COOLDOWN_MS);
      }
      setError(message);
    } finally {
      setEmailLoading(false);
    }
  }

  return (
    <div className="page-light flex min-h-[calc(100vh-64px)] items-center justify-center">
      <div className="axio-auth-card w-full max-w-md space-y-6 rounded-2xl p-6 sm:p-8">
        <div>
          <h1 className="axio-auth-title text-4xl tracking-tight" style={{ color: 'var(--ax-ink)' }}>Sign in to AXIO7</h1>
          <p className="mt-1 text-sm" style={{ color: 'var(--lt-muted)' }}>
            Save research conversations and monitors under your own identity, or continue as a guest.
          </p>
        </div>

        {error && (
          <div role="alert" className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
            {error}
          </div>
        )}

        {sentTo ? (
          <div role="status" className="rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-800">
            Magic link sent to <strong>{sentTo}</strong>. Open it in this same browser. If QQ Mail opens its own browser,
            copy the link into Chrome/Safari.
          </div>
        ) : (
          <>
            {appleAvailable ? (
              <button
                onClick={signInWithApple}
                disabled={appleLoading || googleLoading}
                className="flex min-h-11 w-full items-center justify-center gap-2 rounded-lg bg-black px-4 py-2.5 text-sm font-medium text-white shadow-sm transition hover:opacity-90 disabled:opacity-50"
              >
                {appleLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Apple className="h-4 w-4" />}
                Continue with Apple
              </button>
            ) : providerAvailabilityLoaded ? (
              <div role="status" className="rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-center text-xs text-amber-800">
                Apple sign-in is temporarily unavailable. Continue with Google or email.
              </div>
            ) : null}

            <button
              onClick={signInWithGoogle}
              disabled={googleLoading || appleLoading}
              className="flex min-h-11 w-full items-center justify-center gap-2 rounded-lg border px-4 py-2.5 text-sm font-medium shadow-sm transition hover:opacity-90 disabled:opacity-50"
              style={{ borderColor: 'var(--lt-border)', background: 'var(--lt-surface)', color: 'var(--lt-text)' }}
            >
              {googleLoading ? (
                <Loader2 className="h-4 w-4 animate-spin" />
              ) : (
                <GoogleG className="h-4 w-4" />
              )}
              Continue with Google
            </button>

            <div className="flex items-center gap-3">
              <div className="h-px flex-1" style={{ background: 'var(--lt-border)' }} />
              <span className="text-xs" style={{ color: 'var(--lt-subtle)' }}>or email me a link</span>
              <div className="h-px flex-1" style={{ background: 'var(--lt-border)' }} />
            </div>

            <form onSubmit={signInWithEmail} className="space-y-3">
              <label className="block text-sm">
                <span className="mb-1 block font-medium" style={{ color: 'var(--lt-text)' }}>Email</span>
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@columbia.edu"
                  className="w-full rounded-md border px-3 py-2 text-sm focus:outline-none"
                  style={{ borderColor: 'var(--lt-border)', background: 'var(--lt-surface)', color: 'var(--lt-text)' }}
                />
              </label>
              <button
                type="submit"
                disabled={emailLoading || !email.trim() || secondsRemaining > 0}
                className="inline-flex min-h-11 w-full items-center justify-center gap-2 rounded-lg bg-[var(--ax-accent)] px-4 py-2 text-sm font-medium text-white hover:opacity-90 disabled:opacity-50"
              >
                {emailLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Mail className="h-4 w-4" />}
                {secondsRemaining > 0 ? `Try again in ${secondsRemaining}s` : 'Send magic link'}
              </button>
            </form>
          </>
        )}

        <div className="pt-2 text-center text-xs" style={{ color: 'var(--lt-subtle)' }}>
          <Link href={next} className="inline-flex items-center gap-1 transition hover:opacity-70" style={{ color: 'var(--lt-muted)' }}>
            <LogIn className="h-3.5 w-3.5" /> Continue to research as guest
          </Link>
        </div>
      </div>
    </div>
  );
}

function GoogleG({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 48 48" aria-hidden>
      <path
        fill="#FFC107"
        d="M43.6 20.5H42V20H24v8h11.3C33.7 32.4 29.3 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20c11 0 20-8.9 20-20 0-1.3-.1-2.3-.4-3.5z"
      />
      <path
        fill="#FF3D00"
        d="M6.3 14.7l6.6 4.8C14.8 16 19 13 24 13c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6 29.3 4 24 4 16.3 4 9.7 8.4 6.3 14.7z"
      />
      <path
        fill="#4CAF50"
        d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2C29.2 34.7 26.7 36 24 36c-5.3 0-9.7-3.5-11.3-8.4l-6.5 5C9.6 39.6 16.2 44 24 44z"
      />
      <path
        fill="#1976D2"
        d="M43.6 20.5H42V20H24v8h11.3c-.8 2.3-2.3 4.3-4.1 5.8l6.2 5.2C40 36.5 44 31 44 24c0-1.3-.1-2.3-.4-3.5z"
      />
    </svg>
  );
}
