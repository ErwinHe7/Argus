import 'package:ritual_investing_app/features/ai_analysis/domain/model.dart';

AiAnalysisSnapshot buildFixtureAiAnalysisSnapshot() {
  final assessedAt = DateTime.utc(2026, 8, 31, 20);
  final freshThrough = DateTime.utc(2026, 9, 3);

  return AiAnalysisSnapshot(
    id: 'leo-ai-analysis-demo-2026-08-31',
    models: [
      _buildAtlasQuality(),
      _buildNorthstarGrowth(),
      _buildHarborDefense(),
      _buildChatGptSimulation(),
      _buildClaudeSimulation(),
      _buildTrumpDisclosureTracker(),
      _buildBerkshireDisclosureTracker(),
      _buildArkDisclosureTracker(),
      _buildSorosDisclosureTracker(),
      _buildSituationalAwarenessTracker(),
    ],
    riskRegime: MarketRiskRegime(
      level: MarketRiskLevel.elevated,
      label: 'Pressure is building',
      summary:
          'Three of four rules-based signals warrant attention. This is not a '
          'bear-market forecast. Conditions may normalize. This is not an '
          'instruction to sell.',
      observedAt: assessedAt,
      validThrough: freshThrough,
      horizon: 'Next 4–8 weeks',
      validation: 'Illustrative rule only; it has not been checked against live market data.',
      limitations:
          'These simplified signals may lag, conflict, or produce false '
          'positives. They do not estimate the probability or timing of a '
          'decline.',
      signals: [
        MarketRiskSignal(
          id: 'trend',
          label: 'Trend',
          state: MarketRiskSignalState.watch,
          observedAt: assessedAt,
          horizon: 'Next 4–8 weeks',
          summary:
              'The long-term trend is positive in this scenario, while '
              'short-term momentum is losing strength.',
          validation:
              'The rule compares a broad index with its 50- and 200-day '
              'moving averages.',
          limitations:
              'Moving averages are backward-looking and can turn after a '
              'large price move.',
        ),
        MarketRiskSignal(
          id: 'breadth',
          label: 'Breadth',
          state: MarketRiskSignalState.stressed,
          observedAt: assessedAt,
          horizon: 'Next 4–8 weeks',
          summary:
              'Fewer stocks are participating in the advance in this scenario, '
              'which makes the headline index less representative.',
          validation:
              'The rule compares the share of large-cap stocks above their '
              '50-day averages with its recent range.',
          limitations:
              'Narrow breadth can persist for months and does not by itself '
              'signal a market peak.',
        ),
        MarketRiskSignal(
          id: 'volatility',
          label: 'Volatility',
          state: MarketRiskSignalState.watch,
          observedAt: assessedAt,
          horizon: 'Next 4–8 weeks',
          summary:
              'Expected volatility is above its recent median in this scenario, '
              'but remains below a crisis-like level.',
          validation:
              'The rule compares implied volatility with its trailing '
              'one-year distribution.',
          limitations:
              'Volatility can rise without a sustained decline and can stay '
              'low before a sudden shock.',
        ),
        MarketRiskSignal(
          id: 'credit',
          label: 'Credit',
          state: MarketRiskSignalState.supportive,
          observedAt: assessedAt,
          horizon: 'Next 4–8 weeks',
          summary:
              'Corporate-credit stress remains contained in this scenario, '
              'partly offsetting the other warning signals.',
          validation:
              'The rule checks whether investment-grade and high-yield '
              'spreads are widening together.',
          limitations:
              'Credit spreads can react late, and this simplified signal '
              'does not measure liquidity or issuer-specific risk.',
        ),
      ],
    ),
    observedAt: assessedAt,
    availableAt: DateTime.utc(2026, 8, 31, 20, 5),
    // Midnight UTC on Sep 3 keeps the deterministic snapshot fresh through
    // Sep 2 while preserving the domain model's exclusive expiry boundary.
    expiresAt: freshThrough,
    sourceLabel: 'Leo Research',
    methodologyVersion: 'leo-demo-analysis-v1.0.0',
    isDemo: true,
    limitations: const [
      'Hypothetical backtests only; no capital was invested and no live or '
          'paper-forward performance is shown.',
      'Returns and benchmark values are deterministic hypothetical values, not '
          'provider-sourced market data.',
      'Backtests may benefit from hindsight, model selection, and '
          'survivorship bias; past performance does not predict future '
          'results.',
      'Reported returns include dividends and the stated trading-cost '
          'assumption, but exclude advisory fees, additional slippage, and '
          'taxes.',
      'Holdings are educational examples as of Aug 31, 2026, not '
          'personalized recommendations or instructions to buy, hold, or '
          'sell.',
      'ChatGPT and Claude entries are unofficial interface simulations built '
          'by Leo. They are not provider outputs, managed portfolios, or '
          'evidence of endorsement.',
      'Public-disclosure trackers use delayed and incomplete filings or fund '
          'holdings. Their curves are Leo filing-follow simulations, never '
          'the tracked person\'s or manager\'s actual return.',
      'The market-risk panel is not a bear-market forecast. Conditions may '
          'normalize. It is not an instruction to sell.',
    ],
  );
}

const _benchmarkSeries = <int>[
  0,
  90,
  190,
  330,
  440,
  380,
  240,
  410,
  590,
  710,
  920,
  1080,
  1280,
];

AiSectorAllocation _sector(String id, String label, int weightBps) =>
    AiSectorAllocation(id: id, label: label, weightBps: weightBps);

AiHolding _holding(
  String id,
  String symbol,
  String name,
  int weightBps,
  String rationale,
) => AiHolding(
  id: id,
  symbol: symbol,
  name: name,
  weightBps: weightBps,
  rationale: rationale,
);

AiModelPortfolio _buildAtlasQuality() => AiModelPortfolio(
  id: 'leo-atlas-quality',
  name: 'Leo Atlas Quality',
  visualAssetPath: 'assets/images/ai_analysis/leo_atlas_quality.png',
  summary:
      'A hypothetical quality-focused portfolio. Best quarter: Q2 2026 '
      '(+7.10%). Worst quarter: Q1 2026 (-3.40%).',
  trackRecordKind: AiTrackRecordKind.backtest,
  modelVersion: 'leo-atlas-quality-demo-v1.0.0',
  start: DateTime.utc(2025, 9),
  end: DateTime.utc(2026, 8, 28),
  totalReturnBps: 1860,
  benchmarkLabel: 'S&P 500 hypothetical same-period benchmark',
  benchmarkReturnBps: 1280,
  maxDrawdownMagnitudeBps: 940,
  bestQuarterBps: 710,
  worstQuarterBps: -340,
  holdingsAsOf: DateTime.utc(2026, 8, 31),
  cadence: 'Hypothetical monthly rebalance',
  selectionUniverse: 'U.S.-listed large-cap equities',
  dividendsIncluded: true,
  feeAssumption: '0.10% annualized trading-cost drag; taxes excluded',
  category: AiPortfolioCategory.leoModel,
  holdingsBasis: AiHoldingsBasis.modelOutput,
  affiliationDisclosure: 'Built by Leo. No external manager, issuer, or AI provider is affiliated with or endorses this research.',
  sourceDisclosure: 'Rules-based Leo quality screen using deterministic educational inputs; no live market feed.',
  sectorAllocations: [
    AiSectorAllocation(id: 'technology', label: 'Technology', weightBps: 4400),
    AiSectorAllocation(id: 'financials', label: 'Financials', weightBps: 3800),
    AiSectorAllocation(
      id: 'consumer-staples',
      label: 'Consumer staples',
      weightBps: 1800,
    ),
  ],
  holdings: [
    AiHolding(
      id: 'atlas-msft',
      symbol: 'MSFT',
      name: 'Microsoft',
      weightBps: 2300,
      rationale:
          'Illustrates recurring revenue, cash generation, and balance-sheet '
          'quality.',
    ),
    AiHolding(
      id: 'atlas-googl',
      symbol: 'GOOGL',
      name: 'Alphabet',
      weightBps: 2100,
      rationale:
          'Illustrates diversified digital revenue and investment capacity.',
    ),
    AiHolding(
      id: 'atlas-brkb',
      symbol: 'BRK.B',
      name: 'Berkshire Hathaway',
      weightBps: 2000,
      rationale:
          'Illustrates diversified earnings and conservative capital '
          'management.',
    ),
    AiHolding(
      id: 'atlas-v',
      symbol: 'V',
      name: 'Visa',
      weightBps: 1800,
      rationale:
          'Illustrates an asset-light network with broad payment exposure.',
    ),
    AiHolding(
      id: 'atlas-cost',
      symbol: 'COST',
      name: 'Costco Wholesale',
      weightBps: 1800,
      rationale:
          'Illustrates membership revenue and durable customer retention.',
    ),
  ],
  returnSeriesBps: const [
    0,
    140,
    320,
    520,
    760,
    290,
    -180,
    210,
    590,
    980,
    1280,
    1570,
    1860,
  ],
  benchmarkReturnSeriesBps: _benchmarkSeries,
);

AiModelPortfolio _buildNorthstarGrowth() => AiModelPortfolio(
  id: 'leo-northstar-growth',
  name: 'Leo Northstar Growth',
  visualAssetPath: 'assets/images/ai_analysis/leo_northstar_growth.png',
  summary:
      'A hypothetical growth-focused portfolio. Best quarter: Q4 2025 '
      '(+11.20%). Worst quarter: Q1 2026 (-6.20%).',
  trackRecordKind: AiTrackRecordKind.backtest,
  modelVersion: 'leo-northstar-growth-demo-v1.0.0',
  start: DateTime.utc(2025, 9),
  end: DateTime.utc(2026, 8, 28),
  totalReturnBps: 2410,
  benchmarkLabel: 'S&P 500 hypothetical same-period benchmark',
  benchmarkReturnBps: 1280,
  maxDrawdownMagnitudeBps: 1580,
  bestQuarterBps: 1120,
  worstQuarterBps: -620,
  holdingsAsOf: DateTime.utc(2026, 8, 31),
  cadence: 'Hypothetical monthly rebalance',
  selectionUniverse: 'U.S.-listed and ADR large-cap growth equities',
  dividendsIncluded: true,
  feeAssumption: '0.20% annualized trading-cost drag; taxes excluded',
  category: AiPortfolioCategory.leoModel,
  holdingsBasis: AiHoldingsBasis.modelOutput,
  affiliationDisclosure: 'Built by Leo. No external manager, issuer, or AI provider is affiliated with or endorses this research.',
  sourceDisclosure: 'Rules-based Leo growth screen using deterministic educational inputs; no live market feed.',
  sectorAllocations: [
    AiSectorAllocation(id: 'technology', label: 'Technology', weightBps: 6200),
    AiSectorAllocation(
      id: 'consumer-discretionary',
      label: 'Consumer discretionary',
      weightBps: 2000,
    ),
    AiSectorAllocation(
      id: 'communication-services',
      label: 'Communication services',
      weightBps: 1800,
    ),
  ],
  holdings: [
    AiHolding(
      id: 'northstar-nvda',
      symbol: 'NVDA',
      name: 'NVIDIA',
      weightBps: 2500,
      rationale:
          'Illustrates high-growth computing exposure with high valuation '
          'risk.',
    ),
    AiHolding(
      id: 'northstar-avgo',
      symbol: 'AVGO',
      name: 'Broadcom',
      weightBps: 2100,
      rationale:
          'Illustrates semiconductor and infrastructure-software exposure.',
    ),
    AiHolding(
      id: 'northstar-amzn',
      symbol: 'AMZN',
      name: 'Amazon',
      weightBps: 2000,
      rationale:
          'Illustrates cloud growth balanced by a scaled consumer business.',
    ),
    AiHolding(
      id: 'northstar-meta',
      symbol: 'META',
      name: 'Meta Platforms',
      weightBps: 1800,
      rationale:
          'Illustrates advertising cash flow funding new technology bets.',
    ),
    AiHolding(
      id: 'northstar-tsm',
      symbol: 'TSM',
      name: 'Taiwan Semiconductor',
      weightBps: 1600,
      rationale:
          'Illustrates advanced-chip manufacturing with geopolitical risk.',
    ),
  ],
  returnSeriesBps: const [
    0,
    250,
    590,
    820,
    1120,
    640,
    -460,
    90,
    580,
    940,
    1420,
    1900,
    2410,
  ],
  benchmarkReturnSeriesBps: _benchmarkSeries,
);

AiModelPortfolio _buildHarborDefense() => AiModelPortfolio(
  id: 'leo-harbor-defense',
  name: 'Leo Harbor Defense',
  visualAssetPath: 'assets/images/ai_analysis/leo_harbor_defense.png',
  summary:
      'A hypothetical lower-volatility portfolio. Best quarter: Q2 2026 '
      '(+3.90%). Worst quarter: Q1 2026 (-1.80%).',
  trackRecordKind: AiTrackRecordKind.backtest,
  modelVersion: 'leo-harbor-defense-demo-v1.0.0',
  start: DateTime.utc(2025, 9),
  end: DateTime.utc(2026, 8, 28),
  totalReturnBps: 1090,
  benchmarkLabel: 'S&P 500 hypothetical same-period benchmark',
  benchmarkReturnBps: 1280,
  maxDrawdownMagnitudeBps: 540,
  bestQuarterBps: 390,
  worstQuarterBps: -180,
  holdingsAsOf: DateTime.utc(2026, 8, 31),
  cadence: 'Hypothetical quarterly rebalance',
  selectionUniverse: 'U.S.-listed large-cap defensive equities',
  dividendsIncluded: true,
  feeAssumption: '0.08% annualized trading-cost drag; taxes excluded',
  category: AiPortfolioCategory.leoModel,
  holdingsBasis: AiHoldingsBasis.modelOutput,
  affiliationDisclosure: 'Built by Leo. No external manager, issuer, or AI provider is affiliated with or endorses this research.',
  sourceDisclosure: 'Rules-based Leo defensive screen using deterministic educational inputs; no live market feed.',
  sectorAllocations: [
    AiSectorAllocation(id: 'financials', label: 'Financials', weightBps: 2400),
    AiSectorAllocation(
      id: 'health-care',
      label: 'Health care',
      weightBps: 2100,
    ),
    AiSectorAllocation(
      id: 'consumer-staples',
      label: 'Consumer staples',
      weightBps: 3800,
    ),
    AiSectorAllocation(id: 'energy', label: 'Energy', weightBps: 1700),
  ],
  holdings: [
    AiHolding(
      id: 'harbor-brkb',
      symbol: 'BRK.B',
      name: 'Berkshire Hathaway',
      weightBps: 2400,
      rationale:
          'Illustrates diversified cash flows and balance-sheet resilience.',
    ),
    AiHolding(
      id: 'harbor-jnj',
      symbol: 'JNJ',
      name: 'Johnson & Johnson',
      weightBps: 2100,
      rationale:
          'Illustrates diversified healthcare demand and regulatory risk.',
    ),
    AiHolding(
      id: 'harbor-pg',
      symbol: 'PG',
      name: 'Procter & Gamble',
      weightBps: 1900,
      rationale:
          'Illustrates recurring consumer demand and pricing-power exposure.',
    ),
    AiHolding(
      id: 'harbor-wmt',
      symbol: 'WMT',
      name: 'Walmart',
      weightBps: 1900,
      rationale:
          'Illustrates essential retail demand with thin-margin tradeoffs.',
    ),
    AiHolding(
      id: 'harbor-xom',
      symbol: 'XOM',
      name: 'Exxon Mobil',
      weightBps: 1700,
      rationale:
          'Illustrates inflation sensitivity alongside commodity-cycle risk.',
    ),
  ],
  returnSeriesBps: const [
    0,
    80,
    190,
    310,
    370,
    120,
    -170,
    40,
    290,
    520,
    730,
    910,
    1090,
  ],
  benchmarkReturnSeriesBps: _benchmarkSeries,
);

AiModelPortfolio _buildChatGptSimulation() => AiModelPortfolio(
  id: 'chatgpt-simulation',
  name: 'ChatGPT Simulation',
  visualAssetPath: 'assets/images/ai_analysis/chatgpt_simulation.png',
  summary: 'An unofficial Leo simulation of a balanced, general-purpose AI stock screen. The result is hypothetical, not a ChatGPT-managed portfolio.',
  trackRecordKind: AiTrackRecordKind.backtest,
  modelVersion: 'leo-chatgpt-simulation-demo-v1.0.0',
  start: DateTime.utc(2025, 9),
  end: DateTime.utc(2026, 8, 28),
  totalReturnBps: 1470,
  benchmarkLabel: 'S&P 500 hypothetical same-period benchmark',
  benchmarkReturnBps: 1280,
  maxDrawdownMagnitudeBps: 1020,
  bestQuarterBps: 540,
  worstQuarterBps: -370,
  holdingsAsOf: DateTime.utc(2026, 8, 31),
  cadence: 'Hypothetical monthly rebalance',
  selectionUniverse: 'U.S.-listed large-cap equities',
  dividendsIncluded: true,
  feeAssumption: '0.15% annualized trading-cost drag; taxes excluded',
  category: AiPortfolioCategory.aiSimulation,
  holdingsBasis: AiHoldingsBasis.unofficialSimulation,
  affiliationDisclosure: 'Unofficial simulation. Leo is not affiliated with, sponsored by, or endorsed by OpenAI.',
  sourceDisclosure: 'Fixed Leo-authored hypothetical rules inspired by a general-purpose AI research workflow; ChatGPT is not queried at runtime.',
  sectorAllocations: [
    _sector('technology', 'Technology', 2300),
    _sector('consumer-discretionary', 'Consumer discretionary', 2100),
    _sector('financials', 'Financials', 3700),
    _sector('consumer-staples', 'Consumer staples', 1900),
  ],
  holdings: [
    _holding(
      'chatgpt-msft',
      'MSFT',
      'Microsoft',
      2300,
      'Educational example balancing recurring software revenue with AI investment risk.',
    ),
    _holding(
      'chatgpt-amzn',
      'AMZN',
      'Amazon',
      2100,
      'Educational example combining cloud growth with a scaled consumer business.',
    ),
    _holding(
      'chatgpt-v',
      'V',
      'Visa',
      2000,
      'Educational example of an asset-light payments network.',
    ),
    _holding(
      'chatgpt-cost',
      'COST',
      'Costco Wholesale',
      1900,
      'Educational example of membership revenue and customer retention.',
    ),
    _holding(
      'chatgpt-jpm',
      'JPM',
      'JPMorgan Chase',
      1700,
      'Educational example of diversified banking earnings and credit-cycle risk.',
    ),
  ],
  returnSeriesBps: const [
    0,
    110,
    260,
    430,
    550,
    330,
    -210,
    30,
    310,
    610,
    850,
    1120,
    1470,
  ],
  benchmarkReturnSeriesBps: _benchmarkSeries,
);

AiModelPortfolio _buildClaudeSimulation() => AiModelPortfolio(
  id: 'claude-simulation',
  name: 'Claude Simulation',
  visualAssetPath: 'assets/images/ai_analysis/claude_simulation.png',
  summary: 'An unofficial Leo simulation of a quality-and-resilience AI screen. The result is hypothetical, not a Claude-managed portfolio.',
  trackRecordKind: AiTrackRecordKind.backtest,
  modelVersion: 'leo-claude-simulation-demo-v1.0.0',
  start: DateTime.utc(2025, 9),
  end: DateTime.utc(2026, 8, 28),
  totalReturnBps: 1620,
  benchmarkLabel: 'S&P 500 hypothetical same-period benchmark',
  benchmarkReturnBps: 1280,
  maxDrawdownMagnitudeBps: 870,
  bestQuarterBps: 580,
  worstQuarterBps: -290,
  holdingsAsOf: DateTime.utc(2026, 8, 31),
  cadence: 'Hypothetical monthly rebalance',
  selectionUniverse: 'U.S.-listed and ADR large-cap equities',
  dividendsIncluded: true,
  feeAssumption: '0.15% annualized trading-cost drag; taxes excluded',
  category: AiPortfolioCategory.aiSimulation,
  holdingsBasis: AiHoldingsBasis.unofficialSimulation,
  affiliationDisclosure: 'Unofficial simulation. Leo is not affiliated with, sponsored by, or endorsed by Anthropic.',
  sourceDisclosure: 'Fixed Leo-authored hypothetical rules inspired by a risk-aware AI research workflow; Claude is not queried at runtime.',
  sectorAllocations: [
    _sector('financials', 'Financials', 2200),
    _sector('technology', 'Technology', 4000),
    _sector('health-care', 'Health care', 1900),
    _sector('consumer-staples', 'Consumer staples', 1900),
  ],
  holdings: [
    _holding(
      'claude-brkb',
      'BRK.B',
      'Berkshire Hathaway',
      2200,
      'Educational example of diversified cash flow and patient capital allocation.',
    ),
    _holding(
      'claude-msft',
      'MSFT',
      'Microsoft',
      2100,
      'Educational example of recurring revenue and a strong balance sheet.',
    ),
    _holding(
      'claude-asml',
      'ASML',
      'ASML Holding',
      1900,
      'Educational example of semiconductor equipment leadership with cycle risk.',
    ),
    _holding(
      'claude-unh',
      'UNH',
      'UnitedHealth Group',
      1900,
      'Educational example of healthcare scale with policy and execution risk.',
    ),
    _holding(
      'claude-cost',
      'COST',
      'Costco Wholesale',
      1900,
      'Educational example of recurring membership economics.',
    ),
  ],
  returnSeriesBps: const [
    0,
    100,
    230,
    390,
    540,
    420,
    -110,
    170,
    480,
    790,
    1080,
    1360,
    1620,
  ],
  benchmarkReturnSeriesBps: _benchmarkSeries,
);

AiModelPortfolio _buildTrumpDisclosureTracker() => AiModelPortfolio(
  id: 'trump-disclosed-purchases-tracker',
  name: 'Donald Trump Disclosed Purchases',
  publicFigureName: 'Donald Trump',
  publicFigureRole: '2026 OGE Form 278-T',
  portraitAssetPath: 'assets/portraits/donald_trump.png',
  summary:
      'A selected-purchase reconstruction from a 2026 public transaction '
      'report. The displayed return is Leo\'s equal-weight follow simulation, '
      'not Donald Trump\'s return or verified current holdings.',
  trackRecordKind: AiTrackRecordKind.backtest,
  modelVersion: 'leo-trump-278t-reconstruction-v1.0.0',
  start: DateTime.utc(2026, 5, 14),
  end: DateTime.utc(2026, 8, 28),
  totalReturnBps: 54,
  benchmarkLabel: 'Vanguard S&P 500 ETF (VOO) same-period benchmark',
  benchmarkReturnBps: 314,
  maxDrawdownMagnitudeBps: 2066,
  bestQuarterBps: 764,
  worstQuarterBps: -1606,
  bestPeriodLabel: 'Best month',
  worstPeriodLabel: 'Worst month',
  holdingsAsOf: DateTime.utc(2026, 8, 31),
  sourceDataAsOf: DateTime.utc(2026, 5, 13),
  cadence: 'One-time hypothetical equal-weight basket after public filing',
  selectionUniverse:
      'Five selected common-stock purchases, each reported in the '
      r'$1,000,001-$5,000,000 bracket on OGE Form 278-T',
  dividendsIncluded: true,
  feeAssumption: 'No fees, slippage, or taxes; adjusted closes',
  category: AiPortfolioCategory.publicDisclosureTracker,
  holdingsBasis: AiHoldingsBasis.delayedPublicDisclosure,
  affiliationDisclosure:
      'Independent educational tracker. No affiliation with or endorsement '
      'by Donald Trump, the White House, or the U.S. Government.',
  sourceDisclosure:
      'Selected from Donald J. Trump\'s U.S. Office of Government Ethics Form '
      '278-T, received 2026-05-12 and certified 2026-05-13. NVDA, MSFT, AMZN, '
      'AAPL, and ORCL purchases were each reported in the '
      r'$1,000,001-$5,000,000 range. Exact amounts, account ownership, later '
      'sales, and current positions are not established by this sample. Leo '
      'equal-weights the five names and starts the historical adjusted-close '
      'simulation on 2026-05-14, after certification, through 2026-08-28. '
      'The separate 2025 annual report certified on 2026-06-30 discloses '
      'business, digital-asset, and real-estate exposures that are excluded '
      'because they cannot support a comparable daily-price reconstruction. '
      'Prices were retrieved from Yahoo Finance on 2026-09-01. This is not '
      'Donald Trump\'s actual portfolio return.',
  sectorAllocations: [
    _sector('technology', 'Technology', 8000),
    _sector('consumer-discretionary', 'Consumer discretionary', 2000),
  ],
  holdings: [
    _holding(
      'trump-nvda',
      'NVDA',
      'NVIDIA',
      2000,
      'Purchase disclosed on 2026-02-10 in the '
          r"$1,000,001-$5,000,000 range. The 20% weight is Leo's equal-weight "
          'assumption, not a reported or current allocation.',
    ),
    _holding(
      'trump-msft',
      'MSFT',
      'Microsoft',
      2000,
      'Unsolicited purchase disclosed on 2026-03-19 in the '
          r'$1,000,001-$5,000,000 range. The filing does not establish a '
          'current position.',
    ),
    _holding(
      'trump-amzn',
      'AMZN',
      'Amazon',
      2000,
      'Unsolicited purchase disclosed on 2026-03-19 in the '
          r'$1,000,001-$5,000,000 range. Later sales may not appear in this '
          'selected sample.',
    ),
    _holding(
      'trump-aapl',
      'AAPL',
      'Apple',
      2000,
      'Unsolicited purchase disclosed on 2026-03-02 in the '
          r'$1,000,001-$5,000,000 range. The exact purchase amount is not '
          'public.',
    ),
    _holding(
      'trump-orcl',
      'ORCL',
      'Oracle',
      2000,
      'Purchase disclosed on 2026-03-17 in the '
          r'$1,000,001-$5,000,000 range. This is a historical transaction, '
          'not verified current ownership.',
    ),
  ],
  returnSeriesBps: const [
    0,
    -96,
    585,
    -558,
    -641,
    -1342,
    -1028,
    -964,
    -1205,
    -141,
    -84,
    -304,
    54,
  ],
  benchmarkReturnSeriesBps: const [
    0,
    -32,
    153,
    -301,
    6,
    -69,
    -7,
    -37,
    -94,
    339,
    356,
    223,
    314,
  ],
);

AiModelPortfolio _buildBerkshireDisclosureTracker() => AiModelPortfolio(
  id: 'berkshire-disclosure-tracker',
  name: 'Berkshire Hathaway',
  publicFigureName: 'Warren Buffett',
  publicFigureRole: 'Berkshire Hathaway',
  portraitAssetPath: 'assets/portraits/warren_buffett.jpg',
  summary: 'A delayed 13F-style reconstruction. Its return is a hypothetical Leo filing-follow simulation, not Berkshire Hathaway\'s investment return.',
  trackRecordKind: AiTrackRecordKind.backtest,
  modelVersion: 'leo-berkshire-disclosure-demo-v1.0.0',
  start: DateTime.utc(2025, 9),
  end: DateTime.utc(2026, 8, 28),
  totalReturnBps: 1330,
  benchmarkLabel: 'S&P 500 hypothetical same-period benchmark',
  benchmarkReturnBps: 1280,
  maxDrawdownMagnitudeBps: 690,
  bestQuarterBps: 460,
  worstQuarterBps: -210,
  holdingsAsOf: DateTime.utc(2026, 8, 31),
  sourceDataAsOf: DateTime.utc(2026, 6, 30),
  cadence: 'Hypothetical quarterly rebalance after a 13F becomes public',
  selectionUniverse:
      'Long U.S.-listed positions represented in delayed 13F filings',
  dividendsIncluded: true,
  feeAssumption: '0.10% annualized trading-cost drag; taxes excluded',
  category: AiPortfolioCategory.publicDisclosureTracker,
  holdingsBasis: AiHoldingsBasis.delayedPublicDisclosure,
  affiliationDisclosure: 'Independent educational tracker. No affiliation with or endorsement by Warren Buffett or Berkshire Hathaway.',
  sourceDisclosure: 'Five-name educational sample from Berkshire Hathaway\'s SEC Form 13F-HR, CIK 0001067983, report date 2026-06-30, filed 2026-08-14. Sample weights are report-period values renormalized to 100%. 13F data are delayed and incomplete; the return series is a Leo simulation.',
  sectorAllocations: [
    _sector('technology', 'Technology', 3468),
    _sector('financials', 'Financials', 4146),
    _sector('consumer-staples', 'Consumer staples', 1709),
    _sector('energy', 'Energy', 677),
  ],
  holdings: [
    _holding(
      'berkshire-aapl',
      'AAPL',
      'Apple',
      3468,
      'Reported long line; weight is its report-period value renormalized within this five-name sample, not the full portfolio.',
    ),
    _holding(
      'berkshire-axp',
      'AXP',
      'American Express',
      2698,
      'Reported long line; sample weight preserves the filing-period relationship to the other displayed names.',
    ),
    _holding(
      'berkshire-bac',
      'BAC',
      'Bank of America',
      1448,
      'Reported long line illustrating rate and credit-cycle risk; this is not a current weight.',
    ),
    _holding(
      'berkshire-ko',
      'KO',
      'Coca-Cola',
      1709,
      'Reported long line illustrating consumer-brand and dividend exposure.',
    ),
    _holding(
      'berkshire-oxy',
      'OXY',
      'Occidental Petroleum',
      677,
      'Reported long line illustrating commodity-price sensitivity; this is a delayed sample weight.',
    ),
  ],
  returnSeriesBps: const [
    0,
    70,
    180,
    310,
    420,
    230,
    -90,
    160,
    390,
    650,
    880,
    1110,
    1330,
  ],
  benchmarkReturnSeriesBps: _benchmarkSeries,
);

AiModelPortfolio _buildArkDisclosureTracker() => AiModelPortfolio(
  id: 'ark-disclosure-tracker',
  name: 'ARK Innovation ETF (ARKK)',
  publicFigureName: 'Cathie Wood',
  publicFigureRole: 'ARK Invest · ARKK',
  portraitAssetPath: 'assets/portraits/cathie_wood.jpg',
  summary: 'A delayed public-holdings reconstruction. Its return is a hypothetical Leo filing-follow simulation, not ARK\'s fund return.',
  trackRecordKind: AiTrackRecordKind.backtest,
  modelVersion: 'leo-ark-disclosure-demo-v1.0.0',
  start: DateTime.utc(2025, 9),
  end: DateTime.utc(2026, 8, 28),
  totalReturnBps: 1980,
  benchmarkLabel: 'S&P 500 hypothetical same-period benchmark',
  benchmarkReturnBps: 1280,
  maxDrawdownMagnitudeBps: 2310,
  bestQuarterBps: 1040,
  worstQuarterBps: -880,
  holdingsAsOf: DateTime.utc(2026, 8, 31),
  sourceDataAsOf: DateTime.utc(2026, 8, 28),
  cadence: 'Hypothetical monthly rebalance from delayed public holdings',
  selectionUniverse:
      'U.S.-listed names represented in publicly available ARK ETF holdings',
  dividendsIncluded: true,
  feeAssumption: '0.30% annualized trading-cost drag; taxes excluded',
  category: AiPortfolioCategory.publicDisclosureTracker,
  holdingsBasis: AiHoldingsBasis.delayedPublicDisclosure,
  affiliationDisclosure: 'Independent educational tracker. No affiliation with or endorsement by Cathie Wood or ARK Invest.',
  sourceDisclosure: 'Deterministic reconstruction inspired by delayed public ETF-holdings patterns. Displayed weights and return series are Leo assumptions and do not reproduce any ARK fund.',
  sectorAllocations: [
    _sector('consumer-discretionary', 'Consumer discretionary', 2500),
    _sector('financials', 'Financials', 2100),
    _sector('communication-services', 'Communication services', 1900),
    _sector('health-care', 'Health care', 1800),
    _sector('technology', 'Technology', 1700),
  ],
  holdings: [
    _holding(
      'ark-tsla',
      'TSLA',
      'Tesla',
      2500,
      'Illustrative public-holdings proxy with high valuation and execution risk.',
    ),
    _holding(
      'ark-coin',
      'COIN',
      'Coinbase',
      2100,
      'Illustrative public-holdings proxy with crypto-cycle sensitivity.',
    ),
    _holding(
      'ark-roku',
      'ROKU',
      'Roku',
      1900,
      'Illustrative public-holdings proxy with advertising-cycle risk.',
    ),
    _holding(
      'ark-crsp',
      'CRSP',
      'CRISPR Therapeutics',
      1800,
      'Illustrative public-holdings proxy with clinical and regulatory risk.',
    ),
    _holding(
      'ark-pltr',
      'PLTR',
      'Palantir Technologies',
      1700,
      'Illustrative public-holdings proxy with concentration and valuation risk.',
    ),
  ],
  returnSeriesBps: const [
    0,
    310,
    660,
    940,
    1280,
    520,
    -1030,
    -420,
    210,
    720,
    1110,
    1540,
    1980,
  ],
  benchmarkReturnSeriesBps: _benchmarkSeries,
);

AiModelPortfolio _buildSorosDisclosureTracker() => AiModelPortfolio(
  id: 'soros-disclosure-tracker',
  name: 'Soros Fund Management',
  publicFigureName: 'George Soros',
  publicFigureRole: 'Soros Fund Management',
  portraitAssetPath: 'assets/portraits/george_soros.jpg',
  summary: 'A delayed 13F reconstruction. Its return is a hypothetical Leo filing-follow simulation, not Soros Fund Management\'s return.',
  trackRecordKind: AiTrackRecordKind.backtest,
  modelVersion: 'leo-soros-disclosure-demo-v1.0.0',
  start: DateTime.utc(2025, 9),
  end: DateTime.utc(2026, 8, 28),
  totalReturnBps: 1710,
  benchmarkLabel: 'S&P 500 hypothetical same-period benchmark',
  benchmarkReturnBps: 1280,
  maxDrawdownMagnitudeBps: 1240,
  bestQuarterBps: 680,
  worstQuarterBps: -410,
  holdingsAsOf: DateTime.utc(2026, 8, 31),
  sourceDataAsOf: DateTime.utc(2026, 6, 30),
  cadence: 'Hypothetical quarterly rebalance after each 13F becomes public',
  selectionUniverse: 'Long common-stock and ADR positions reported on Soros Fund Management 13F filings; notes and options excluded',
  dividendsIncluded: true,
  feeAssumption: '0.25% annualized trading-cost drag; taxes excluded',
  category: AiPortfolioCategory.publicDisclosureTracker,
  holdingsBasis: AiHoldingsBasis.delayedPublicDisclosure,
  affiliationDisclosure: 'Independent educational tracker. No affiliation with or endorsement by George Soros or Soros Fund Management.',
  sourceDisclosure: 'Five-name educational sample from Soros Fund Management\'s SEC Form 13F-HR, CIK 0001029160, report date 2026-06-30, filed 2026-08-14. Sample values are renormalized to 100%; 13F data are delayed and incomplete. Returns are Leo hypothetical calculations.',
  sectorAllocations: [
    _sector('consumer-discretionary', 'Consumer discretionary', 2570),
    _sector('technology', 'Technology', 3670),
    _sector('communication-services', 'Communication services', 3760),
  ],
  holdings: [
    _holding(
      'soros-amzn',
      'AMZN',
      'Amazon',
      2570,
      'Reported long common-stock line; weight is renormalized within this five-name sample.',
    ),
    _holding(
      'soros-tsm',
      'TSM',
      'Taiwan Semiconductor',
      2270,
      'Reported long ADR line illustrating fabrication exposure and geopolitical risk.',
    ),
    _holding(
      'soros-googl',
      'GOOGL',
      'Alphabet',
      1940,
      'Reported long common-stock line; sample weight is not a current portfolio weight.',
    ),
    _holding(
      'soros-ea',
      'EA',
      'Electronic Arts',
      1820,
      'Reported long common-stock line illustrating interactive-entertainment exposure.',
    ),
    _holding(
      'soros-aapl',
      'AAPL',
      'Apple',
      1400,
      'Reported long common-stock line; this delayed sample omits the rest of the filing.',
    ),
  ],
  returnSeriesBps: const [
    0,
    150,
    310,
    520,
    690,
    410,
    -350,
    20,
    390,
    730,
    1040,
    1380,
    1710,
  ],
  benchmarkReturnSeriesBps: _benchmarkSeries,
);

AiModelPortfolio _buildSituationalAwarenessTracker() => AiModelPortfolio(
  id: 'situational-awareness-leopold-tracker',
  name: 'Situational Awareness (Leopold Aschenbrenner)',
  publicFigureName: 'Leopold Aschenbrenner',
  publicFigureRole: 'Situational Awareness LP',
  portraitAssetPath: 'assets/portraits/leopold_aschenbrenner.png',
  summary: '13F reconstruction · hypothetical performance. The displayed return is a Leo filing-follow simulation, never the fund\'s or Leopold Aschenbrenner\'s return.',
  trackRecordKind: AiTrackRecordKind.backtest,
  modelVersion: 'leo-situational-awareness-13f-demo-v1.0.0',
  start: DateTime.utc(2026, 8, 17),
  end: DateTime.utc(2026, 8, 28),
  totalReturnBps: 680,
  benchmarkLabel: 'S&P 500 hypothetical same-period benchmark',
  benchmarkReturnBps: 190,
  maxDrawdownMagnitudeBps: 520,
  bestQuarterBps: 170,
  worstQuarterBps: -520,
  bestPeriodLabel: 'Best day',
  worstPeriodLabel: 'Worst day',
  holdingsAsOf: DateTime.utc(2026, 8, 31),
  sourceDataAsOf: DateTime.utc(2026, 6, 30),
  cadence: 'Hypothetical quarterly rebalance after each 13F becomes public',
  selectionUniverse: 'Long U.S.-listed positions reported on Situational Awareness LP 13F filings; options excluded from normalized weights',
  dividendsIncluded: true,
  feeAssumption: '0.35% annualized trading-cost drag; taxes excluded',
  category: AiPortfolioCategory.publicDisclosureTracker,
  holdingsBasis: AiHoldingsBasis.delayedPublicDisclosure,
  affiliationDisclosure: 'Independent educational tracker. No affiliation with or endorsement by Leopold Aschenbrenner or Situational Awareness LP.',
  sourceDisclosure: 'Top-five common-stock basket reconstructed from SEC Form 13F-HR, CIK 0002045724, report date 2026-06-30, filed 2026-08-14. The simulation begins at the next tradable close, 2026-08-17. 13F data are delayed and incomplete; options, shorts, private assets, and smaller names are omitted. Weights and returns are Leo hypothetical calculations.',
  sectorAllocations: [
    _sector('semiconductors-storage', 'Semiconductors & storage', 7999),
    _sector('power-systems', 'Power systems', 1214),
    _sector('ai-cloud', 'AI cloud infrastructure', 787),
  ],
  holdings: [
    _holding(
      'situational-sndk',
      'SNDK',
      'SanDisk',
      3627,
      'Reported long position; weight is normalized within the five-name educational basket, not the full 13F.',
    ),
    _holding(
      'situational-mu',
      'MU',
      'Micron Technology',
      3563,
      'Reported long position illustrating memory demand and semiconductor-cycle risk.',
    ),
    _holding(
      'situational-be',
      'BE',
      'Bloom Energy',
      1214,
      'Reported long position illustrating power demand alongside execution risk.',
    ),
    _holding(
      'situational-tsm',
      'TSM',
      'Taiwan Semiconductor',
      809,
      'Reported long ADR position illustrating advanced-fabrication and geopolitical risk.',
    ),
    _holding(
      'situational-nbis',
      'NBIS',
      'Nebius Group',
      787,
      'Reported long position illustrating AI cloud infrastructure and concentration risk.',
    ),
  ],
  returnSeriesBps: const [
    0,
    120,
    -400,
    -260,
    -120,
    50,
    210,
    330,
    280,
    520,
    680,
  ],
  benchmarkReturnSeriesBps: const [
    0,
    35,
    10,
    55,
    90,
    75,
    120,
    150,
    130,
    170,
    190,
  ],
);
