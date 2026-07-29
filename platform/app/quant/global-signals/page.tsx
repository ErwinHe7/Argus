import type { Metadata } from 'next';
import Link from 'next/link';
import {
  AlertTriangle,
  ArrowLeft,
  BellRing,
  CheckCircle2,
  Crosshair,
  Database,
  ExternalLink,
  Gauge,
  ListChecks,
  RadioTower,
  ShieldAlert,
  Siren,
  TrendingDown,
  TrendingUp,
  Zap,
} from 'lucide-react';
import {
  buildGlobalSignalsReport,
  type AlertDeliveryConfig,
  type AlertLevel,
  type GlobalSignalEvent,
  type ProfessionalProvider,
  type PublicSignalSource,
  type RegionalWatchItem,
  type SignalScoreCard,
  type SourceTier,
  type TacticalPlaybookRule,
} from '@/lib/quant/global-signals';
import type { PriceAnomalyReport, PriceAnomalySignal } from '@/lib/quant/price-anomalies';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'AXIO7 Global Signal Radar',
  description: 'Professional-source global quant signal radar for macro, leverage, institutional and mega-cap shocks.',
};

export default async function GlobalSignalsPage() {
  const report = await buildGlobalSignalsReport({ includeReplay: true });
  const liveProviders = report.sources.filter((source) => source.status === 'ready');
  const criticalMissing = report.sources.filter(
    (source) => source.status === 'missing' && (source.tier === 'T0' || source.tier === 'T1')
  );

  return (
    <div className="-mx-4 -mb-24 -mt-6 min-h-screen bg-[#dfe4e8] px-4 pb-24 pt-0 text-slate-950 sm:-mx-6 sm:px-6 lg:-mx-8 lg:px-8">
      <main className="mx-auto min-h-screen max-w-[1440px] bg-[#07090d] px-4 py-5 text-white shadow-2xl shadow-black/35 sm:px-7">
        <TopBar />

        <section className="grid gap-4 xl:grid-cols-[1.1fr_0.9fr]">
          <header className="border border-slate-700 bg-[#10151e] p-5 sm:p-6">
            <p className="inline-flex items-center gap-2 border border-cyan-400/40 bg-cyan-500/10 px-2.5 py-1 font-mono text-[11px] font-black uppercase text-cyan-100">
              <Siren className="h-3.5 w-3.5" /> live war room
            </p>
            <h1 className="mt-4 max-w-4xl text-3xl font-black tracking-normal text-white sm:text-5xl">
              Korea memory tape to NQ/SMH risk radar
            </h1>
            <p className="mt-4 max-w-4xl text-sm leading-7 text-slate-300">
              This is not a pretty quote board. It is a premarket decision cockpit: Korea opens first, memory names lead, FX confirms stress,
              NQ transmits it, and US semis decide whether the move repairs or becomes a second-leg liquidation.
            </p>
            <div className="mt-5 grid gap-3 md:grid-cols-3">
              <HeroMetric label="regime" value={report.scores.regime} tone={levelTone(report.scores.level)} />
              <HeroMetric label="risk score" value={`${report.scores.marketRiskScore}/100`} tone={levelTone(report.scores.level)} />
              <HeroMetric label="live feeds" value={`${liveProviders.length}/${report.sources.length}`} />
            </div>
          </header>

          <NowPanel scores={report.scores} alertDelivery={report.alertDelivery} criticalMissing={criticalMissing.length} />
        </section>

        <section className="mt-4 grid gap-4 xl:grid-cols-[0.95fr_1.05fr]">
          <HowToUse />
          <ScoreConsole scores={report.scores} />
        </section>

        {report.providerWarnings.length ? <WarningStrip warnings={report.providerWarnings} /> : null}

        <PriceAnomalyEngine report={report.priceAnomalyReport} />

        <section className="mt-4 grid gap-4 xl:grid-cols-[1.15fr_0.85fr]">
          <AsiaSemiTape items={report.asiaSemiTape} />
          <Playbook rules={report.tacticalPlaybook} alertDelivery={report.alertDelivery} />
        </section>

        <section className="mt-4 grid gap-4 xl:grid-cols-[1.05fr_0.95fr]">
          <EventPanel
            title="Live Active Events"
            description="Only connected professional adapters appear here. Delayed retail pages are not promoted into live risk."
            events={report.activeEvents}
            empty="No live professional events yet. Configure providers and alerts before trusting the cockpit."
          />
          <EventPanel
            title="Replay Casebook"
            description="6.5-style macro / financing / Korea-memory scenarios used to sanity-check the scoring model. These never trigger alerts."
            events={report.replayEvents}
            empty="Replay disabled."
            replay
          />
        </section>

        <PublicSourceMatrix sources={report.publicSources} />
        <ProviderMatrix sources={report.sources} />
        <RulesPanel rules={report.rules} disclaimer={report.disclaimer} />
      </main>
    </div>
  );
}

function PriceAnomalyEngine({ report }: { report: PriceAnomalyReport }) {
  const topSignal = report.signals[0];
  return (
    <section className="mt-4 border border-slate-700 bg-[#080c13]">
      <div className="grid gap-0 xl:grid-cols-[0.82fr_1.18fr]">
        <div className="border-b border-slate-800 p-5 xl:border-b-0 xl:border-r">
          <p className="inline-flex items-center gap-2 font-mono text-[10px] font-black uppercase text-rose-200">
            <Zap className="h-3.5 w-3.5" /> price-led anomaly engine
          </p>
          <h2 className="mt-2 text-2xl font-black text-white">Tape first. Cause second. Orders locked.</h2>
          <p className="mt-3 text-xs leading-6 text-slate-400">
            This module watches abnormal price/flow before waiting for a clean headline. If the move is real, it then tries to attribute the cause
            through filings, company wires, newswire, macro, peers, and options stress.
          </p>
          <div className="mt-4 grid gap-2 sm:grid-cols-2">
            <HeroMetric label="mode" value={report.mode.replace(/_/g, ' ')} tone={report.sourceSummary.primaryTapeReady ? 'text-emerald-300' : 'text-amber-200'} />
            <HeroMetric label="primary tape" value={report.sourceSummary.primaryTapeReady ? 'ready' : 'needs feed'} tone={report.sourceSummary.primaryTapeReady ? 'text-emerald-300' : 'text-rose-200'} />
            <HeroMetric label="execution" value={`${report.executionPreference.primaryPlatform} / ${report.executionPreference.mode.replace(/_/g, ' ')}`} tone="text-cyan-200" />
            <HeroMetric label="paper auto" value={report.sourceSummary.paperAutomationEnabled ? 'enabled' : 'off'} />
            <HeroMetric label="live orders" value={report.sourceSummary.liveOrderLocked ? 'locked' : 'env unlocked'} tone={report.sourceSummary.liveOrderLocked ? 'text-amber-200' : 'text-rose-200'} />
          </div>
          <div className="mt-3 border border-cyan-400/20 bg-cyan-500/5 p-3 text-xs leading-6 text-cyan-50">
            {report.executionPreference.note}
          </div>
          <div className="mt-4 grid gap-2">
            {report.providers.map((provider) => (
              <div key={provider.id} className="grid grid-cols-[1fr_auto] gap-3 border border-slate-800 bg-black/60 p-3">
                <div>
                  <p className="text-xs font-black text-white">{provider.name}</p>
                  <p className="mt-1 text-[11px] leading-5 text-slate-500">{provider.role}</p>
                </div>
                <span className={`h-fit border px-2 py-1 font-mono text-[10px] font-black uppercase ${providerStatusTone(provider.status)}`}>
                  {provider.status.replace('_', ' ')}
                </span>
              </div>
            ))}
          </div>
        </div>

        <div className="p-5">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <p className="font-mono text-[10px] font-black uppercase text-slate-500">watchlist</p>
              <p className="mt-1 text-sm font-black text-slate-200">{report.universe.join(' / ')}</p>
            </div>
            <Link
              href="/api/quant/price-anomalies"
              className="inline-flex items-center gap-2 border border-slate-600 bg-slate-900 px-3 py-1.5 text-xs font-black text-slate-200 hover:bg-slate-800"
            >
              <Database className="h-3.5 w-3.5" /> Anomaly API
            </Link>
          </div>

          {topSignal ? (
            <div className="mt-4 grid gap-3">
              {report.signals.slice(0, 5).map((signal) => (
                <AnomalySignalCard key={signal.id} signal={signal} />
              ))}
            </div>
          ) : (
            <div className="mt-4 border border-dashed border-slate-700 bg-black/40 p-5 text-sm leading-6 text-slate-400">
              No live tape anomaly. Configure TotalView, Databento, Polygon/Massive, or IBKR market data before relying on this station.
            </div>
          )}
        </div>
      </div>
    </section>
  );
}

function AnomalySignalCard({ signal }: { signal: PriceAnomalySignal }) {
  return (
    <article className="border border-slate-800 bg-black p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p className="font-mono text-[10px] font-black uppercase text-slate-500">
            {signal.provider} / {signal.mode} / {signal.direction}
          </p>
          <h3 className="mt-1 text-base font-black text-white">
            {signal.ticker} {signal.level}
          </h3>
        </div>
        <div className={`border px-3 py-2 text-right ${anomalyLevelBox(signal.level)}`}>
          <p className="font-mono text-[10px] font-black uppercase">score</p>
          <p className="font-mono text-xl font-black">{signal.score}</p>
        </div>
      </div>
      <p className="mt-3 text-xs leading-6 text-slate-300">{signal.reason}</p>
      <p className="mt-2 border-l-2 border-cyan-400/60 pl-3 text-xs leading-6 text-cyan-100">{signal.likelyCause}</p>
      <div className="mt-3 grid gap-2 md:grid-cols-3">
        {signal.features.slice(0, 6).map((feature) => (
          <div key={feature.label} className="border border-slate-900 bg-[#080b10] p-3">
            <p className="font-mono text-[10px] font-black uppercase text-slate-500">{feature.label}</p>
            <p className="mt-1 font-mono text-sm font-black text-white">{feature.value}</p>
            <p className="mt-1 text-[11px] leading-5 text-slate-500">{feature.note}</p>
          </div>
        ))}
      </div>
      <div className="mt-3 grid gap-3 md:grid-cols-[1fr_0.85fr]">
        <div className="border border-slate-900 bg-[#080b10] p-3">
          <p className="font-mono text-[10px] font-black uppercase text-slate-500">same-type history</p>
          {signal.analogs.slice(0, 1).map((analog) => (
            <div key={analog.label} className="mt-2 text-[11px] leading-5 text-slate-400">
              <p className="font-bold text-slate-200">{analog.label}</p>
              <p className="mt-1">{analog.observedPattern}</p>
              <p className="mt-1 text-slate-500">Next: {analog.nextChecks.join(' / ')}</p>
            </div>
          ))}
        </div>
        <div className="border border-slate-900 bg-[#080b10] p-3">
          <p className="font-mono text-[10px] font-black uppercase text-slate-500">execution gate</p>
          <p className="mt-1 font-mono text-sm font-black text-white">{signal.execution.action}</p>
          <p className="mt-1 text-[11px] leading-5 text-slate-400">{signal.execution.rationale}</p>
          <p className="mt-2 font-mono text-[10px] font-black uppercase text-amber-200">
            {signal.execution.liveOrderAllowed ? 'live allowed by env' : 'live locked'}
          </p>
        </div>
      </div>
      <ManualExecutionTicketPanel signal={signal} />
    </article>
  );
}

function ManualExecutionTicketPanel({ signal }: { signal: PriceAnomalySignal }) {
  const ticket = signal.manualExecution;
  return (
    <div className="mt-3 border border-cyan-400/25 bg-cyan-500/5 p-3">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p className="font-mono text-[10px] font-black uppercase text-cyan-200">{ticket.platform} manual ticket</p>
          <h4 className="mt-1 text-sm font-black text-white">
            {ticket.ticker} / {ticket.side} / {ticket.orderStyle.replace(/_/g, ' ')}
          </h4>
        </div>
        <span className="border border-cyan-400/40 bg-black px-2 py-1 font-mono text-[10px] font-black uppercase text-cyan-100">
          {ticket.mode.replace(/_/g, ' ')}
        </span>
      </div>
      <div className="mt-3 grid gap-3 md:grid-cols-2">
        <div className="text-[11px] leading-5 text-slate-300">
          <p>
            <span className="font-black text-slate-100">Trigger:</span> {ticket.trigger}
          </p>
          <p className="mt-2">
            <span className="font-black text-slate-100">Invalidation:</span> {ticket.invalidation}
          </p>
          <p className="mt-2 text-amber-100">
            <span className="font-black">Size:</span> {ticket.sizeHint}
          </p>
        </div>
        <div className="space-y-1.5">
          {ticket.checklist.slice(0, 4).map((item) => (
            <p key={item} className="flex gap-2 text-[11px] leading-5 text-slate-300">
              <CheckCircle2 className="mt-0.5 h-3.5 w-3.5 shrink-0 text-cyan-200" />
              {item}
            </p>
          ))}
        </div>
      </div>
      <div className="mt-3 border-t border-cyan-400/10 pt-2">
        {ticket.warnings.slice(0, 2).map((warning) => (
          <p key={warning} className="flex gap-2 text-[11px] leading-5 text-amber-100">
            <AlertTriangle className="mt-0.5 h-3.5 w-3.5 shrink-0 text-amber-300" />
            {warning}
          </p>
        ))}
      </div>
    </div>
  );
}

function TopBar() {
  return (
    <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
      <Link href="/quant" className="inline-flex items-center gap-2 text-xs font-black text-slate-300 hover:text-white">
        <ArrowLeft className="h-4 w-4" /> Back to quant
      </Link>
      <div className="flex flex-wrap gap-2">
        <Link
          href="/api/quant/global-signals"
          className="inline-flex items-center gap-2 border border-slate-600 bg-slate-900 px-3 py-1.5 text-xs font-black text-slate-200 hover:bg-slate-800"
        >
          <Database className="h-3.5 w-3.5" /> JSON API
        </Link>
        <Link
          href="/api/cron/global-signal-alerts"
          className="inline-flex items-center gap-2 border border-slate-600 bg-slate-900 px-3 py-1.5 text-xs font-black text-slate-200 hover:bg-slate-800"
        >
          <BellRing className="h-3.5 w-3.5" /> Alert cron
        </Link>
      </div>
    </div>
  );
}

function providerStatusTone(status: PriceAnomalyReport['providers'][number]['status']): string {
  if (status === 'ready') return 'border-emerald-400/50 bg-emerald-500/10 text-emerald-200';
  if (status === 'adapter_pending') return 'border-cyan-400/50 bg-cyan-500/10 text-cyan-200';
  if (status === 'missing') return 'border-rose-400/50 bg-rose-500/10 text-rose-200';
  return 'border-slate-600 bg-slate-950 text-slate-500';
}

function anomalyLevelBox(level: PriceAnomalySignal['level']): string {
  if (level === 'RED') return 'border-rose-400/50 bg-rose-500/10 text-rose-200';
  if (level === 'ORANGE') return 'border-orange-400/50 bg-orange-500/10 text-orange-200';
  if (level === 'YELLOW') return 'border-amber-400/50 bg-amber-500/10 text-amber-200';
  if (level === 'LIGHT_YELLOW') return 'border-yellow-400/50 bg-yellow-500/10 text-yellow-100';
  return 'border-emerald-400/50 bg-emerald-500/10 text-emerald-200';
}

function NowPanel({
  scores,
  alertDelivery,
  criticalMissing,
}: {
  scores: SignalScoreCard;
  alertDelivery: AlertDeliveryConfig;
  criticalMissing: number;
}) {
  return (
    <section className={`border p-5 ${levelPanel(scores.level)}`}>
      <p className="inline-flex items-center gap-2 font-mono text-[11px] font-black uppercase">
        <Crosshair className="h-3.5 w-3.5" /> do this now
      </p>
      <h2 className="mt-3 text-2xl font-black">{scores.level}</h2>
      <p className="mt-3 text-sm leading-7">{scores.action}</p>
      <div className="mt-5 grid gap-2 text-xs leading-6">
        <p className="border border-black/20 bg-black/20 p-3">
          First check Korea: SK Hynix, Samsung, KOSPI/KOSDAQ, KRW. If this chain does not collapse, US semis can repair.
        </p>
        <p className="border border-black/20 bg-black/20 p-3">
          Then check US transmission: NQ futures, SOXX/SMH premarket, MU/SNDK/AVGO. No structure, no chase.
        </p>
        <p className="border border-black/20 bg-black/20 p-3">
          Alerts: {alertDelivery.enabled ? 'enabled' : 'disabled'} | targets:{' '}
          {alertDelivery.deliveryTargets.length ? alertDelivery.deliveryTargets.join(', ') : 'none'} | missing critical feeds: {criticalMissing}
        </p>
      </div>
    </section>
  );
}

function HowToUse() {
  const steps = [
    ['01 Asia open', 'Do not start with US premarket. Start with Hynix/Samsung, KOSPI/KOSDAQ, and KRW.'],
    ['02 Transmission', 'Use NQ futures and SMH/SOXX to decide whether Korea stress is spreading into US high beta.'],
    ['03 Trade filter', 'For dip buys, wait for no second-leg Korea liquidation, no US semi lower low, skew repair, and NQ/SMH reclaim.'],
    ['04 Notification', 'Set Telegram or webhook env vars. The cron route scans every 5 minutes on weekdays and pushes only threshold events.'],
  ];

  return (
    <section className="border border-slate-700 bg-[#0e141d] p-5">
      <p className="inline-flex items-center gap-2 font-mono text-[10px] font-black uppercase text-slate-400">
        <ListChecks className="h-3.5 w-3.5 text-emerald-300" /> how to use in 90 seconds
      </p>
      <div className="mt-4 grid gap-3 md:grid-cols-2">
        {steps.map(([label, text]) => (
          <div key={label} className="border border-slate-800 bg-black/35 p-4">
            <p className="font-mono text-[11px] font-black uppercase text-cyan-200">{label}</p>
            <p className="mt-2 text-xs leading-6 text-slate-300">{text}</p>
          </div>
        ))}
      </div>
    </section>
  );
}

function AsiaSemiTape({ items }: { items: RegionalWatchItem[] }) {
  return (
    <section className="border border-slate-700 bg-[#0b1018] p-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p className="inline-flex items-center gap-2 font-mono text-[10px] font-black uppercase text-cyan-200">
            <RadioTower className="h-3.5 w-3.5" /> asia semi tape
          </p>
          <h2 className="mt-2 text-2xl font-black text-white">Monday premarket checklist</h2>
          <p className="mt-2 max-w-3xl text-xs leading-6 text-slate-400">
            Watch this before the US cash open. If Korea holds, US semis may repair. If Korea opens into liquidation and Hynix/Samsung
            cannot hold, MU/SNDK/SMH/SOXX/NQ are likely under pressure.
          </p>
        </div>
      </div>
      <div className="mt-4 grid gap-3 md:grid-cols-2">
        {items.map((item) => (
          <WatchCard key={item.id} item={item} />
        ))}
      </div>
    </section>
  );
}

function WatchCard({ item }: { item: RegionalWatchItem }) {
  return (
    <article className="border border-slate-800 bg-black p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="font-mono text-[10px] font-black uppercase text-slate-500">{item.market}</p>
          <h3 className="mt-1 text-sm font-black text-white">{item.label}</h3>
        </div>
        <StatusPill ready={item.sourceStatus === 'ready'} />
      </div>
      <div className="mt-3 space-y-2 text-xs leading-6 text-slate-300">
        <p>
          <span className="font-black text-slate-100">Watch:</span> {item.whatToWatch}
        </p>
        <p>
          <span className="font-black text-rose-200">Risk-off:</span> {item.riskOffTrigger}
        </p>
        <p>
          <span className="font-black text-emerald-200">Repair:</span> {item.riskOnRepair}
        </p>
        <p className="border-t border-slate-900 pt-2 text-slate-400">{item.tradingRead}</p>
      </div>
      <div className="mt-3 flex flex-wrap gap-1.5">
        {item.affectedAssets.map((asset) => (
          <span key={asset} className="border border-slate-700 bg-[#111827] px-2 py-1 font-mono text-[10px] font-black text-slate-300">
            {asset}
          </span>
        ))}
      </div>
    </article>
  );
}

function Playbook({ rules, alertDelivery }: { rules: TacticalPlaybookRule[]; alertDelivery: AlertDeliveryConfig }) {
  return (
    <section className="grid gap-4">
      {rules.map((rule) => (
        <PlaybookRule key={rule.id} rule={rule} />
      ))}
      <AlertDeliveryPanel config={alertDelivery} />
    </section>
  );
}

function PlaybookRule({ rule }: { rule: TacticalPlaybookRule }) {
  const Icon = rule.side === 'dip_buy' ? TrendingUp : rule.side === 'short' ? TrendingDown : ShieldAlert;
  return (
    <article className="border border-slate-700 bg-[#10151e] p-5">
      <p className={`inline-flex items-center gap-2 font-mono text-[10px] font-black uppercase ${sideTone(rule.side)}`}>
        <Icon className="h-3.5 w-3.5" /> {rule.side.replace('_', ' ')}
      </p>
      <h3 className="mt-2 text-lg font-black text-white">{rule.title}</h3>
      <p className="mt-2 text-xs leading-6 text-slate-300">{rule.trigger}</p>
      <div className="mt-4 grid gap-3">
        <Checklist title="Confirmation" items={rule.confirmation} good />
        <Checklist title="Avoid" items={rule.avoid} />
        <Checklist title="Structures" items={rule.structures} good />
      </div>
    </article>
  );
}

function Checklist({ title, items, good }: { title: string; items: string[]; good?: boolean }) {
  return (
    <div>
      <p className="font-mono text-[10px] font-black uppercase text-slate-500">{title}</p>
      <div className="mt-2 space-y-1.5">
        {items.map((item) => (
          <p key={item} className="flex gap-2 text-xs leading-5 text-slate-300">
            {good ? (
              <CheckCircle2 className="mt-0.5 h-3.5 w-3.5 shrink-0 text-emerald-300" />
            ) : (
              <AlertTriangle className="mt-0.5 h-3.5 w-3.5 shrink-0 text-amber-300" />
            )}
            {item}
          </p>
        ))}
      </div>
    </div>
  );
}

function AlertDeliveryPanel({ config }: { config: AlertDeliveryConfig }) {
  return (
    <section className="border border-slate-700 bg-[#0b1018] p-5">
      <p className="inline-flex items-center gap-2 font-mono text-[10px] font-black uppercase text-emerald-300">
        <BellRing className="h-3.5 w-3.5" /> automatic warnings
      </p>
      <h3 className="mt-2 text-lg font-black text-white">{config.enabled ? 'Alert engine armed' : 'Alert engine not armed yet'}</h3>
      <div className="mt-3 grid gap-2 text-xs leading-6 text-slate-300">
        <p>Threshold: {config.minLevel} and {config.minScore}/100 minimum score.</p>
        <p>Cooldown: {config.cooldownMinutes} minutes. Redis cooldown: {config.redisCooldownConfigured ? 'on' : 'off'}.</p>
        <p>Targets: {config.deliveryTargets.length ? config.deliveryTargets.join(', ') : 'none configured'}.</p>
        {config.missingEnv.length ? <p className="text-amber-200">Missing: {config.missingEnv.join(' | ')}</p> : null}
        <p className="font-mono text-[11px] text-slate-500">{config.cronPath}</p>
      </div>
    </section>
  );
}

function ScoreConsole({ scores }: { scores: SignalScoreCard }) {
  const metrics: Array<[string, number]> = [
    ['Macro Hawk', scores.macroHawkScore],
    ['Leverage Unwind', scores.leverageUnwindScore],
    ['Global Contagion', scores.globalContagionScore],
    ['Mega-cap Shock', scores.megaCapShockScore],
    ['Options Stress', scores.optionsStressScore],
    ['Liquidity Stress', scores.liquidityStressScore],
    ['News Velocity', scores.newsVelocityScore],
    ['Fragility', scores.fragilityScore],
    ['Trigger', scores.triggerScore],
  ];
  return (
    <section className="border border-slate-700 bg-[#0e141d] p-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p className="inline-flex items-center gap-2 font-mono text-[10px] font-black uppercase text-slate-400">
            <Gauge className="h-3.5 w-3.5 text-emerald-300" /> risk model
          </p>
          <h2 className="mt-2 text-xl font-black text-white">{scores.level}</h2>
          <p className="mt-2 text-xs leading-6 text-slate-300">{scores.action}</p>
        </div>
        <div className={`border px-4 py-3 text-right ${levelBox(scores.level)}`}>
          <p className="font-mono text-[10px] font-black uppercase">Market Risk</p>
          <p className="mt-1 font-mono text-3xl font-black">{scores.marketRiskScore}</p>
        </div>
      </div>
      <div className="mt-5 space-y-2">
        {metrics.map(([label, value]) => (
          <ScoreBar key={label} label={label} value={value} />
        ))}
      </div>
    </section>
  );
}

function ScoreBar({ label, value }: { label: string; value: number }) {
  return (
    <div className="grid grid-cols-[116px_1fr_44px] items-center gap-3">
      <p className="font-mono text-[10px] font-black uppercase text-slate-400">{label}</p>
      <div className="h-5 border border-slate-800 bg-black">
        <div className={`h-full ${barColor(value)}`} style={{ width: `${Math.max(2, value)}%` }} />
      </div>
      <p className="text-right font-mono text-xs font-black text-white">{value}</p>
    </div>
  );
}

function WarningStrip({ warnings }: { warnings: string[] }) {
  return (
    <section className="mt-4 border border-amber-400/40 bg-amber-500/10 p-4">
      <p className="inline-flex items-center gap-2 font-mono text-[10px] font-black uppercase text-amber-200">
        <AlertTriangle className="h-3.5 w-3.5" /> provider gaps
      </p>
      <div className="mt-3 grid gap-2 md:grid-cols-2">
        {warnings.map((warning) => (
          <p key={warning} className="text-xs leading-6 text-amber-100">
            {warning}
          </p>
        ))}
      </div>
    </section>
  );
}

function EventPanel({
  title,
  description,
  events,
  empty,
  replay,
}: {
  title: string;
  description: string;
  events: GlobalSignalEvent[];
  empty: string;
  replay?: boolean;
}) {
  return (
    <section className="border border-slate-700 bg-[#0b1018] p-5">
      <p className={`inline-flex items-center gap-2 font-mono text-[10px] font-black uppercase ${replay ? 'text-amber-300' : 'text-emerald-300'}`}>
        <Zap className="h-3.5 w-3.5" /> {replay ? 'replay' : 'live'}
      </p>
      <h2 className="mt-2 text-xl font-black text-white">{title}</h2>
      <p className="mt-2 text-xs leading-6 text-slate-400">{description}</p>
      <div className="mt-4 space-y-3">
        {events.length ? (
          events.slice(0, 8).map((event) => <EventCard key={event.id} event={event} />)
        ) : (
          <div className="border border-dashed border-slate-700 bg-black/40 p-5 text-sm text-slate-400">{empty}</div>
        )}
      </div>
    </section>
  );
}

function EventCard({ event }: { event: GlobalSignalEvent }) {
  const impact = event.impactAssessment;
  return (
    <article className="border border-slate-800 bg-black p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p className="font-mono text-[10px] font-black uppercase text-slate-500">
            {event.sourceTier} / {event.confirmationStatus} / {event.eventType}
          </p>
          <h3 className="mt-1 text-sm font-black text-white">{event.title}</h3>
        </div>
        <div
          className={`border px-2 py-1 font-mono text-[11px] font-black ${
            event.direction === 'risk_off' ? 'border-rose-400/40 bg-rose-500/10 text-rose-200' : 'border-slate-600 bg-slate-900 text-slate-200'
          }`}
        >
          {event.severity}/{event.confidence}
        </div>
      </div>
      <p className="mt-2 text-xs leading-6 text-slate-300">{event.summary}</p>
      <div className="mt-3 flex flex-wrap gap-1.5">
        {event.affectedAssets.slice(0, 10).map((asset) => (
          <span key={asset} className="border border-slate-700 bg-[#111827] px-2 py-1 font-mono text-[10px] font-black text-slate-300">
            {asset}
          </span>
        ))}
      </div>
      <div className="mt-3 grid gap-2 text-[11px] leading-5 text-slate-400">
        <p>{event.transmission.join(' -> ')}</p>
        <p>
          Published {new Date(event.publishedAt).toLocaleString()} / latency{' '}
          {event.latencyMs === null ? 'n/a' : `${Math.round(event.latencyMs / 1000)}s`}
        </p>
      </div>
      {impact ? (
        <div className="mt-3 border border-slate-800 bg-[#080b10] p-3">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <p className="font-mono text-[10px] font-black uppercase text-slate-500">agent read</p>
            <span className={`border px-2 py-1 font-mono text-[10px] font-black uppercase ${biasTone(impact.bias)}`}>
              {impact.bias} / {impact.horizon}
            </span>
          </div>
          <div className="mt-2 space-y-1.5">
            {impact.reasoning.slice(0, 2).map((line) => (
              <p key={line} className="text-[11px] leading-5 text-slate-300">
                {line}
              </p>
            ))}
          </div>
          {impact.historicalAnalogs.length ? (
            <div className="mt-3 border-t border-slate-900 pt-2">
              <p className="font-mono text-[10px] font-black uppercase text-slate-500">same-type history</p>
              {impact.historicalAnalogs.slice(0, 2).map((analog) => (
                <p key={analog.label} className="mt-1 text-[11px] leading-5 text-slate-400">
                  <span className="font-bold text-slate-200">{analog.label}:</span> {analog.usualMarketImpact}
                </p>
              ))}
            </div>
          ) : null}
        </div>
      ) : null}
      {event.evidence.some((e) => e.url) ? (
        <div className="mt-2 flex flex-wrap gap-2">
          {event.evidence
            .filter((e) => e.url)
            .slice(0, 2)
            .map((evidence) => (
              <a key={evidence.label} href={evidence.url} target="_blank" rel="noreferrer" className="inline-flex items-center gap-1 text-[11px] font-bold text-cyan-200 hover:text-cyan-100">
                {evidence.label} <ExternalLink className="h-3 w-3" />
              </a>
            ))}
        </div>
      ) : null}
    </article>
  );
}

function PublicSourceMatrix({ sources }: { sources: PublicSignalSource[] }) {
  return (
    <section className="mt-4 border border-slate-700 bg-[#0b1018] p-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p className="inline-flex items-center gap-2 font-mono text-[10px] font-black uppercase text-emerald-300">
            <RadioTower className="h-3.5 w-3.5" /> public first-source mesh
          </p>
          <h2 className="mt-2 text-xl font-black text-white">Official public sources plus context wires</h2>
        </div>
        <p className="max-w-xl text-xs leading-6 text-slate-400">
          Official .gov / SEC / issuer sources can confirm. NYT, Jin10, and broad public indexes are fast context, not official confirmation.
        </p>
      </div>
      <div className="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-3">
        {sources.map((source) => (
          <article key={source.id} className="border border-slate-800 bg-black p-4">
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="font-mono text-[10px] font-black uppercase text-slate-500">
                  {source.tier} / {source.kind.replace('_', ' ')}
                </p>
                <h3 className="mt-1 text-sm font-black text-white">{source.name}</h3>
              </div>
              <StatusPill ready={source.active} />
            </div>
            <p className="mt-3 text-xs leading-6 text-slate-300">{source.role}</p>
            <p className="mt-2 text-[11px] leading-5 text-slate-500">{source.marketUse}</p>
            <p className="mt-2 text-[11px] leading-5 text-slate-400">{source.confirmationRole}</p>
            <div className="mt-3 flex flex-wrap gap-1.5">
              {source.env.length ? (
                source.env.map((env) => (
                  <span key={env} className="border border-slate-700 bg-[#111827] px-2 py-1 font-mono text-[10px] font-black text-slate-300">
                    {env}
                  </span>
                ))
              ) : (
                <span className="border border-emerald-400/40 bg-emerald-500/10 px-2 py-1 font-mono text-[10px] font-black text-emerald-200">
                  no key
                </span>
              )}
            </div>
          </article>
        ))}
      </div>
    </section>
  );
}

function ProviderMatrix({ sources }: { sources: ProfessionalProvider[] }) {
  return (
    <section className="mt-4 border border-slate-700 bg-[#0b1018] p-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p className="inline-flex items-center gap-2 font-mono text-[10px] font-black uppercase text-slate-400">
            <RadioTower className="h-3.5 w-3.5 text-cyan-200" /> professional data matrix
          </p>
          <h2 className="mt-2 text-xl font-black text-white">Low-latency sources, no Yahoo-style primary data</h2>
        </div>
        <p className="max-w-xl text-xs leading-6 text-slate-400">
          T0/T1 sources are allowed to drive alerts. T2 confirms broker/account risk. T3/T4 can inform context but cannot trigger RED alone.
        </p>
      </div>
      <div className="mt-4 overflow-x-auto">
        <table className="w-full min-w-[1180px] border-collapse text-left text-[12px]">
          <thead>
            <tr className="border-b border-slate-700 font-mono text-[10px] uppercase text-slate-400">
              <th className="px-2 py-2.5">Tier</th>
              <th className="px-2 py-2.5">Provider</th>
              <th className="px-2 py-2.5">Role</th>
              <th className="px-2 py-2.5 text-right">Latency</th>
              <th className="px-2 py-2.5">Status</th>
              <th className="px-2 py-2.5">Env</th>
            </tr>
          </thead>
          <tbody>
            {sources.map((source) => (
              <ProviderRow key={source.id} source={source} />
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}

function ProviderRow({ source }: { source: ProfessionalProvider }) {
  return (
    <tr className="border-b border-slate-800 text-slate-200">
      <td className="px-2 py-3">
        <TierBadge tier={source.tier} />
      </td>
      <td className="px-2 py-3">
        <p className="font-bold text-white">{source.name}</p>
        <p className="mt-1 text-[11px] leading-5 text-slate-500">{source.whyItMatters}</p>
      </td>
      <td className="max-w-[320px] px-2 py-3 text-xs leading-5 text-slate-300">{source.role}</td>
      <td className="px-2 py-3 text-right font-mono text-xs font-black text-slate-100">{source.latencyTargetMs}ms</td>
      <td className="px-2 py-3">
        <StatusBadge status={source.status} />
      </td>
      <td className="max-w-[280px] px-2 py-3 font-mono text-[11px] leading-5 text-slate-400">
        {source.env.length ? source.env.join(', ') : 'none'}
      </td>
    </tr>
  );
}

function RulesPanel({ rules, disclaimer }: { rules: string[]; disclaimer: string }) {
  return (
    <section className="mt-4 grid gap-4 lg:grid-cols-[1fr_0.9fr]">
      <div className="border border-slate-700 bg-[#0b1018] p-5">
        <h2 className="text-xl font-black text-white">Hard Rules</h2>
        <ul className="mt-3 space-y-2">
          {rules.map((rule) => (
            <li key={rule} className="flex gap-2 text-xs leading-6 text-slate-300">
              <ShieldAlert className="mt-1 h-3.5 w-3.5 shrink-0 text-emerald-300" />
              {rule}
            </li>
          ))}
        </ul>
      </div>
      <div className="border border-slate-700 bg-black p-5 text-xs leading-6 text-slate-400">
        <h2 className="text-xl font-black text-white">Disclosure</h2>
        <p className="mt-3">{disclaimer}</p>
      </div>
    </section>
  );
}

function HeroMetric({ label, value, tone = 'text-white' }: { label: string; value: string; tone?: string }) {
  return (
    <div className="border border-slate-700 bg-[#06080d] px-4 py-3">
      <p className="font-mono text-[10px] font-black uppercase text-slate-500">{label}</p>
      <p className={`mt-1 break-words font-mono text-sm font-black ${tone}`}>{value}</p>
    </div>
  );
}

function StatusPill({ ready }: { ready: boolean }) {
  return (
    <span
      className={`shrink-0 border px-2 py-1 font-mono text-[10px] font-black uppercase ${
        ready ? 'border-emerald-400/50 bg-emerald-500/10 text-emerald-200' : 'border-amber-400/50 bg-amber-500/10 text-amber-200'
      }`}
    >
      {ready ? 'live' : 'needs feed'}
    </span>
  );
}

function TierBadge({ tier }: { tier: SourceTier }) {
  const styles: Record<SourceTier, string> = {
    T0: 'border-emerald-400/50 bg-emerald-500/10 text-emerald-200',
    T1: 'border-cyan-400/50 bg-cyan-500/10 text-cyan-200',
    T2: 'border-sky-400/50 bg-sky-500/10 text-sky-200',
    T3: 'border-amber-400/50 bg-amber-500/10 text-amber-200',
    T4: 'border-slate-600 bg-slate-900 text-slate-300',
  };
  return <span className={`border px-2 py-1 font-mono text-[10px] font-black ${styles[tier]}`}>{tier}</span>;
}

function StatusBadge({ status }: { status: ProfessionalProvider['status'] }) {
  const styles: Record<ProfessionalProvider['status'], string> = {
    ready: 'border-emerald-400/50 bg-emerald-500/10 text-emerald-200',
    missing: 'border-rose-400/50 bg-rose-500/10 text-rose-200',
    optional: 'border-slate-600 bg-slate-900 text-slate-300',
    disabled: 'border-slate-600 bg-slate-950 text-slate-500',
  };
  return <span className={`border px-2 py-1 font-mono text-[10px] font-black uppercase ${styles[status]}`}>{status}</span>;
}

function levelTone(level: AlertLevel): string {
  if (level === 'RED') return 'text-rose-300';
  if (level === 'ORANGE') return 'text-orange-300';
  if (level === 'YELLOW') return 'text-amber-300';
  if (level === 'LIGHT_YELLOW') return 'text-yellow-200';
  return 'text-emerald-300';
}

function levelPanel(level: AlertLevel): string {
  if (level === 'RED') return 'border-rose-400/60 bg-rose-950/80 text-rose-50';
  if (level === 'ORANGE') return 'border-orange-400/60 bg-orange-950/70 text-orange-50';
  if (level === 'YELLOW') return 'border-amber-400/50 bg-amber-950/60 text-amber-50';
  if (level === 'LIGHT_YELLOW') return 'border-yellow-400/50 bg-yellow-950/50 text-yellow-50';
  return 'border-emerald-400/40 bg-emerald-950/55 text-emerald-50';
}

function levelBox(level: AlertLevel): string {
  if (level === 'RED') return 'border-rose-400/50 bg-rose-500/10 text-rose-200';
  if (level === 'ORANGE') return 'border-orange-400/50 bg-orange-500/10 text-orange-200';
  if (level === 'YELLOW') return 'border-amber-400/50 bg-amber-500/10 text-amber-200';
  if (level === 'LIGHT_YELLOW') return 'border-yellow-400/50 bg-yellow-500/10 text-yellow-100';
  return 'border-emerald-400/50 bg-emerald-500/10 text-emerald-200';
}

function sideTone(side: TacticalPlaybookRule['side']): string {
  if (side === 'dip_buy') return 'text-emerald-300';
  if (side === 'short') return 'text-rose-300';
  return 'text-cyan-200';
}

function biasTone(bias: NonNullable<GlobalSignalEvent['impactAssessment']>['bias']): string {
  if (bias === 'bearish') return 'border-rose-400/50 bg-rose-500/10 text-rose-200';
  if (bias === 'bullish') return 'border-emerald-400/50 bg-emerald-500/10 text-emerald-200';
  if (bias === 'mixed') return 'border-amber-400/50 bg-amber-500/10 text-amber-200';
  return 'border-slate-600 bg-slate-900 text-slate-300';
}

function barColor(value: number): string {
  if (value >= 85) return 'bg-rose-500';
  if (value >= 70) return 'bg-orange-400';
  if (value >= 50) return 'bg-amber-300';
  if (value >= 30) return 'bg-yellow-200';
  return 'bg-emerald-400';
}
