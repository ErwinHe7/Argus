'use client';

import { useState } from 'react';
import Link from 'next/link';
import { ArrowLeft, Compass, Loader2, Sparkles } from 'lucide-react';

const SAMPLE_PROMPTS = [
  'A 股 AI 半导体产业链，哪 5 个方向最值得优先研究？',
  '机器人产业链里，哪些环节最接近真实供需瓶颈？',
  '美股 AI 基建：CPO / HBM / 电源散热，哪一层卡得最紧？',
  '挑战这家公司是不是 CPO 核心供应商：[填公司名/股票代码]',
];

type ApiResponse =
  | { topic: string; analysis: string; generatedAt: string }
  | { error: string };

export default function SerenityResearchPage() {
  const [topic, setTopic] = useState('');
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<{ topic: string; analysis: string; generatedAt: string } | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    if (!topic.trim() || loading) return;
    setLoading(true);
    setError(null);
    setResult(null);
    try {
      const res = await fetch('/api/research/serenity', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ topic }),
      });
      const data = (await res.json()) as ApiResponse;
      if (!res.ok || 'error' in data) {
        setError('error' in data ? data.error : `请求失败 (${res.status})`);
      } else {
        setResult(data);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : '请求失败');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="-mx-4 -mb-24 -mt-6 min-h-screen bg-[#f3eee5] px-4 pb-24 pt-0 text-slate-950 sm:-mx-6 sm:px-6 lg:-mx-8 lg:px-8">
      <main className="mx-auto min-h-screen max-w-[1100px] bg-[#05070b] px-5 py-6 text-white shadow-2xl shadow-black/30 sm:px-8">
        <div className="mb-5">
          <Link
            href="/market"
            className="inline-flex items-center gap-2 text-xs font-black tracking-[0.08em] text-slate-300 hover:text-white"
          >
            <ArrowLeft className="h-4 w-4" /> 返回市场首页
          </Link>
        </div>

        <header className="rounded-[8px] border border-slate-700 bg-gradient-to-br from-[#0b1120] to-[#080d1a] p-6">
          <p className="inline-flex items-center gap-2 rounded-[4px] border border-emerald-400/40 bg-emerald-500/10 px-2.5 py-1 font-mono text-[11px] font-black uppercase tracking-[0.16em] text-emerald-300">
            <Compass className="h-3.5 w-3.5" /> 研究层 · 产业链卡点
          </p>
          <h1 className="mt-3 text-3xl font-black tracking-tight text-white">
            Serenity 式深度研究
          </h1>
          <p className="mt-3 max-w-3xl text-sm leading-7 text-slate-200">
            把热点拆成产业链，找供应链卡住的环节，再回到股票排序。输入主题/方向/公司，
            <span className="text-white font-bold"> 返回卡点判断 + 优先研究清单 + 证据 + 反方理由 + 下一步检查</span>。
          </p>
          <p className="mt-2 text-xs leading-6 text-slate-400">
            公开方法论研究辅助 · 灵感来自 Serenity / @aleabitoreddit 的公开内容 · 不构成投资建议。
          </p>
        </header>

        <section className="mt-6 rounded-[8px] border border-slate-700 bg-[#0b1120] p-5">
          <label className="block text-xs font-black tracking-[0.08em] text-slate-300 uppercase">
            研究主题
          </label>
          <textarea
            value={topic}
            onChange={(e) => setTopic(e.target.value)}
            placeholder="例：A 股 AI 半导体，哪 5 个方向最值得优先研究？"
            rows={3}
            className="mt-2 w-full rounded-[6px] border border-slate-600 bg-black/40 px-3 py-2 text-sm text-white placeholder:text-slate-500 focus:border-emerald-400 focus:outline-none"
            disabled={loading}
          />
          <div className="mt-3 flex flex-wrap gap-2">
            {SAMPLE_PROMPTS.map((p) => (
              <button
                key={p}
                type="button"
                onClick={() => setTopic(p)}
                disabled={loading}
                className="rounded-[4px] border border-slate-600 bg-slate-800/60 px-2.5 py-1 text-[11px] text-slate-300 hover:border-emerald-400/60 hover:text-white disabled:opacity-50"
              >
                {p}
              </button>
            ))}
          </div>
          <div className="mt-4 flex items-center gap-3">
            <button
              type="button"
              onClick={submit}
              disabled={loading || !topic.trim()}
              className="inline-flex items-center gap-2 rounded-[6px] border border-emerald-400/60 bg-emerald-500/20 px-4 py-2 text-sm font-black tracking-[0.06em] text-emerald-100 hover:bg-emerald-500/30 disabled:opacity-50"
            >
              {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Sparkles className="h-4 w-4" />}
              {loading ? '正在调研…' : '开始调研'}
            </button>
            <span className="text-[11px] text-slate-500">
              用 lib/llm 多模型 fallback · 每分钟限 4 次
            </span>
          </div>
        </section>

        {error && (
          <div className="mt-5 rounded-[6px] border border-red-500/60 bg-red-500/10 p-4 text-sm text-red-200">
            {error}
          </div>
        )}

        {result && (
          <section className="mt-5 rounded-[8px] border border-slate-700 bg-[#0b1120] p-5">
            <div className="mb-3 flex items-center justify-between text-[11px] text-slate-400">
              <span>主题：{result.topic}</span>
              <span>生成于 {new Date(result.generatedAt).toLocaleString('zh-CN')}</span>
            </div>
            <article className="whitespace-pre-wrap text-sm leading-7 text-slate-100">
              {result.analysis}
            </article>
          </section>
        )}

        <footer className="mt-7 rounded-[6px] border border-slate-800 bg-black px-5 py-4 text-xs leading-7 text-slate-400">
          研究辅助工具。强结论应以公告、交易所文件、财报、监管/项目文件等强证据为依据。
          最终买卖判断由用户自己控制。
        </footer>
      </main>
    </div>
  );
}
