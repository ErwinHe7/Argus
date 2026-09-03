export const AXIO7_KNOWLEDGE_VERSION = 'axio7.model-knowledge.2026-07-25.v1';

type KnowledgeSection = {
  id: string;
  title: string;
  keywords: string[];
  body: string;
  sources: string[];
};

const ALWAYS_INCLUDE = new Set(['operating-contract', 'production-status']);

const SECTIONS: KnowledgeSection[] = [
  {
    id: 'operating-contract',
    title: 'What AXIO7 is',
    keywords: ['axio7', 'what', 'who', '能力', '是什么', '能做什么', '介绍'],
    body:
      'AXIO7 is an impersonal market-research system. It converts a natural-language question into an allow-listed deterministic market query, runs the query in the Rust engine, and returns evidence, counter-evidence, historical analogs, freshness, lineage, caveats, and an audit identifier. It does not place orders, personalize recommendations, or call directional setups risk-free arbitrage.',
    sources: ['AGENTS.md', 'docs/exec-plans/active/production-quant-inference.md'],
  },
  {
    id: 'production-status',
    title: 'Current production status',
    keywords: [
      'status',
      'live',
      'realtime',
      'data',
      'production',
      '状态',
      '实时',
      '数据',
      '上线',
      '为什么不能',
    ],
    body:
      'The public website, Google authentication, Next.js conversation service, Rust research runtime, and monitor scheduler are deployed. Public live market candidates remain fail-closed until AXIO7 has a redistributable realtime equities/options entitlement and a separately validated, promoted immutable model artifact. Personal Massive history is research-only and cannot be silently republished to website users.',
    sources: [
      'docs/exec-plans/active/production-quant-inference.md',
      'docs/data-source-decision-2026-07-25.md',
    ],
  },
  {
    id: 'architecture',
    title: 'Research architecture',
    keywords: [
      'architecture',
      'pipeline',
      'backend',
      'rust',
      'python',
      'llm',
      '架构',
      '后台',
      '流程',
      '大模型',
    ],
    body:
      'The language model may understand a question and explain a result, but it cannot calculate prices, probabilities, Greeks, gamma exposure, expected return, or trading economics. Python and CUDA are offline research and training. Rust owns production features, readiness gates, regime inference, stochastic-model inference, scanners, historical evaluation, and audit output. Next.js owns authentication, request validation, orchestration, and presentation.',
    sources: ['AGENTS.md', 'docs/intraday-quant-rust-architecture.md'],
  },
  {
    id: 'universe-horizons',
    title: 'Supported universe and horizons',
    keywords: [
      'universe',
      'symbol',
      'ticker',
      'horizon',
      '标的',
      '股票',
      '预测多久',
      '周期',
    ],
    body:
      'The initial public research universe is SPX, QQQ, NVDA, AAPL, MU, SOXX, NBIS, BE, and IGV. Standard short-horizon contracts are 5, 15, 30, and 60 minutes. SPX has no centralized traded volume, so volume and VWAP studies use the explicitly disclosed SPY proxy while SPX options use the SPX option root.',
    sources: [
      'docs/model-system-audit-and-narrow-universe-roadmap.md',
      'docs/exec-plans/active/production-quant-inference.md',
    ],
  },
  {
    id: 'regime-stochastic',
    title: 'Regime and stochastic models',
    keywords: [
      'hmm',
      'markov',
      'regime',
      'sde',
      'ou',
      'stochastic',
      '状态',
      '随机微分',
      '隐马尔可夫',
      '市场环境',
    ],
    body:
      'The frozen Rust research artifact contains a hidden-state regime layer, a Markov-switching log-return diffusion, a VWAP-residual Ornstein-Uhlenbeck process, and a regime-conditioned momentum head. Regime probabilities are filtered causally from information available at the cutoff. The stochastic layer is decision-neutral shadow research unless its artifact is independently validated and promoted.',
    sources: [
      'docs/regime-model-specification.md',
      'docs/intraday-quant-mathematics.md',
      'docs/exec-plans/active/production-quant-inference.md',
    ],
  },
  {
    id: 'neural-models',
    title: 'CUDA neural challengers',
    keywords: [
      'cuda',
      'gpu',
      'tcn',
      'neural',
      'deep learning',
      'transformer',
      '神经网络',
      '深度学习',
      '训练',
      '显卡',
    ],
    body:
      'AXIO7 has offline CUDA challengers for the narrow universe: a causal temporal convolutional network and a regime-gated mixture of experts with causal attention, direction, return-distribution, VWAP-cross, and excursion heads. They were trained on chronological splits with embargoes and validation-only calibration. They remain candidate artifacts because longer-horizon direction did not establish a stable edge and no licensed forward-shadow trial or executable-cost validation exists.',
    sources: [
      'docs/model-system-audit-and-narrow-universe-roadmap.md',
      'docs/exec-plans/active/production-quant-inference.md',
    ],
  },
  {
    id: 'setups',
    title: 'Supported research setups',
    keywords: [
      'momentum',
      'vwap',
      'gamma',
      'squeeze',
      'turn',
      'short cover',
      '动量',
      '趋势',
      '伽马',
      '挤压',
      '转折',
      '空头回补',
      '回测',
    ],
    body:
      'The first setup families are finalized-bar momentum continuation, VWAP reclaim or rejection, opening-session five-minute exhaustion, closing short-cover hazard, potential gamma-convexity feedback, and statistical market dislocation. The same normalized query can be scanned now and evaluated historically with point-in-time cutoffs and explicit evidence grades.',
    sources: [
      'docs/realtime-short-horizon-system.md',
      'docs/forecast-contract-and-evidence.md',
    ],
  },
  {
    id: 'gamma-semantics',
    title: 'Gamma limitations',
    keywords: [
      'gamma',
      'gex',
      'dealer',
      'opra',
      'options',
      '伽马',
      '期权',
      '做市商',
      'call wall',
    ],
    body:
      'Open interest does not reveal dealer identity, dealer position sign, or whether a trade opened or closed a position. AXIO7 therefore reports unsigned gamma concentration or an explicitly named sign scenario. A production gamma scan requires a complete fresh OPRA chain, contract definitions, Greeks, timestamped daily open interest, underlying data, spread and coverage checks, and external-display rights.',
    sources: [
      'docs/realtime-options-data-policy.md',
      'docs/forecast-contract-and-evidence.md',
    ],
  },
  {
    id: 'validation',
    title: 'Validation and probability policy',
    keywords: [
      'accuracy',
      'auc',
      'probability',
      'calibration',
      'backtest',
      '验证',
      '准确率',
      '概率',
      '校准',
      '回测',
      '过拟合',
    ],
    body:
      'Raw historical frequencies are descriptive and are not calibrated probabilities. A probability may be published only from a separately validated and promoted immutable calibration artifact. Evaluation uses point-in-time inputs, purged walk-forward splits where applicable, explicit costs, untouched out-of-sample results, data-leakage checks, and a later forward-shadow period.',
    sources: [
      'docs/model_promotion_policy.md',
      'docs/overfitting_controls.md',
      'docs/forecast-contract-and-evidence.md',
    ],
  },
  {
    id: 'storage-lineage',
    title: 'Data storage and lineage',
    keywords: [
      'postgres',
      'sqlite',
      'database',
      'history',
      'lineage',
      '数据库',
      '历史数据',
      '数据源',
      '存储',
    ],
    body:
      'PostgreSQL is the continuous-ingestion market database and the immutable SQLite archive remains source evidence. Stored observations distinguish event time, availability time, and capture time, plus provider, dataset, quality, and license scope. Migrating data into PostgreSQL does not upgrade its redistribution license.',
    sources: ['docs/data_contracts.md', 'docs/exec-plans/active/production-quant-inference.md'],
  },
  {
    id: 'authentication',
    title: 'Authentication and secret handling',
    keywords: [
      'google',
      'login',
      'account',
      'privacy',
      '登录',
      '谷歌',
      '账户',
      '隐私',
    ],
    body:
      'Google OAuth uses the existing Supabase identity store and returns to the AXIO7 production callback. Vendor credentials, the OpenAI-compatible model key, Supabase service credentials, and the Rust research token stay in server-only environment variables. The browser never receives those secrets.',
    sources: [
      'app/auth/signin/page.tsx',
      'app/auth/callback/route.ts',
      'infra/single-vm/README.md',
    ],
  },
];

function tokenize(query: string): string[] {
  return query
    .toLowerCase()
    .split(/[^\p{L}\p{N}]+/u)
    .map((token) => token.trim())
    .filter((token) => token.length > 1);
}

export function isMarketResearchQuestion(query: string): boolean {
  return /(?:\b(?:SPX|QQQ|NVDA|AAPL|MU|SOXX|NBIS|BE|IGV)\b|\$[A-Z]{1,9}\b|momentum|VWAP|gamma|GEX|squeeze|backtest|scan|monitor|price|return|market|options?|K[\s-]?line|走势|预测|动量|趋势|伽马|挤压|回测|监测|扫描|期权|价格|涨|跌|转折|空头回补|大盘)/i.test(
    query
  );
}

export function retrieveModelKnowledge(
  query: string,
  limit = 7
): {
  version: string;
  sections: Array<Pick<KnowledgeSection, 'id' | 'title' | 'body' | 'sources'>>;
} {
  const lower = query.toLowerCase();
  const tokens = tokenize(query);
  const ranked = SECTIONS.map((section, index) => {
    const keywordMatches = section.keywords.reduce(
      (score, keyword) =>
        score + (lower.includes(keyword.toLowerCase()) ? 4 : 0),
      0
    );
    const tokenMatches = tokens.reduce(
      (score, token) =>
        score +
        (section.title.toLowerCase().includes(token) ||
        section.body.toLowerCase().includes(token)
          ? 1
          : 0),
      0
    );
    return {
      section,
      index,
      score:
        keywordMatches +
        tokenMatches +
        (ALWAYS_INCLUDE.has(section.id) ? 2 : 0),
    };
  })
    .filter((row) => row.score > 0)
    .sort((a, b) => b.score - a.score || a.index - b.index);

  const selected = new Map<string, KnowledgeSection>();
  for (const section of SECTIONS) {
    if (ALWAYS_INCLUDE.has(section.id)) selected.set(section.id, section);
  }
  for (const row of ranked) {
    if (selected.size >= limit) break;
    selected.set(row.section.id, row.section);
  }

  return {
    version: AXIO7_KNOWLEDGE_VERSION,
    sections: Array.from(selected.values()).map(
      ({ id, title, body, sources }) => ({ id, title, body, sources })
    ),
  };
}
