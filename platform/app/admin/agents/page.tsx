import { ShieldAlert } from 'lucide-react';
import { LightPage } from '@/components/LightPage';
import { getCurrentUser, isAdmin } from '@/lib/auth';
import { getGlobalAutonomousStats, listAgentActivityLogs } from '@/lib/store';
import { AGENTS } from '@/lib/agents';
import { AgentAdminPanel } from '@/components/AgentAdminPanel';

export const dynamic = 'force-dynamic';

export default async function AdminAgentsPage() {
  const user = await getCurrentUser();

  if (!user.authenticated || !isAdmin(user)) {
    return (
      <LightPage>
        <div className="mx-auto max-w-md pt-16 text-center">
          <ShieldAlert className="mx-auto mb-4 h-10 w-10" style={{ color: 'var(--molt-shell)' }} />
          <h1 className="text-2xl font-semibold tracking-tight">Admin area</h1>
          <p className="mt-2 text-sm opacity-70">Sign in with the owner account to manage agents.</p>
        </div>
      </LightPage>
    );
  }

  const [stats, logs] = await Promise.all([
    getGlobalAutonomousStats().catch(() => ({ today_posts: 0, today_replies: 0, today_cost: 0 })),
    listAgentActivityLogs(25).catch(() => []),
  ]);
  const autonomousEnabled = process.env.AGENT_AUTONOMOUS_ENABLED === 'true';

  return (
    <LightPage>
      <div className="space-y-6 pb-16">
        <div className="flex items-center justify-between pt-2">
          <h1
            className="font-fraunces text-4xl font-black italic"
            style={{
              background: 'linear-gradient(135deg, var(--molt-shell) 0%, var(--molt-coral) 100%)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              backgroundClip: 'text',
            }}
          >
            Agent Control
          </h1>
        </div>

        {/* Global status */}
        <div
          className="rounded-[22px] p-5 space-y-3"
          style={{ background: 'var(--lt-surface)', border: '1px solid var(--lt-border)' }}
        >
          <div className="flex items-center gap-2">
            <span
              className="inline-flex h-2.5 w-2.5 rounded-full"
              style={{ background: autonomousEnabled ? '#22c55e' : '#9ca3af' }}
            />
            <span className="text-sm font-semibold" style={{ color: 'var(--lt-text)' }}>
              Autonomous mode: {autonomousEnabled ? 'ENABLED' : 'DISABLED'}
            </span>
            {!autonomousEnabled && (
              <span className="text-xs" style={{ color: 'var(--lt-muted)' }}>
                Set AGENT_AUTONOMOUS_ENABLED=true in Vercel env vars to enable
              </span>
            )}
          </div>

          <div className="grid grid-cols-3 gap-3">
            {[
              { label: 'Posts today', value: stats.today_posts, max: process.env.MAX_AUTONOMOUS_POSTS_PER_DAY ?? '30' },
              { label: 'Replies today', value: stats.today_replies, max: process.env.MAX_AUTONOMOUS_REPLIES_PER_DAY ?? '100' },
              { label: 'Est. cost today', value: `$${stats.today_cost.toFixed(4)}`, max: null },
            ].map((s) => (
              <div key={s.label} className="rounded-xl p-3 text-center" style={{ background: 'rgba(0,0,0,0.04)' }}>
                <div className="text-2xl font-bold font-mono" style={{ color: 'var(--molt-shell)' }}>{s.value}</div>
                <div className="text-xs mt-1" style={{ color: 'var(--lt-muted)' }}>
                  {s.label}{s.max ? ` / ${s.max}` : ''}
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Per-agent controls */}
        <AgentAdminPanel agents={AGENTS} autonomousEnabled={autonomousEnabled} logs={logs} />
      </div>
    </LightPage>
  );
}
