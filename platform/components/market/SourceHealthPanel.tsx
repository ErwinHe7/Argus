'use client';

import { useEffect, useState } from 'react';
import { Activity, Loader2, ShieldCheck, Wifi, WifiOff } from 'lucide-react';

type SourceRow = {
  id: string;
  name: string;
  kind: string;
  access: string;
  mode?: string;
  enabled?: boolean;
  productionReady?: boolean;
  coverage?: string;
  setup?: string;
};

type SourcesPayload = {
  generatedAt: string;
  sources: SourceRow[];
  summary?: { total: number; productionReady: number };
};

export function SourceHealthPanel() {
  const [data, setData] = useState<SourcesPayload | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    fetch('/api/market/sources')
      .then((r) => r.json())
      .then((d) => {
        if (!cancelled) {
          if (d.error) setError(d.error);
          else setData(d);
        }
      })
      .catch((e) => {
        if (!cancelled) setError(e instanceof Error ? e.message : 'fetch failed');
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <section className="rounded-[10px] border border-slate-700 bg-slate-900 p-6 shadow-2xl shadow-black/30">
      <header className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <ShieldCheck className="h-5 w-5 text-blue-300" />
          <h2 className="text-xl font-black text-white">数据源健康度</h2>
        </div>
        {data?.summary ? (
          <span className="rounded-[6px] border border-slate-700 bg-black px-3 py-1.5 text-xs font-black text-slate-100">
            {data.summary.productionReady}/{data.summary.total} 已生产就绪
          </span>
        ) : null}
      </header>

      {loading ? (
        <div className="flex items-center gap-2 text-sm text-slate-200">
          <Loader2 className="h-4 w-4 animate-spin" /> 检测数据源连接...
        </div>
      ) : null}

      {error ? (
        <div className="rounded-[8px] border border-red-400/40 bg-red-950/60 p-3 text-sm text-red-100">{error}</div>
      ) : null}

      {data ? (
        <div className="overflow-hidden rounded-[8px] border border-slate-700 bg-slate-950">
          <div className="overflow-x-auto">
            <table className="w-full min-w-[640px] text-left text-sm">
              <thead className="bg-black/40">
                <tr className="text-xs font-black uppercase tracking-[0.12em] text-slate-200">
                  <th className="border-b border-slate-700 py-3 pl-4 pr-3">Source</th>
                  <th className="border-b border-slate-700 py-3 pr-3">Kind</th>
                  <th className="border-b border-slate-700 py-3 pr-3">Access</th>
                  <th className="border-b border-slate-700 py-3 pr-3">Mode</th>
                  <th className="border-b border-slate-700 py-3 pr-3">Status</th>
                  <th className="border-b border-slate-700 py-3 pr-4">Setup</th>
                </tr>
              </thead>
              <tbody>
                {data.sources.map((s, idx) => (
                  <tr
                    key={s.id}
                    className={`text-slate-100 ${idx % 2 === 1 ? 'bg-black/30' : ''}`}
                  >
                    <td className="border-b border-slate-800 py-3 pl-4 pr-3">
                      <p className="font-black text-white">{s.name}</p>
                      <p className="font-mono text-[10px] text-slate-400">{s.id}</p>
                    </td>
                    <td className="border-b border-slate-800 py-3 pr-3 font-mono text-xs text-slate-200">{s.kind}</td>
                    <td className="border-b border-slate-800 py-3 pr-3 font-mono text-xs text-slate-200">{s.access}</td>
                    <td className="border-b border-slate-800 py-3 pr-3 font-mono text-xs">
                      <ModeChip mode={s.mode || (s.enabled ? 'official_api' : 'disabled')} />
                    </td>
                    <td className="border-b border-slate-800 py-3 pr-3">
                      {s.productionReady ? (
                        <span className="inline-flex items-center gap-1 rounded-[6px] border border-emerald-400/50 bg-emerald-500/20 px-2 py-1 text-[10px] font-black text-emerald-100">
                          <Wifi className="h-3 w-3" /> LIVE
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 rounded-[6px] border border-slate-600 bg-slate-800 px-2 py-1 text-[10px] font-black text-slate-200">
                          <WifiOff className="h-3 w-3" /> KEY MISSING
                        </span>
                      )}
                    </td>
                    <td className="border-b border-slate-800 py-3 pr-4 max-w-[280px] text-xs leading-5 text-slate-200">
                      {s.setup || '—'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      ) : null}

      {data ? (
        <p className="mt-3 text-[11px] leading-5 text-slate-300">
          <Activity className="mr-1 inline h-3 w-3" />
          Mode: <strong className="text-slate-100">official_api</strong> = 正式付费 API · <strong className="text-slate-100">public_csv / public_search / public_official</strong> = 免费公开端点 · <strong className="text-slate-100">fixture</strong> = 本地测试数据 · <strong className="text-slate-100">manual</strong> = 仅人工粘贴 · <strong className="text-slate-100">disabled</strong> = 未配置。
        </p>
      ) : null}
    </section>
  );
}

function ModeChip({ mode }: { mode: string }) {
  const tone: Record<string, string> = {
    official_api: 'border-emerald-400/50 bg-emerald-500/20 text-emerald-100',
    public_csv: 'border-blue-400/50 bg-blue-500/20 text-blue-100',
    public_search: 'border-blue-400/50 bg-blue-500/20 text-blue-100',
    public_official: 'border-blue-400/50 bg-blue-500/20 text-blue-100',
    fixture: 'border-amber-400/50 bg-amber-500/20 text-amber-100',
    manual: 'border-amber-400/50 bg-amber-500/20 text-amber-100',
    search_adapter: 'border-amber-400/50 bg-amber-500/20 text-amber-100',
    disabled: 'border-slate-600 bg-slate-800 text-slate-200',
  };
  const cls = tone[mode] || tone.disabled;
  return (
    <span className={`inline-flex items-center rounded-[6px] border px-2 py-1 text-[10px] font-black uppercase tracking-[0.1em] ${cls}`}>
      {mode}
    </span>
  );
}
