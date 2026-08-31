export type SpaceFundamentalMetric = {
  label: string;
  value: number | null;
  unit: 'usd_m' | 'multiple' | 'percent' | 'ratio' | 'count';
  better?: 'higher' | 'lower' | 'context';
};

export type SpaceCompanyFundamentals = {
  symbol: string;
  name: string;
  status: 'public' | 'ipo';
  business: string;
  spaceXReadThrough: string;
  latestQuarter: string;
  snapshotDate: string;
  metrics: {
    marketCap: SpaceFundamentalMetric;
    ttmRevenue: SpaceFundamentalMetric;
    netIncome: SpaceFundamentalMetric;
    revenueGrowth: SpaceFundamentalMetric;
    grossMargin: SpaceFundamentalMetric;
    psRatio: SpaceFundamentalMetric;
    peRatio: SpaceFundamentalMetric;
    evSales: SpaceFundamentalMetric;
    cashLiquidity: SpaceFundamentalMetric;
    backlog: SpaceFundamentalMetric;
    currentRatio: SpaceFundamentalMetric;
    debtEquity: SpaceFundamentalMetric;
    adjustedEbitda: SpaceFundamentalMetric;
    freeCashFlow: SpaceFundamentalMetric;
  };
  catalysts: string[];
  risks: string[];
  sourceRefs: string[];
};

export const spaceFundamentalSources = [
  {
    id: 'sec-spacex-s1a',
    label: 'SpaceX S-1/A, SEC EDGAR, filed 2026-06-03',
    url: 'https://www.sec.gov/Archives/edgar/data/1181412/000162828026040364/spaceexplorationtechnologib.htm',
  },
  {
    id: 'rklb-q1-2026',
    label: 'Rocket Lab Q1 2026 results, 2026-05-07',
    url: 'https://investors.rocketlabcorp.com/node/12416/pdf',
  },
  {
    id: 'asts-q1-2026',
    label: 'AST SpaceMobile Q1 2026 results, 2026-05-11',
    url: 'https://www.businesswire.com/news/home/20260511685431/en/AST-SpaceMobile-Provides-Business-Update-and-First-Quarter-2026-Results',
  },
  {
    id: 'pl-fy-2026',
    label: 'Planet Labs Q4/FY2026 results, 2026-03-19',
    url: 'https://s29.q4cdn.com/903184914/files/doc_earnings/2026/q4/earnings-result/PL-Q4-26-Press-Release.pdf',
  },
  {
    id: 'pl-q1-2027-date',
    label: 'Planet Labs Q1 FY2027 earnings date, 2026-06-04',
    url: 'https://www.stockwatch.com/News/Item/U-b20260507546271-U%21PL-20260507/U/PL',
  },
  {
    id: 'stockanalysis-rklb',
    label: 'StockAnalysis RKLB overview and ratios, pulled 2026-06-04',
    url: 'https://stockanalysis.com/stocks/rklb/',
  },
  {
    id: 'stockanalysis-asts',
    label: 'StockAnalysis ASTS overview and ratios, pulled 2026-06-04',
    url: 'https://stockanalysis.com/stocks/asts/',
  },
  {
    id: 'stockanalysis-pl',
    label: 'StockAnalysis PL overview and ratios, pulled 2026-06-04',
    url: 'https://stockanalysis.com/stocks/pl/',
  },
];

export const spaceFundamentals: SpaceCompanyFundamentals[] = [
  {
    symbol: 'RKLB',
    name: 'Rocket Lab',
    status: 'public',
    business: 'Launch services plus spacecraft, satellite components, hypersonic testing and space systems.',
    spaceXReadThrough:
      'Closest public launch and space-infrastructure comp. SpaceX names Rocket Lab as an emerging commercial launch provider expanding toward medium-lift payloads.',
    latestQuarter: 'Q1 2026',
    snapshotDate: '2026-06-04',
    metrics: {
      marketCap: metric('Market cap', 66400, 'usd_m', 'context'),
      ttmRevenue: metric('TTM revenue', 679.58, 'usd_m', 'higher'),
      netIncome: metric('TTM net income', -182.62, 'usd_m', 'higher'),
      revenueGrowth: metric('Q1 revenue growth YoY', 63.5, 'percent', 'higher'),
      grossMargin: metric('Q1 GAAP gross margin', 38.2, 'percent', 'higher'),
      psRatio: metric('P/S', 97.7, 'multiple', 'lower'),
      peRatio: metric('P/E', null, 'multiple', 'context'),
      evSales: metric('EV/Sales', 95.73, 'multiple', 'lower'),
      cashLiquidity: metric('Liquidity', 2000, 'usd_m', 'higher'),
      backlog: metric('Backlog', 2200, 'usd_m', 'higher'),
      currentRatio: metric('Current ratio', 4.47, 'ratio', 'higher'),
      debtEquity: metric('Debt/equity', 0.06, 'ratio', 'lower'),
      adjustedEbitda: metric('Q2 adj. EBITDA guide midpoint', -23, 'usd_m', 'higher'),
      freeCashFlow: metric('Free cash flow', null, 'usd_m', 'higher'),
    },
    catalysts: ['SpaceX IPO valuation anchor', 'Neutron milestones', 'new launch and defense contracts', 'M&A execution'],
    risks: ['$3B ATM equity program', 'Neutron schedule risk', 'valuation already prices strong execution'],
    sourceRefs: ['rklb-q1-2026', 'stockanalysis-rklb', 'sec-spacex-s1a'],
  },
  {
    symbol: 'ASTS',
    name: 'AST SpaceMobile',
    status: 'public',
    business: 'Space-based cellular broadband directly to standard smartphones through mobile network partners.',
    spaceXReadThrough:
      'Direct Starlink Mobile read-through. SpaceX names AST SpaceMobile among satellite-to-mobile competitors.',
    latestQuarter: 'Q1 2026',
    snapshotDate: '2026-06-04',
    metrics: {
      marketCap: metric('Market cap', 41810, 'usd_m', 'context'),
      ttmRevenue: metric('TTM revenue', 84.94, 'usd_m', 'higher'),
      netIncome: metric('TTM net income', -487.25, 'usd_m', 'higher'),
      revenueGrowth: metric('2026 revenue guide vs TTM', 106.0, 'percent', 'higher'),
      grossMargin: metric('Gross margin', null, 'percent', 'higher'),
      psRatio: metric('P/S', 492.29, 'multiple', 'lower'),
      peRatio: metric('P/E', null, 'multiple', 'context'),
      evSales: metric('EV/Sales', 491.84, 'multiple', 'lower'),
      cashLiquidity: metric('Cash and restricted cash', 3500, 'usd_m', 'higher'),
      backlog: metric('2026 guide midpoint', 175, 'usd_m', 'higher'),
      currentRatio: metric('Current ratio', 18.47, 'ratio', 'higher'),
      debtEquity: metric('Debt/equity', 1.12, 'ratio', 'lower'),
      adjustedEbitda: metric('Q1 adjusted operating expenses', -91.2, 'usd_m', 'higher'),
      freeCashFlow: metric('Free cash flow', null, 'usd_m', 'higher'),
    },
    catalysts: ['BlueBird 8/9/10 launch window in mid-June', 'MNO commercialization milestones', 'government awards'],
    risks: ['launch delay or anomaly', 'very high P/S', 'future capital intensity and dilution risk'],
    sourceRefs: ['asts-q1-2026', 'stockanalysis-asts', 'sec-spacex-s1a'],
  },
  {
    symbol: 'PL',
    name: 'Planet Labs',
    status: 'public',
    business: 'Earth observation imagery, analytics, government and enterprise data subscriptions.',
    spaceXReadThrough:
      'Indirect space-data read-through. Less direct competition with SpaceX; benefits most from cheaper launch, government demand, and AI imagery use cases.',
    latestQuarter: 'Q4 FY2026 / Q1 FY2027 pending',
    snapshotDate: '2026-06-04',
    metrics: {
      marketCap: metric('Market cap', 15370, 'usd_m', 'context'),
      ttmRevenue: metric('TTM revenue', 307.73, 'usd_m', 'higher'),
      netIncome: metric('TTM net income', -246.86, 'usd_m', 'higher'),
      revenueGrowth: metric('FY2026 revenue growth YoY', 25.9, 'percent', 'higher'),
      grossMargin: metric('FY2026 gross margin', 56, 'percent', 'higher'),
      psRatio: metric('P/S', 49.95, 'multiple', 'lower'),
      peRatio: metric('P/E', null, 'multiple', 'context'),
      evSales: metric('EV/Sales', 49.37, 'multiple', 'lower'),
      cashLiquidity: metric('Cash and short-term investments', 640.1, 'usd_m', 'higher'),
      backlog: metric('Backlog', 900, 'usd_m', 'higher'),
      currentRatio: metric('Current ratio', 1.65, 'ratio', 'higher'),
      debtEquity: metric('Debt/equity', 2.42, 'ratio', 'lower'),
      adjustedEbitda: metric('FY2026 adjusted EBITDA', 15.5, 'usd_m', 'higher'),
      freeCashFlow: metric('FY2026 free cash flow', 52.9, 'usd_m', 'higher'),
    },
    catalysts: ['Q1 FY2027 earnings after market on 2026-06-04', 'defense and intelligence demand', 'AI imagery workflows'],
    risks: ['earnings sell-the-news risk', 'high P/S despite smaller revenue base', 'GAAP loss and warrant-liability noise'],
    sourceRefs: ['pl-fy-2026', 'pl-q1-2027-date', 'stockanalysis-pl'],
  },
  {
    symbol: 'SPCX',
    name: 'SpaceX',
    status: 'ipo',
    business: 'Reusable launch, Starlink broadband/mobile, Starshield, and AI infrastructure after xAI acquisition.',
    spaceXReadThrough:
      'Sector anchor rather than a clean public comp. Its IPO filing can reset investor multiples and highlight competitive pressure.',
    latestQuarter: 'Q1 2026 / FY2025',
    snapshotDate: '2026-06-04',
    metrics: {
      marketCap: metric('Market cap', null, 'usd_m', 'context'),
      ttmRevenue: metric('2025 revenue', 18674, 'usd_m', 'higher'),
      netIncome: metric('2025 net income', -4937, 'usd_m', 'higher'),
      revenueGrowth: metric('Connectivity 2025 revenue growth', 49.8, 'percent', 'higher'),
      grossMargin: metric('Gross margin', null, 'percent', 'higher'),
      psRatio: metric('P/S', null, 'multiple', 'context'),
      peRatio: metric('P/E', null, 'multiple', 'context'),
      evSales: metric('EV/Sales', null, 'multiple', 'context'),
      cashLiquidity: metric('Liquidity', null, 'usd_m', 'higher'),
      backlog: metric('Q1 2026 revenue', 4694, 'usd_m', 'higher'),
      currentRatio: metric('Current ratio', null, 'ratio', 'higher'),
      debtEquity: metric('Debt/equity', null, 'ratio', 'lower'),
      adjustedEbitda: metric('2025 adjusted EBITDA', 6584, 'usd_m', 'higher'),
      freeCashFlow: metric('Free cash flow', null, 'usd_m', 'higher'),
    },
    catalysts: ['IPO pricing', 'Nasdaq listing under SPCX if effective', 'Starlink growth and mobile connectivity narrative'],
    risks: ['preliminary filing may change', 'controlled-company governance', 'AI and Starship investment losses'],
    sourceRefs: ['sec-spacex-s1a'],
  },
];

function metric(
  label: string,
  value: number | null,
  unit: SpaceFundamentalMetric['unit'],
  better: SpaceFundamentalMetric['better'] = 'context',
): SpaceFundamentalMetric {
  return { label, value, unit, better };
}
