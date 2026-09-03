'use client';

import { useEffect, useState } from 'react';
import { CheckCircle2, ExternalLink, Settings, X } from 'lucide-react';

type SourceRow = {
  id: string;
  name: string;
  productionReady?: boolean;
  enabled?: boolean;
  mode?: string;
};

type Payload = {
  sources: SourceRow[];
  summary?: { total: number; productionReady: number };
};

// Direct signup / docs links for each provider that AXIO7 supports.
// Cost column = cheapest viable plan to unlock the source in production.
const PROVIDERS: Array<{
  envVar: string;
  matchSourceId: string;
  label: string;
  unlocks: string;
  cost: string;
  url: string;
  priority: 'critical' | 'high' | 'medium';
}> = [
  {
    envVar: 'POLYGON_API_KEY',
    matchSourceId: 'polygon',
    label: 'Polygon.io',
    unlocks: '期权链 OI / Max Pain / Greeks / 实时报价（Vercel datacenter IP 友好）',
    cost: 'Free 5 req/min · Starter $79/mo 无限',
    url: 'https://polygon.io/dashboard/signup',
    priority: 'critical',
  },
  {
    envVar: 'FINNHUB_API_KEY',
    matchSourceId: 'market-tape',
    label: 'Finnhub',
    unlocks: '免费股票 quote、市场 tape、公司新闻（60 req/min 免费）',
    cost: 'Free 60 req/min',
    url: 'https://finnhub.io/register',
    priority: 'high',
  },
  {
    envVar: 'X_BEARER_TOKEN',
    matchSourceId: 'x-recent',
    label: 'X API v2',
    unlocks: 'Trump / Elon / Jensen / Unusual Whales 等 influencer 直播流',
    cost: 'Free tier 1500 reads/mo · Basic $200/mo',
    url: 'https://developer.x.com/en/portal/petition/essential/basic-info',
    priority: 'high',
  },
  {
    envVar: 'REDDIT_CLIENT_ID',
    matchSourceId: 'reddit',
    label: 'Reddit OAuth',
    unlocks: 'WSB / options / stocks 帖子情绪扫描',
    cost: '完全免费 (60 req/min)',
    url: 'https://www.reddit.com/prefs/apps',
    priority: 'medium',
  },
  {
    envVar: 'NEWSAPI_KEY',
    matchSourceId: 'newsapi',
    label: 'NewsAPI',
    unlocks: '主流财经新闻聚合（CNBC / WSJ / Yahoo / AP 等）',
    cost: 'Free 100 req/day · Business $449/mo',
    url: 'https://newsapi.org/register',
    priority: 'medium',
  },
  {
    envVar: 'TRUTH_SOCIAL_PROVIDER_URL',
    matchSourceId: 'truth-vendor',
    label: 'Truth Social vendor',
    unlocks: 'Trump on Truth Social（Dataminr 等授权 vendor，无公开 API）',
    cost: 'Vendor-bespoke · 默认 manual paste 即可',
    url: 'https://help.truthsocial.com/legal/terms-of-service/',
    priority: 'medium',
  },
];

const STORAGE_KEY = 'axio7_setup_hints_dismissed_v1';

export function MarketSetupHints() {
  const [data, setData] = useState<Payload | null>(null);
  const [dismissed, setDismissed] = useState(false);

  useEffect(() => {
    if (typeof window !== 'undefined') {
      setDismissed(window.localStorage.getItem(STORAGE_KEY) === '1');
    }
    fetch('/api/market/sources', { cache: 'no-store' })
      .then((r) => r.json())
      .then((d) => setData(d))
      .catch(() => undefined);
  }, []);

  function dismiss() {
    if (typeof window !== 'undefined') {
      window.localStorage.setItem(STORAGE_KEY, '1');
    }
    setDismissed(true);
  }

  if (dismissed || !data) return null;

  const liveIds = new Set(data.sources.filter((s) => s.productionReady).map((s) => s.id));
  const missing = PROVIDERS.filter((p) => !liveIds.has(p.matchSourceId));

  if (missing.length === 0) return null;

  const critical = missing.filter((m) => m.priority === 'critical');
  const high = missing.filter((m) => m.priority === 'high');
  const medium = missing.filter((m) => m.priority === 'medium');

  return (
    <section className="rounded-[10px] border border-amber-400/40 bg-amber-500/5 p-5">
      <header className="mb-3 flex items-start justify-between gap-3">
        <div className="flex items-start gap-3">
          <Settings className="mt-0.5 h-5 w-5 shrink-0 text-amber-300" />
          <div>
            <h2 className="text-base font-black text-white">
              {data.summary?.productionReady ?? 0}/{data.summary?.total ?? 15} 数据源已生产就绪 · {missing.length} 个等待配置
            </h2>
            <p className="mt-1 text-xs leading-5 text-slate-200">
              下面是缺失数据源的免费 / 低成本签到链接。配好 env 写进 Vercel 后 cron 下一轮自动启用。
            </p>
          </div>
        </div>
        <button
          type="button"
          onClick={dismiss}
          className="rounded p-1 text-slate-400 hover:bg-slate-800 hover:text-slate-100"
          title="dismiss"
        >
          <X className="h-4 w-4" />
        </button>
      </header>

      {critical.length ? (
        <div className="mb-3">
          <div className="mb-1.5 inline-flex items-center gap-1 rounded border border-red-400/40 bg-red-500/15 px-2 py-0.5 text-[10px] font-black uppercase tracking-[0.14em] text-red-100">
            critical · 阻塞期权分析
          </div>
          <div className="grid gap-2 sm:grid-cols-1">
            {critical.map((p) => (
              <ProviderRow key={p.envVar} provider={p} tone="critical" />
            ))}
          </div>
        </div>
      ) : null}

      {high.length ? (
        <div className="mb-3">
          <div className="mb-1.5 inline-flex items-center gap-1 rounded border border-amber-400/40 bg-amber-500/15 px-2 py-0.5 text-[10px] font-black uppercase tracking-[0.14em] text-amber-100">
            high · 显著提升信号覆盖
          </div>
          <div className="grid gap-2 sm:grid-cols-2">
            {high.map((p) => (
              <ProviderRow key={p.envVar} provider={p} tone="high" />
            ))}
          </div>
        </div>
      ) : null}

      {medium.length ? (
        <div>
          <div className="mb-1.5 inline-flex items-center gap-1 rounded border border-slate-600 bg-slate-800 px-2 py-0.5 text-[10px] font-black uppercase tracking-[0.14em] text-slate-200">
            medium · 锦上添花
          </div>
          <div className="grid gap-2 sm:grid-cols-3">
            {medium.map((p) => (
              <ProviderRow key={p.envVar} provider={p} tone="medium" />
            ))}
          </div>
        </div>
      ) : null}

      <p className="mt-4 border-t border-slate-800 pt-3 text-[11px] leading-5 text-slate-300">
        <CheckCircle2 className="mr-1 inline h-3 w-3 text-emerald-300" />
        申请到 key 后：在 Vercel project → Settings → Environment Variables 添加 → Redeploy。无需改代码。
      </p>
    </section>
  );
}

function ProviderRow({
  provider,
  tone,
}: {
  provider: typeof PROVIDERS[number];
  tone: 'critical' | 'high' | 'medium';
}) {
  const borderCls =
    tone === 'critical'
      ? 'border-red-400/40 hover:border-red-400/70'
      : tone === 'high'
        ? 'border-amber-400/40 hover:border-amber-400/70'
        : 'border-slate-700 hover:border-slate-500';
  return (
    <a
      href={provider.url}
      target="_blank"
      rel="noreferrer"
      className={`group block rounded-[6px] border bg-slate-950 p-3 transition ${borderCls}`}
    >
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0 flex-1">
          <p className="text-sm font-black text-white">
            {provider.label}
            <code className="ml-2 font-mono text-[10px] text-amber-200">{provider.envVar}</code>
          </p>
          <p className="mt-1 text-xs leading-5 text-slate-200">{provider.unlocks}</p>
          <p className="mt-1 text-[11px] text-slate-400">{provider.cost}</p>
        </div>
        <ExternalLink className="mt-1 h-3.5 w-3.5 shrink-0 text-slate-400 transition group-hover:text-white" />
      </div>
    </a>
  );
}
