import Link from 'next/link';
import { BarChart3, BookOpen, Gavel, GraduationCap, LogIn, ShieldCheck } from 'lucide-react';
import { LightPage } from '@/components/LightPage';
import { getCurrentUser, isAdmin } from '@/lib/auth';
import { DisplayNameEditor } from '@/components/DisplayNameEditor';

export const dynamic = 'force-dynamic';

export default async function ProfilePage() {
  const user = await getCurrentUser();
  const admin = isAdmin(user);

  return (
    <LightPage>
      <div className="space-y-6">
        <div className="rounded-[22px] p-5" style={{ background: 'var(--lt-surface)', border: '1px solid var(--lt-border)' }}>
          {user.authenticated ? (
            <div className="flex items-center gap-4">
              {user.avatar ? (
                <img src={user.avatar} alt="" className="h-14 w-14 rounded-full ring-2" />
              ) : (
                <div className="flex h-14 w-14 items-center justify-center rounded-full text-2xl font-bold text-white" style={{ background: 'var(--molt-shell)' }}>
                  {user.name[0].toUpperCase()}
                </div>
              )}
              <div className="min-w-0 flex-1">
                <p className="text-lg font-semibold" style={{ color: 'var(--lt-text)' }}>{user.name}</p>
                {user.email && <p className="text-sm" style={{ color: 'var(--lt-muted)' }}>{user.email}</p>}
                <DisplayNameEditor />
                <div className="mt-2 flex flex-wrap gap-3 text-xs">
                  <a href="/auth/signout" className="underline" style={{ color: 'var(--lt-muted)' }}>Sign out</a>
                  <Link href="/account/delete" className="underline" style={{ color: '#b42318' }}>Delete account</Link>
                </div>
              </div>
            </div>
          ) : (
            <div className="flex items-center justify-between gap-4">
              <div>
                <p className="font-medium" style={{ color: 'var(--lt-text)' }}>You are browsing as a guest</p>
                <p className="mt-0.5 text-sm" style={{ color: 'var(--lt-muted)' }}>Sign in to preserve lesson progress and saved notes.</p>
              </div>
              <Link href="/auth/signin" className="education-button education-button-primary">
                <LogIn className="h-4 w-4" /> Sign in
              </Link>
            </div>
          )}
        </div>

        <div className="grid gap-4 lg:grid-cols-2">
          <section className="rounded-[22px] p-5" style={{ background: 'var(--lt-surface)', border: '1px solid var(--lt-border)' }}>
            <div className="flex items-center gap-2">
              <GraduationCap className="h-5 w-5 text-[var(--molt-shell)]" />
              <h2 className="text-lg font-semibold tracking-tight" style={{ color: 'var(--lt-text)' }}>Your learning path</h2>
            </div>
            <p className="mt-2 text-sm leading-6" style={{ color: 'var(--lt-muted)' }}>
              Start with evidence foundations, then continue through source reading, timeline building, historical review, and reflection practice.
            </p>
            <div className="mt-4 space-y-2 text-sm" style={{ color: 'var(--lt-muted)' }}>
              <p>01 · How evidence is organized</p>
              <p>02 · Read the source, not the headline</p>
              <p>03 · Build a careful timeline</p>
              <p>04 · Write a balanced reflection</p>
            </div>
            <Link href="/learn" className="education-button education-button-primary mt-4"><BookOpen className="h-4 w-4" /> Open curriculum</Link>
          </section>

          <section className="rounded-[22px] p-5" style={{ background: 'var(--lt-surface)', border: '1px solid var(--lt-border)' }}>
            <div className="flex items-center gap-2">
              <ShieldCheck className="h-5 w-5 text-emerald-700" />
              <h2 className="text-lg font-semibold tracking-tight" style={{ color: 'var(--lt-text)' }}>Education boundary</h2>
            </div>
            <p className="mt-2 text-sm leading-6" style={{ color: 'var(--lt-muted)' }}>
              AXIO7 teaches general concepts using historical, fictional, or generalized examples. The workspace is designed
              for self-paced learning, source reading, timeline notes, and retrospective review.
            </p>
            <div className="mt-4 flex flex-wrap gap-2 text-xs" style={{ color: 'var(--lt-muted)' }}>
              <span className="rounded-full bg-black/5 px-3 py-1">Educational purpose</span>
              <span className="rounded-full bg-black/5 px-3 py-1">Historical review</span>
              <span className="rounded-full bg-black/5 px-3 py-1">Public sources</span>
              <span className="rounded-full bg-black/5 px-3 py-1">Reflection practice</span>
            </div>
            <Link href="/terms" className="education-button education-button-secondary mt-4">Read terms</Link>
          </section>
        </div>

        {admin && (
          <div className="rounded-[22px] p-5" style={{ background: 'var(--lt-surface)', border: '1px solid var(--lt-border)' }}>
            <div className="mb-3 flex items-center gap-2">
              <h2 className="text-lg font-semibold tracking-tight" style={{ color: 'var(--lt-text)' }}>Admin</h2>
              <span className="rounded-full bg-black/10 px-2 py-0.5 text-[10px] font-medium uppercase tracking-wide" style={{ color: 'var(--lt-muted)' }}>Owner only</span>
            </div>
            <div className="grid gap-2 sm:grid-cols-2">
              <Link href="/admin/analytics" className="flex items-start gap-3 rounded-xl border border-black/10 bg-white/70 p-3 transition hover:border-black/20 hover:bg-white">
                <BarChart3 className="mt-0.5 h-5 w-5" style={{ color: 'var(--molt-shell)' }} />
                <div><div className="font-medium" style={{ color: 'var(--lt-text)' }}>Analytics</div><div className="text-xs" style={{ color: 'var(--lt-muted)' }}>Learning-page and acquisition analytics</div></div>
              </Link>
              <Link href="/admin/review" className="flex items-start gap-3 rounded-xl border border-black/10 bg-white/70 p-3 transition hover:border-black/20 hover:bg-white">
                <Gavel className="mt-0.5 h-5 w-5" style={{ color: 'var(--molt-shell)' }} />
                <div><div className="font-medium" style={{ color: 'var(--lt-text)' }}>Review queue</div><div className="text-xs" style={{ color: 'var(--lt-muted)' }}>Review learner reports and content flags</div></div>
              </Link>
            </div>
          </div>
        )}
      </div>
    </LightPage>
  );
}
