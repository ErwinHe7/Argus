import Link from 'next/link';
import { LogIn, ShieldAlert } from 'lucide-react';
import { LightPage } from '@/components/LightPage';
import { getCurrentUser, isAdmin } from '@/lib/auth';

export const dynamic = 'force-dynamic';

const cardLinks = [
  {
    label: 'Realtime · who is on the site right now',
    href: 'https://analytics.google.com/analytics/web/#/p0/realtime/overview',
    hint: 'Live users, top pages, traffic sources (last 30 min)',
  },
  {
    label: 'Reports · traffic acquisition',
    href: 'https://analytics.google.com/analytics/web/#/p0/reports/explorer?params=_u..nav%3Dmaui&r=all-pages-and-screens',
    hint: 'Where visitors came from: Google, direct, social, referrals',
  },
  {
    label: 'Reports · engagement & pages',
    href: 'https://analytics.google.com/analytics/web/#/p0/reports/explorer?params=_u..nav%3Dmaui&r=all-pages-and-screens',
    hint: 'PV, sessions, average engagement time per page',
  },
  {
    label: 'Explore · custom funnels / UV',
    href: 'https://analytics.google.com/analytics/web/#/p0/analysis',
    hint: 'Build your own reports: UV by country, cohort retention, funnels',
  },
];

export default async function AdminAnalyticsPage() {
  const user = await getCurrentUser();
  const authed = user.authenticated;
  const admin = isAdmin(user);

  if (!authed) {
    return (
      <LightPage>
        <div className="mx-auto max-w-md pt-16 text-center">
          <ShieldAlert className="mx-auto mb-4 h-10 w-10 text-[color:var(--molt-shell)]" />
          <h1 className="text-2xl font-semibold tracking-tight">Admin area</h1>
          <p className="mt-2 text-sm opacity-70">
            Sign in with the owner account to view site analytics.
          </p>
          <Link
            href="/auth/signin?redirect=/admin/analytics"
            className="mt-6 inline-flex items-center gap-1.5 rounded-lg px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:opacity-90"
            style={{ background: 'var(--molt-shell)' }}
          >
            <LogIn className="h-4 w-4" /> Sign in
          </Link>
        </div>
      </LightPage>
    );
  }

  if (!admin) {
    return (
      <LightPage>
        <div className="mx-auto max-w-md pt-16 text-center">
          <ShieldAlert className="mx-auto mb-4 h-10 w-10 text-[color:var(--molt-shell)]" />
          <h1 className="text-2xl font-semibold tracking-tight">Not authorized</h1>
          <p className="mt-2 text-sm opacity-70">
            Signed in as <span className="font-mono">{user.email ?? user.name}</span>. This page is
            restricted to the site owner.
          </p>
        </div>
      </LightPage>
    );
  }

  const gaId = process.env.NEXT_PUBLIC_GA_ID;
  const lookerEmbed = process.env.NEXT_PUBLIC_LOOKER_STUDIO_EMBED;
  const tracking = Boolean(gaId);

  return (
    <LightPage>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Admin · Analytics</h1>
          <p className="mt-1 text-sm opacity-70">
            Google Analytics 4 backend for <span className="font-mono">{user.email}</span>.
            Data shows up ~30 seconds after first visit once{' '}
            <code className="rounded bg-black/10 px-1 py-0.5 text-xs">NEXT_PUBLIC_GA_ID</code>{' '}
            is set.
          </p>
        </div>

        <div
          className={`rounded-xl border p-4 text-sm ${
            tracking
              ? 'border-emerald-300/60 bg-emerald-100/60 text-emerald-900'
              : 'border-amber-300/60 bg-amber-100/60 text-amber-900'
          }`}
        >
          {tracking ? (
            <>
              Tracking active — Measurement ID{' '}
              <code className="rounded bg-white/70 px-1 py-0.5 text-xs">{gaId}</code>
            </>
          ) : (
            <>
              <strong>Tracking not set up.</strong> Create a GA4 property at{' '}
              <a
                className="underline"
                href="https://analytics.google.com"
                target="_blank"
                rel="noreferrer"
              >
                analytics.google.com
              </a>
              , copy the Measurement ID (starts with <code>G-</code>), and set{' '}
              <code className="rounded bg-white/70 px-1 py-0.5 text-xs">NEXT_PUBLIC_GA_ID</code>{' '}
              in Vercel → Settings → Environment Variables. Redeploy and come back.
            </>
          )}
        </div>

        <div className="grid gap-3 sm:grid-cols-2">
          {cardLinks.map((c) => (
            <a
              key={c.href}
              href={c.href}
              target="_blank"
              rel="noreferrer"
              className="block rounded-xl border border-black/10 bg-white/70 p-4 transition hover:border-black/20 hover:bg-white hover:shadow-sm"
            >
              <div className="font-medium">{c.label}</div>
              <div className="mt-1 text-xs opacity-70">{c.hint}</div>
            </a>
          ))}
        </div>

        <div className="rounded-xl border border-black/10 bg-white/70 p-4">
          <div className="mb-2 text-sm font-medium">Embedded dashboard</div>
          {lookerEmbed ? (
            <div className="aspect-video w-full overflow-hidden rounded-lg border border-black/10">
              <iframe
                src={lookerEmbed}
                className="h-full w-full"
                allowFullScreen
                title="Looker Studio dashboard"
              />
            </div>
          ) : (
            <p className="text-xs opacity-70">
              Build a Looker Studio report from your GA4 data (free) at{' '}
              <a
                className="underline"
                href="https://lookerstudio.google.com"
                target="_blank"
                rel="noreferrer"
              >
                lookerstudio.google.com
              </a>
              , click <em>Share → Embed report</em>, copy the URL, and set{' '}
              <code className="rounded bg-black/10 px-1 py-0.5 text-xs">
                NEXT_PUBLIC_LOOKER_STUDIO_EMBED
              </code>{' '}
              to see UV / PV / sources / retention rendered right here.
            </p>
          )}
        </div>

        <div className="rounded-xl border border-black/10 bg-white/70 p-4 text-xs opacity-75">
          <div className="mb-1 font-medium opacity-100">What GA4 tracks automatically</div>
          Page views, sessions, users, engagement time, scrolls, outbound clicks, site search,
          video engagement, file downloads, country/device/browser, traffic source. No code
          changes needed — just keep the env var set.
        </div>
      </div>
    </LightPage>
  );
}
