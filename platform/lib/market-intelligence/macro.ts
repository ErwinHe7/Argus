// FRED (Federal Reserve Economic Data) connector. Works without an API key by
// reading the public fredgraph.csv endpoints; if FRED_API_KEY is set we use the
// official JSON API which is more stable. No mock fallback — failed series
// surface as null with status:"unavailable".

export type MacroPoint = {
  date: string;
  value: number | null;
};

export type MacroSeries = {
  id: string;
  title: string;
  unit: string;
  source: string;
  sourceUrl: string;
  status: 'ok' | 'unavailable';
  asOf: string | null;
  latest: number | null;
  previous: number | null;
  changeAbs: number | null;
  changePct: number | null;
  yearAgo: number | null;
  yoyPct: number | null;
  interpretation: string;
  threshold?: string;
  recessionFlag?: boolean;
  history: MacroPoint[];
};

export type MacroReport = {
  generatedAt: string;
  series: MacroSeries[];
  reliability: 'ok' | 'partial' | 'unavailable';
  recessionSignals: string[];
  disclaimer: string;
};

type FredSeriesDef = {
  id: string;
  title: string;
  unit: string;
  threshold?: string;
  recession?: (latest: number, previous: number | null) => boolean;
  interpret: (latest: number, previous: number | null, yearAgo: number | null) => string;
};

const SERIES: FredSeriesDef[] = [
  {
    id: 'T10Y2Y',
    title: '10年-2年利差',
    unit: '%',
    threshold: '< 0 = 倒挂(历史衰退先行) · > 0 = 正常',
    recession: (latest) => latest < 0,
    interpret: (latest) =>
      latest < 0
        ? `当前 ${latest.toFixed(2)}%，曲线倒挂，历史衰退先行信号。`
        : latest < 0.5
          ? `当前 ${latest.toFixed(2)}%，接近持平，需要观察是否倒挂。`
          : `当前 ${latest.toFixed(2)}%，曲线正常陡峭。`,
  },
  {
    id: 'DFF',
    title: '联邦基金利率',
    unit: '%',
    threshold: '关注 Fed 降息节奏',
    interpret: (latest, previous) => {
      const delta = previous !== null ? latest - previous : 0;
      const dir = delta > 0 ? '近期上调' : delta < 0 ? '近期下调' : '维持不变';
      return `${latest.toFixed(2)}%，${dir}。`;
    },
  },
  {
    id: 'DGS10',
    title: '10年期国债收益率',
    unit: '%',
    interpret: (latest) => `10Y ${latest.toFixed(2)}%，影响科技股估值。`,
  },
  {
    id: 'CPIAUCSL',
    title: '消费者物价 CPI',
    unit: '',
    threshold: 'YoY > 3% 通胀偏高',
    interpret: (latest, _prev, yearAgo) => {
      if (yearAgo === null) return `CPI 指数 ${latest.toFixed(1)}。`;
      const yoy = ((latest - yearAgo) / yearAgo) * 100;
      return `CPI YoY ${yoy.toFixed(2)}%${yoy > 3 ? '，仍偏高' : yoy > 2 ? '，接近目标' : '，偏温和'}。`;
    },
  },
  {
    id: 'UNRATE',
    title: '失业率',
    unit: '%',
    threshold: '上升 0.5+ pct = Sahm rule 衰退信号',
    interpret: (latest) => `失业率 ${latest.toFixed(2)}%。`,
  },
  {
    id: 'M2SL',
    title: 'M2 货币供应',
    unit: 'Bn USD',
    interpret: (latest, _prev, yearAgo) => {
      if (yearAgo === null) return `M2 ${(latest / 1000).toFixed(2)}万亿。`;
      const yoy = ((latest - yearAgo) / yearAgo) * 100;
      return `M2 YoY ${yoy.toFixed(2)}%，${yoy > 0 ? '货币供应扩张' : '货币供应收缩'}。`;
    },
  },
  {
    id: 'DTWEXBGS',
    title: '美元指数 (BG)',
    unit: 'index',
    interpret: (latest, previous) => {
      if (previous === null) return `美元 ${latest.toFixed(2)}。`;
      const delta = ((latest - previous) / previous) * 100;
      return `美元 ${latest.toFixed(2)}，最近变化 ${delta >= 0 ? '+' : ''}${delta.toFixed(2)}%。`;
    },
  },
];

const KEY = process.env.FRED_API_KEY;

export async function buildMacroReport(): Promise<MacroReport> {
  const generatedAt = new Date().toISOString();
  const results = await Promise.allSettled(SERIES.map((def) => fetchSeries(def)));

  const series = results.map((result, idx) => {
    if (result.status === 'fulfilled') return result.value;
    return unavailableSeries(SERIES[idx], result.reason);
  });

  const okCount = series.filter((s) => s.status === 'ok').length;
  const reliability = okCount === series.length ? 'ok' : okCount > 0 ? 'partial' : 'unavailable';
  const recessionSignals = series
    .filter((s) => s.recessionFlag)
    .map((s) => `${s.title} 触发衰退先行信号 (${s.latest?.toFixed(2)}${s.unit})`);

  return {
    generatedAt,
    series,
    reliability,
    recessionSignals,
    disclaimer:
      '数据来自 FRED (Federal Reserve Economic Data) 公开端点，部分序列为月度，更新可能延迟数日。本面板用于宏观研究展示，不构成投资建议。',
  };
}

async function fetchSeries(def: FredSeriesDef): Promise<MacroSeries> {
  const history = KEY ? await fetchSeriesJson(def.id, KEY) : await fetchSeriesCsv(def.id);
  const valid = history.filter((p) => p.value !== null) as Array<{ date: string; value: number }>;
  if (!valid.length) {
    return unavailableSeries(def, new Error('FRED series empty'));
  }
  const latest = valid.at(-1)!;
  const previous = valid.length > 1 ? valid.at(-2)! : null;
  const targetDate = new Date(latest.date);
  targetDate.setFullYear(targetDate.getFullYear() - 1);
  const yearAgo =
    valid.find((p) => {
      const d = new Date(p.date);
      return Math.abs(d.getTime() - targetDate.getTime()) < 1000 * 60 * 60 * 24 * 30;
    })?.value ?? null;

  const changeAbs = previous ? latest.value - previous.value : null;
  const changePct = previous && previous.value !== 0 ? (changeAbs! / previous.value) * 100 : null;
  const yoyPct = yearAgo && yearAgo !== 0 ? ((latest.value - yearAgo) / yearAgo) * 100 : null;
  const recessionFlag = def.recession ? def.recession(latest.value, previous?.value ?? null) : false;

  return {
    id: def.id,
    title: def.title,
    unit: def.unit,
    source: 'FRED (St. Louis Fed)',
    sourceUrl: `https://fred.stlouisfed.org/series/${def.id}`,
    status: 'ok',
    asOf: latest.date,
    latest: latest.value,
    previous: previous?.value ?? null,
    changeAbs,
    changePct,
    yearAgo,
    yoyPct,
    interpretation: def.interpret(latest.value, previous?.value ?? null, yearAgo),
    threshold: def.threshold,
    recessionFlag,
    history: valid.slice(-260),
  };
}

async function fetchSeriesJson(id: string, key: string): Promise<MacroPoint[]> {
  const url = new URL('https://api.stlouisfed.org/fred/series/observations');
  url.searchParams.set('series_id', id);
  url.searchParams.set('api_key', key);
  url.searchParams.set('file_type', 'json');
  url.searchParams.set('limit', '4000');
  url.searchParams.set('sort_order', 'asc');
  const data = await fetchJson<{
    observations?: Array<{ date?: string; value?: string }>;
  }>(url.toString());
  return (data.observations || []).map((row) => ({
    date: row.date || '',
    value: row.value && row.value !== '.' ? Number(row.value) : null,
  }));
}

async function fetchSeriesCsv(id: string): Promise<MacroPoint[]> {
  const url = `https://fred.stlouisfed.org/graph/fredgraph.csv?id=${encodeURIComponent(id)}`;
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), 9000);
  try {
    const res = await fetch(url, {
      cache: 'no-store',
      signal: controller.signal,
      headers: { Accept: 'text/csv,*/*' },
    });
    if (!res.ok) throw new Error(`fred csv ${res.status}`);
    const text = await res.text();
    const lines = text.trim().split('\n').slice(1);
    return lines.map((line) => {
      const [date, raw] = line.split(',');
      const v = raw && raw !== '.' ? Number(raw) : NaN;
      return { date: date || '', value: Number.isFinite(v) ? v : null };
    });
  } finally {
    clearTimeout(t);
  }
}

function unavailableSeries(def: FredSeriesDef, err: unknown): MacroSeries {
  return {
    id: def.id,
    title: def.title,
    unit: def.unit,
    source: 'FRED (St. Louis Fed)',
    sourceUrl: `https://fred.stlouisfed.org/series/${def.id}`,
    status: 'unavailable',
    asOf: null,
    latest: null,
    previous: null,
    changeAbs: null,
    changePct: null,
    yearAgo: null,
    yoyPct: null,
    interpretation: `暂无可靠数据 (${err instanceof Error ? err.message : 'fetch failed'})`,
    threshold: def.threshold,
    recessionFlag: false,
    history: [],
  };
}

async function fetchJson<T>(url: string, init?: RequestInit): Promise<T> {
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), 9000);
  try {
    const res = await fetch(url, { ...init, cache: 'no-store', signal: controller.signal });
    if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
    return (await res.json()) as T;
  } finally {
    clearTimeout(t);
  }
}
