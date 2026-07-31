import type { Metadata } from 'next';
import Link from 'next/link';
import { ArrowRight, BarChart3, Database, ShieldCheck } from 'lucide-react';
import { LightPage } from '@/components/LightPage';

export const metadata: Metadata = {
  title: 'Sector Rotation Research - Cloud, Semiconductors, Software & Mag 7 | AXIO7',
  description:
    'Learn how AXIO7 evaluates cloud, semiconductor, software, Magnificent Seven, and broad-sector leadership with point-in-time data and walk-forward validation.',
  alternates: { canonical: '/research/sector-rotation' },
};

const GROUPS = [
  ['Magnificent Seven', 'MAGS is used as an explicit ETF proxy; it is not presented as reconstructed constituent history.'],
  ['Cloud computing', 'SKYY is evaluated relative to the broad market at the completed-session cutoff.'],
  ['Semiconductors', 'SOXX captures semiconductor leadership without treating one company as the whole industry.'],
  ['Software', 'IGV separates software leadership from the wider technology sector.'],
  ['Broad sectors', 'XLK, XLC, XLY, XLF, XLE, XLI, XLV, XLP, XLU, XLRE, and XLB form the rotation breadth basket.'],
] as const;

export default function SectorRotationResearchPage() {
  return (
    <LightPage>
      <main className="mx-auto max-w-5xl space-y-7 px-4 py-10 sm:px-6 sm:py-14">
        <section className="rounded-[28px] border p-7 sm:p-10" style={{ background: 'var(--lt-surface)', borderColor: 'var(--lt-border)' }}>
          <p className="text-xs font-bold uppercase tracking-[0.22em]" style={{ color: 'var(--lt-muted)' }}>
            AXIO7 research methodology
          </p>
          <h1 className="mt-3 max-w-3xl text-4xl font-black tracking-tight sm:text-5xl" style={{ color: 'var(--lt-text)' }}>
            Which sector is leading today—and is that leadership durable?
          </h1>
          <p className="mt-5 max-w-3xl text-base leading-7" style={{ color: 'var(--lt-muted)' }}>
            AXIO7 treats “today&apos;s sector” as a measurable market state, not a story. The research layer compares completed-session leadership, breadth, dispersion, and growth-versus-defensive rotation before it evaluates historical analogs.
          </p>
          <div className="mt-7 flex flex-wrap gap-3">
            <Link href="/" className="r-btn-pink inline-flex items-center gap-2">
              Open the research workspace <ArrowRight className="h-4 w-4" />
            </Link>
            <Link href="/pricing" className="r-btn-ghost">View membership plans</Link>
          </div>
        </section>

        <section className="grid gap-4 md:grid-cols-3">
          <MethodCard icon={<BarChart3 className="h-5 w-5" />} title="Six causal features">
            Relative Mag 7, cloud, and software returns; sector leadership breadth; sector return dispersion; and growth-versus-defensive rotation.
          </MethodCard>
          <MethodCard icon={<Database className="h-5 w-5" />} title="Point-in-time inputs">
            Every row must have source identity, event time, availability time, session-edge coverage, and an observation cutoff before it can enter a result.
          </MethodCard>
          <MethodCard icon={<ShieldCheck className="h-5 w-5" />} title="No automatic promotion">
            A challenger must beat the same baseline queries in purged walk-forward evaluation, then pass untouched holdout and forward-shadow review.
          </MethodCard>
        </section>

        <section className="rounded-[26px] border p-6 sm:p-8" style={{ background: 'var(--lt-surface)', borderColor: 'var(--lt-border)' }}>
          <h2 className="text-2xl font-black" style={{ color: 'var(--lt-text)' }}>The rotation map</h2>
          <div className="mt-5 grid gap-4 sm:grid-cols-2">
            {GROUPS.map(([name, description]) => (
              <article key={name} className="rounded-2xl border p-5" style={{ borderColor: 'var(--lt-border)' }}>
                <h3 className="font-bold" style={{ color: 'var(--lt-text)' }}>{name}</h3>
                <p className="mt-2 text-sm leading-6" style={{ color: 'var(--lt-muted)' }}>{description}</p>
              </article>
            ))}
          </div>
        </section>

        <section className="rounded-[26px] border p-6 text-sm leading-7 sm:p-8" style={{ background: 'var(--lt-surface)', borderColor: 'var(--lt-border)', color: 'var(--lt-muted)' }}>
          <h2 className="text-2xl font-black" style={{ color: 'var(--lt-text)' }}>What a published report must show</h2>
          <p className="mt-3">
            A report must expose its provider, observation cutoff, availability time, freshness, coverage, feature version, historical sample boundary, validation status, and material caveats. Missing or stale sector coverage fails closed rather than being replaced with synthetic or unrelated data.
          </p>
          <p className="mt-3">
            This page explains methodology. It is not a current market signal, investment advice, a personalized recommendation, or an execution service.
          </p>
        </section>
      </main>
    </LightPage>
  );
}

function MethodCard({
  icon,
  title,
  children,
}: {
  icon: React.ReactNode;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <article className="rounded-[22px] border p-5" style={{ background: 'var(--lt-surface)', borderColor: 'var(--lt-border)' }}>
      <div className="flex items-center gap-2 font-bold" style={{ color: 'var(--lt-text)' }}>
        {icon}
        <h2>{title}</h2>
      </div>
      <p className="mt-3 text-sm leading-6" style={{ color: 'var(--lt-muted)' }}>{children}</p>
    </article>
  );
}
