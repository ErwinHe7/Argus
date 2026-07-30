import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import ts from 'typescript';

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
const compiledMarketQuery = ts.transpileModule(read('lib/quant/market-query.ts'), {
  compilerOptions: {
    module: ts.ModuleKind.ESNext,
    target: ts.ScriptTarget.ES2022,
  },
}).outputText;
const {
  compileMarketQuery,
  MarketQueryClarificationError,
  requestsNextSessionForecast,
  UnsupportedScheduledEventModelError,
} = await import(
  `data:text/javascript;base64,${Buffer.from(compiledMarketQuery).toString('base64')}`
);
const compiledResearchAnswer = ts.transpileModule(read('lib/quant/research-answer.ts'), {
  compilerOptions: {
    module: ts.ModuleKind.ESNext,
    target: ts.ScriptTarget.ES2022,
  },
}).outputText;
const { formatQuantResearchAnswer } = await import(
  `data:text/javascript;base64,${Buffer.from(compiledResearchAnswer).toString('base64')}`
);

test('market chat remains Rust-owned and has no web forecast fallback', () => {
  const route = read('app/api/ask/route.ts');
  assert.match(route, /requestQuantResearch/);
  assert.match(route, /explainQuantResearchResult/);
  assert.match(route, /answerModelKnowledgeQuestion/);
  assert.doesNotMatch(route, /runForecastChat\s*\(|fetchYahoo|from ['"]@\/lib\/forecast-chat['"]/);
});

test('model-forecast gaps expose a Rust-owned Databento session result', () => {
  const route = read('app/api/ask/route.ts');
  const client = read('lib/quant/research-client.ts');
  const chat = read('components/AxioChat.tsx');
  const rustApi = read('quant_engine_rs/src/api.rs');

  assert.match(
    rustApi,
    /"\/api\/v1\/research\/session-summary"[\s\S]*get\(research_session_summary\)/
  );
  assert.match(rustApi, /build_session_summary/);
  assert.match(rustApi, /databento_market_data\.sqlite3/);
  assert.match(rustApi, /"SPX"[\s\S]*"SPY"/);
  assert.match(rustApi, /"COMPLETE_78_BAR_SESSION"/);
  assert.match(rustApi, /"probability_published":false/);
  assert.match(rustApi, /"automatic_execution_enabled":false/);

  assert.match(client, /requestQuantSessionSummary/);
  assert.match(client, /axio\.session-summary\.v1/);
  assert.match(client, /observed Databento session summary is malformed/);
  assert.match(route, /envelope\.candidates\.length === 0/);
  assert.match(route, /compiled\.query\.setup_type === 'model_forecast'/);
  assert.match(route, /sessionSummaryAnswer/);
  assert.match(chat, /forecast\.sessionSummary/);
  assert.match(chat, /SessionSummaryDetails/);
  assert.match(chat, /Full five-minute session map/);
  assert.doesNotMatch(route, /fetchYahoo|runForecastChat\s*\(/);
});

test('tomorrow SPX questions use the Rust daily-regime and analog contract', () => {
  const route = read('app/api/ask/route.ts');
  const client = read('lib/quant/research-client.ts');
  const chat = read('components/AxioChat.tsx');
  const rustApi = read('quant_engine_rs/src/api.rs');
  const rustDaily = read('quant_engine_rs/src/daily_regime.rs');
  const llm = read('lib/llm.ts');
  const inventory = read('lib/quant/model-code-inventory.ts');

  assert.equal(requestsNextSessionForecast("tomorrow's trend of spx"), true);
  assert.equal(requestsNextSessionForecast('明天 SPX 走势'), true);
  assert.equal(requestsNextSessionForecast('current SPX trend'), false);
  assert.match(
    rustApi,
    /"\/api\/v1\/research\/daily-regime"[\s\S]*get\(research_daily_regime\)/
  );
  assert.match(rustDaily, /axio\.daily-regime\.v1/);
  assert.match(rustDaily, /NEXT_REGULAR_SESSION_ANALOG_LEAN/);
  assert.match(rustDaily, /Raw analog frequencies/);
  assert.match(rustDaily, /probability_published:\s*false/);
  assert.match(rustDaily, /automatic_execution_enabled:\s*false/);
  assert.match(rustDaily, /ranked_analogs\(&rows,\s*current_index,\s*0\)/);
  assert.match(rustDaily, /PURGED_EXPANDING_WALK_FORWARD/);
  assert.match(client, /requestQuantDailyRegime/);
  assert.match(
    client,
    /daily regime and historical analog report is malformed/
  );
  assert.match(route, /requestsNextSessionForecast/);
  assert.match(route, /explainDailyRegimeResult/);
  assert.match(route, /buildMacroReport/);
  assert.match(route, /buildNewsPulseReport/);
  assert.match(route, /modelCodeInventory/);
  assert.match(chat, /DailyRegimeDetails/);
  assert.match(chat, /Most similar historical regimes/);
  assert.match(chat, /Model and algorithm source list/);
  assert.match(llm, /moonshotai\/kimi-k3-free/);
  assert.match(llm, /TOKENROUTER_API_KEY/);
  assert.match(inventory, /production_rust/);
  assert.match(inventory, /offline_python/);
  assert.match(inventory, /native_cpp/);
  assert.doesNotMatch(route, /fetchYahoo|runForecastChat\s*\(/);
});

test('factor scan is a paid Rust-owned metadata-only shadow that fails closed', () => {
  const scanRoute = read('app/api/quant/scan/route.ts');
  const client = read('lib/quant/research-client.ts');
  const rustApi = read('quant_engine_rs/src/api.rs');
  const reasonRoute = read('app/api/quant/reason/route.ts');
  const scannerPage = read('app/quant/scanner/page.tsx');
  const middleware = read('middleware.ts');
  const contractStart = rustApi.indexOf('const FACTOR_SHADOW_SCHEMA_VERSION');
  const contractEnd = rustApi.indexOf('async fn production_readiness_status', contractStart);
  const rustContract = rustApi.slice(contractStart, contractEnd);

  assert.ok(contractStart >= 0 && contractEnd > contractStart);
  assert.match(
    rustApi,
    /"\/api\/v1\/research\/factor-shadow"[\s\S]*get\(factor_shadow_status\)/
  );
  assert.match(rustContract, /CANDIDATE_NOT_PROMOTED/);
  assert.match(rustContract, /momentum:\s*40/);
  assert.match(rustContract, /liquidity_proxy:\s*20/);
  assert.match(rustContract, /regime_and_other_price_volume:\s*40/);
  assert.match(rustContract, /execution:\s*"DISABLED"/);
  assert.doesNotMatch(
    rustContract,
    /\b(?:rank|score|probability|expected_return|target|order|position|quantity)\b/i
  );

  assert.match(scanRoute, /requirePaidResearchAccess/);
  assert.match(scanRoute, /readFactorShadowStatus/);
  assert.match(scanRoute, /code:\s*factorShadow\.candidate\.status/);
  assert.match(scanRoute, /status:\s*503/);
  assert.doesNotMatch(scanRoute, /runQuantScan|fetchQuantSeries|quant\/scanner/);
  assert.match(
    client,
    /fetchQuantJson\('\/api\/v1\/research\/factor-shadow'\)/
  );
  assert.match(client, /RUST_FACTOR_SHADOW_CONTRACT_MISMATCH/);
  assert.match(client, /hasExactKeys\(payload/);

  assert.match(reasonRoute, /NO_VERIFIED_FACTOR_RANK_TO_EXPLAIN/);
  assert.match(reasonRoute, /explainer_invoked:\s*false/);
  assert.doesNotMatch(reasonRoute, /reasonOverScan|OPENAI_API_KEY/);

  assert.match(scannerPage, /40%/);
  assert.match(scannerPage, /20%/);
  assert.match(scannerPage, /CANDIDATE_NOT_PROMOTED/);
  assert.match(scannerPage, /自动执行始终关闭/);
  assert.doesNotMatch(scannerPage, /runQuantScan|ReasonerConsole/);
  assert.match(middleware, /'\/quant\/scanner'/);
  assert.match(middleware, /'\/api\/quant\/scan'/);
  assert.match(middleware, /'\/api\/quant\/reason'/);
});

test('unpromoted FOMC and earnings forecasts fail closed', () => {
  for (const [question, eventKind] of [
    ['predict tomorrow FOMC market reaction', 'fomc_macro'],
    ['预测明天 FOMC 大盘走势', 'fomc_macro'],
    ['forecast NVDA earnings reaction', 'earnings'],
    ['预测苹果财报后的涨跌', 'earnings'],
  ]) {
    assert.throws(
      () => compileMarketQuery(question),
      (error) =>
        error instanceof UnsupportedScheduledEventModelError &&
        error.code === 'SCHEDULED_EVENT_MODEL_NOT_READY' &&
        error.eventKind === eventKind
    );
  }
  const route = read('app/api/ask/route.ts');
  assert.match(route, /UnsupportedScheduledEventModelError/);
  assert.match(route, /scheduled_event_model_not_ready/);
  assert.match(route, /status:\s*422/);
});

test('website status requires exact frozen Rust models to be loaded', () => {
  const client = read('lib/quant/research-client.ts');
  const rustApi = read('quant_engine_rs/src/api.rs');
  assert.match(client, /axio\.model-runtime-receipt\.v1/);
  assert.match(client, /modelStatus !== 'LOADED'/);
  assert.match(client, /loadedModelCount !== requestedModelCount/);
  assert.match(client, /failedModelCount !== 0/);
  assert.match(rustApi, /load_frozen_universe/);
  assert.match(rustApi, /"model_runtime": model_runtime/);
  assert.match(rustApi, /quality_and_promotion_checked_separately/);
  assert.match(rustApi, /automatic_execution_enabled/);
});

test('website feed banner uses the authoritative sanitized readiness receipt', () => {
  const client = read('lib/quant/research-client.ts');
  const chat = read('components/AxioChat.tsx');
  assert.match(client, /\/api\/v1\/system\/readiness/);
  assert.match(client, /axio\.production_readiness\.v2/);
  assert.match(client, /public_use_rights/);
  assert.match(client, /feed_freshness === 'FRESH'/);
  assert.doesNotMatch(client, /fetchQuantJson\('\/api\/v1\/live\/bars'\)/);
  assert.doesNotMatch(client, /fresh_realtime_completed_bar/);
  assert.match(chat, /live feed ready/);
  assert.match(chat, /OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT/);
  assert.match(chat, /not vendor-issued confirmation/);
  assert.doesNotMatch(chat, /licensed feed verified/);
  assert.doesNotMatch(chat, /feed streaming/);
});

test('model connection and publishable market result are separate UI states', () => {
  const chat = read('components/AxioChat.tsx');
  assert.match(chat, /const rustModelLoaded = modelReadinessState === 'ready'/);
  assert.match(chat, /const liveForecastAvailable = candidates\.length > 0/);
  assert.match(chat, /Model artifacts loaded/);
  assert.match(chat, /Model readiness not checked/);
  assert.match(chat, /No live forecast generated/);
  assert.doesNotMatch(chat, /candidateRealtime|candidateContextComplete/);
  for (const stage of [
    'model',
    'feed',
    'context',
    'inference',
    'publication',
  ]) {
    assert.match(
      chat,
      new RegExp(`explicitReadiness\\.${stage}\\?\\.state`),
      `readiness stage ${stage} must come from the explicit receipt`
    );
  }
  for (const stage of [
    'Model artifacts',
    'Live feed',
    'Point-in-time context',
    'Model inference',
    'Forecast publication',
  ]) {
    assert.ok(chat.includes(stage), `missing readiness stage: ${stage}`);
  }
  assert.match(chat, /Model runtime contract/);
});

test('all customer starter prompts compile with explicit rule assumptions', () => {
  const chat = read('components/AxioChat.tsx');
  const prompts = [
    'Monitor upward momentum in QQQ, NVDA, AAPL, MU, SOXX, NBIS, BE and IGV every 5 minutes.',
    'Monitor bullish gamma-squeeze structures in NVDA, AAPL, MU, NBIS and BE over the next 15 minutes.',
    'Which 5-minute bar most often confirms a bearish SPX opening buy exhaustion? Backtest it.',
    'Is SPX or QQQ triggering a bearish VWAP reversal on the latest completed 5-minute bar?',
  ];
  for (const prompt of prompts) {
    assert.ok(chat.includes(prompt), `starter is not wired into the UI: ${prompt}`);
    assert.doesNotThrow(() => compileMarketQuery(prompt));
  }
  const opening = compileMarketQuery(prompts[2]).query;
  assert.equal(opening.setup_type, 'opening_turn');
  assert.equal(opening.intent, 'backtest');
  assert.equal(opening.horizon_minutes, 5);
  assert.equal(opening.filters.direction, 'down');
  const vwap = compileMarketQuery(prompts[3]).query;
  assert.equal(vwap.horizon_minutes, 5);
  assert.equal(vwap.filters.direction, 'down');
});

test('historical analog language remains a core model forecast, not a rule backtest', () => {
  const query = compileMarketQuery(
    'Forecast SPX using historical analogs from a similar market regime'
  ).query;
  assert.equal(query.intent, 'forecast');
  assert.equal(query.setup_type, 'model_forecast');
  assert.equal(query.filters.include_historical, false);
  assert.equal(Object.hasOwn(query.filters, 'direction'), false);
});

test('ordinary live forecast hides unrelated history while an explicit rule backtest may show it', () => {
  const chat = read('components/AxioChat.tsx');

  assert.match(chat, /historicalRequested && envelope\.historical\.length > 0/);
  assert.match(chat, /historical condition replay/);
  assert.match(chat, /styles\.historicalAssessment/);
  assert.match(chat, /row\.net_win_rate/);
  assert.match(chat, /row\.max_drawdown/);
  assert.doesNotMatch(chat, /<span>Net win rate<\/span>/);

  const compiled = compileMarketQuery(
    'backtest bearish statistical dislocation for NVDA over the next 15 minutes'
  );
  assert.equal(compiled.query.intent, 'backtest');
  assert.equal(compiled.query.filters.require_realtime, false);
  assert.equal(compiled.query.filters.include_historical, true);

  const envelope = {
    schema_version: 'axio.evidence-envelope.v1',
    request_id: 'historical-live-stale',
    query_sha256: 'a'.repeat(64),
    generated_at: '2026-07-28T13:32:00Z',
    observation_cutoff: '2026-07-28T13:32:00Z',
    status: 'PARTIAL',
    query: compiled.query,
    candidates: [],
    exclusions: [],
    historical: [
      {
        symbol: 'NVDA',
        setup_type: 'statistical_dislocation',
        method_version: 'causal-vwap-dislocation-5m.v2',
        event_definition: 'Causal completed-bar dislocation.',
        source: 'DATABENTO_EQUS_MINI',
        dataset_start: '2025-01-02',
        dataset_end: '2026-07-24',
        sessions: 390,
        event_sessions: 120,
        event_rate: 120 / 390,
        event_bar_q25: 8,
        event_bar_median: 16,
        event_bar_q75: 28,
        median_clock_et: '10:45-10:50',
        top_event_bars: [],
        forward_label_minutes: 15,
        completed_backtests: 118,
        session_integrity: {
          target_rows: 152100,
          unique_regular_session_rows: 152100,
          exact_duplicate_rows: 0,
          conflicting_duplicate_rows: 0,
          observed_sessions: 390,
          complete_sessions: 390,
          excluded_sessions: 0,
          session_exclusion_counts: {},
        },
        label_integrity: {
          detected_events: 120,
          completed_labels: 118,
          excluded_events: 2,
          event_exclusion_counts: {
            EVENT_TOO_LATE_FOR_EXACT_CLOCK_HORIZON: 1,
            MISSING_CONTIGUOUS_EXACT_CLOCK_HORIZON: 1,
          },
        },
        vwap_status: {
          policy:
            'SESSION_ATOMIC_AUTHORIZED_VENDOR_MINUTE_VWAP_OR_RECONSTRUCTED_CLOSE_VOLUME_PROXY',
          eligible_minute_rows: 152100,
          authorized_vendor_vwap_rows: 0,
          reported_but_unauthorized_vendor_vwap_rows: 0,
          authorized_vendor_minute_coverage: 0,
          sessions_using_authorized_vendor_vwap: 0,
          sessions_using_reconstructed_proxy: 390,
          parity_observations: 0,
          median_absolute_parity_bps: null,
          maximum_absolute_parity_bps: null,
        },
        entry_semantics: 'Next completed five-minute bar open.',
        assumed_round_trip_cost_bps: 3,
        raw_forward_direction_frequency: 0.56,
        median_forward_return: -0.001,
        forward_return_q05: -0.012,
        forward_return_q95: 0.01,
        median_mfe: 0.003,
        median_mae: -0.004,
        net_win_rate: 0.54,
        mean_net_return: 0.0007,
        median_net_return: 0.0005,
        cumulative_net_return: 0.082,
        max_drawdown: -0.041,
        edge_classification: 'POSITIVE_AFTER_COST_DESCRIPTIVE',
        edge_classification_detail:
          'Mean, median, and cumulative returns are positive after stated costs in this exploratory sample; this descriptive result does not establish a statistically validated edge.',
        performance_scope: 'HISTORICAL_CONDITION_REPLAY_NOT_FROZEN_MODEL_OUT_OF_SAMPLE',
        data_manifest_hash: 'b'.repeat(64),
        evidence_grade: 'CONTAMINATED_EXPLORATORY_DESCRIPTIVE',
        caveats: [],
      },
    ],
    data_blockers: ['PUBLIC_MARKET_DATA_FINALIZED_FEED_NOT_FRESH'],
    model_contract: {},
    research_only_policy: {},
    caveats: [],
  };
  const answer = formatQuantResearchAnswer(
    'backtest bearish statistical dislocation for NVDA over the next 15 minutes',
    envelope,
    []
  );
  assert.match(answer, /No live forecast was generated/i);
  assert.match(answer, /POSITIVE AFTER COST DESCRIPTIVE/);
  assert.match(answer, /does not establish a statistically validated edge/i);
  assert.match(answer, /After-cost positive-event share 54\.0%/);
  assert.match(answer, /max drawdown -4\.10%/);
  assert.match(answer, /not the frozen model's out-of-sample result/i);

  const liveAnswer = formatQuantResearchAnswer(
    'NVDA',
    {
      ...envelope,
      query: compileMarketQuery('NVDA').query,
    },
    []
  );
  assert.match(liveAnswer, /No live forecast was generated/i);
  assert.doesNotMatch(
    liveAnswer,
    /positive-event share|historical condition replay|max drawdown|lost money after/i
  );

  const losingEnvelope = structuredClone(envelope);
  losingEnvelope.historical[0].mean_net_return = -0.0007;
  losingEnvelope.historical[0].median_net_return = -0.0005;
  losingEnvelope.historical[0].cumulative_net_return = -0.082;
  losingEnvelope.historical[0].edge_classification = 'NO_DEMONSTRATED_EDGE';
  losingEnvelope.historical[0].edge_classification_detail =
    'This exploratory rule lost money after the stated costs and does not demonstrate an edge.';
  const losingAnswer = formatQuantResearchAnswer(
    'backtest bearish statistical dislocation for NVDA over the next 15 minutes',
    losingEnvelope,
    []
  );
  assert.match(losingAnswer, /NO DEMONSTRATED EDGE/);
  assert.match(
    losingAnswer,
    /lost money after the stated costs and does not demonstrate an edge/i
  );
});

test('uncalibrated model output is visible without publishing probability or trade fields', () => {
  const chat = read('components/AxioChat.tsx');
  const answer = read('lib/quant/research-answer.ts');
  const rustApi = read('quant_engine_rs/src/api.rs');

  for (const source of [chat, answer, rustApi]) {
    assert.match(source, /UNCALIBRATED_RESEARCH_OUTPUT/);
  }
  assert.match(chat, /Model ran · probability withheld/);
  assert.match(chat, /No probability · no trade action/);
  assert.match(answer, /Calibrated probability, expected move, ranking score/);
  assert.match(rustApi, /PROBABILITY_AND_EXPECTED_MOVE_WITHHELD/);
  assert.match(rustApi, /"probability_up_percent":if validated/);
  assert.match(rustApi, /"coverage":1\.0/);
  assert.match(
    rustApi,
    /ALL_REQUIRED_TARGET_AND_CONTEXT_SYMBOLS_PRESENT_AT_THE_DECISION_CUTOFF/,
  );
});

test('customer answer exposes candidate-specific source clocks lineage and caveats', () => {
  const queryCutoff = '2026-07-28T14:30:30Z';
  const observedAt = '2026-07-28T14:29:00Z';
  const availableAt = '2026-07-28T14:29:02Z';
  const generatedAt = '2026-07-28T14:30:31Z';
  const modelHash = 'a'.repeat(64);
  const envelope = {
    schema_version: 'axio.evidence-envelope.v1',
    request_id: 'audit-nvda-v3',
    query_sha256: 'b'.repeat(64),
    response_sha256: 'c'.repeat(64),
    generated_at: generatedAt,
    observation_cutoff: queryCutoff,
    status: 'UNCALIBRATED_RESEARCH_OUTPUT',
    query: {
      schema_version: 'axio.market-query.v1',
      intent: 'scan',
      setup_type: 'statistical_dislocation',
      symbols: ['NVDA'],
      horizon_minutes: 15,
      limit: 1,
      filters: {},
    },
    candidates: [
      {
        symbol: 'NVDA',
        setup_type: 'statistical_dislocation',
        status: 'UNCALIBRATED_RESEARCH_OUTPUT',
        heuristic_structure_score: null,
        score_semantics: 'direction only',
        supporting_evidence: [],
        contrary_evidence: [],
        metrics: {
          statistical_orientation: 'POSITIVE_CONDITIONAL_MEAN',
          observation_cutoff: observedAt,
          latest_input_available_at: availableAt,
          data_source: 'DATABENTO:EQUS.MINI',
          validation: {
            model_version: 'nvda-model-v3',
            feature_version: 'feature-v4',
            model_hash: modelHash,
          },
        },
        freshness: [
          {
            source: 'DATABENTO:EQUS.MINI',
            observed_at: observedAt,
            available_at: availableAt,
            age_seconds: 88,
            realtime: true,
            entitlement: 'LICENSED_REALTIME_SHADOW_EVIDENCE_VERIFIED',
            coverage: 1,
          },
        ],
      },
    ],
    exclusions: [],
    historical: [],
    data_blockers: [],
    model_contract: { model_version: 'legacy-spy-v1' },
    research_only_policy: {},
    caveats: ['Uncalibrated direction only.'],
  };
  const answer = formatQuantResearchAnswer('nvda', envelope, []);
  const formatEt = (value) =>
    `${new Date(value).toLocaleString('en-US', {
      timeZone: 'America/New_York',
    })} ET`;

  assert.match(answer, /DATABENTO:EQUS\.MINI/);
  assert.ok(answer.includes(formatEt(observedAt)));
  assert.ok(answer.includes(formatEt(availableAt)));
  assert.ok(answer.includes(formatEt(queryCutoff)));
  assert.ok(answer.includes(formatEt(generatedAt)));
  assert.match(answer, /nvda-model-v3/);
  assert.match(answer, /feature-v4/);
  assert.match(answer, /Uncalibrated direction only\./);
  assert.match(answer, /Query cutoff/);
  assert.doesNotMatch(answer, /Data cutoff|legacy-spy-v1/);

  const chat = read('components/AxioChat.tsx');
  assert.match(chat, /candidate\.freshness\[0\]/);
  assert.match(chat, /validation\.model_version/);
  assert.match(chat, /validation\.feature_version/);
  assert.match(chat, /envelope\.caveats/);
  assert.doesNotMatch(chat, /envelope\.model_contract\.model_version/);
});

test('grounded explainer cannot own quantitative calculation', () => {
  const conversation = read('lib/quant/conversation.ts');
  assert.match(conversation, /Never calculate prices, Greeks, GEX/);
  assert.match(conversation, /hasUnsupportedNumber/);
  assert.match(conversation, /deterministic_fallback/);
  assert.match(conversation, /Rust research result/);
});

test('model knowledge covers the configured public universe and model boundary', () => {
  const knowledge = read('lib/quant/model-knowledge.ts');
  for (const symbol of ['SPX', 'QQQ', 'NVDA', 'AAPL', 'MU', 'SOXX', 'NBIS', 'BE', 'IGV']) {
    assert.match(knowledge, new RegExp(`\\b${symbol}\\b`));
  }
  for (const concept of [
    'hidden-state regime',
    'Markov-switching',
    'Ornstein-Uhlenbeck',
    'causal temporal convolutional network',
    'redistributable realtime',
  ]) {
    assert.ok(knowledge.includes(concept), `missing model knowledge: ${concept}`);
  }
});

test('allow-listed ticker parsing is case-insensitive without falling back to the default universe', () => {
  const bare = compileMarketQuery('nvda').query;
  assert.deepEqual(bare.symbols, ['NVDA']);
  assert.equal(bare.version, 'axio.market-query.v2');
  assert.equal(bare.intent, 'forecast');
  assert.equal(bare.setup_type, 'model_forecast');
  assert.equal(bare.filters.include_historical, false);
  assert.equal(bare.filters.require_realtime, true);
  assert.equal(Object.hasOwn(bare, 'horizon_minutes'), false);
  assert.equal(Object.hasOwn(bare.filters, 'direction'), false);
  assert.deepEqual(compileMarketQuery('scan nvda now').query.symbols, ['NVDA']);
  assert.deepEqual(compileMarketQuery('live $qqq').query.symbols, ['QQQ']);
  assert.deepEqual(compileMarketQuery('be').query.symbols, ['BE']);
  assert.deepEqual(
    compileMarketQuery('What should be monitored today?').query.symbols,
    ['SPX', 'QQQ', 'NVDA', 'AAPL', 'MU', 'SOXX', 'NBIS', 'BE', 'IGV']
  );
});

test('research UI persists locale, shows interpreted inputs, recovery controls, and explainer provenance', () => {
  const route = read('app/api/ask/route.ts');
  const conversation = read('lib/quant/conversation.ts');
  const chat = read('components/AxioChat.tsx');
  const css = read('components/AxioChat.module.css');

  assert.match(conversation, /locale:\s*'en-US'\s*\|\s*'zh-CN'/);
  assert.match(conversation, /conversationLocale/);
  assert.match(route, /locale:\s*conversation\.locale/);
  assert.match(route, /X-AXIO7-Conversation-Locale/);
  assert.match(chat, /AXIO7 interpreted query/);
  assert.match(chat, /SPX → SPY \(price\/volume and VWAP proxy\)/);
  assert.match(chat, /Model-owned \(not assumed\)/);
  assert.match(chat, /No setup, direction, or horizon inferred from a ticker/);
  assert.match(chat, /Retry live/);
  assert.match(chat, /View readiness/);
  assert.match(chat, /Set up historical replay/);
  assert.match(chat, /Change assumptions/);
  assert.match(chat, /Grounded language explanation/);
  assert.match(chat, /Deterministic fallback explanation/);
  assert.match(chat, /automatic execution is always disabled/);

  for (const [selector, minimum] of [
    ['readinessStrip b', 11],
    ['readinessStrip small', 10],
    ['reportMeta', 11],
    ['signalLineage p', 10],
    ['reportDisclaimer', 10],
  ]) {
    const escaped = selector.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const match = css.match(
      new RegExp(`\\.${escaped}\\s*\\{[^}]*font-size:\\s*(\\d+)px`, 's')
    );
    assert.ok(match, `missing readable typography rule for ${selector}`);
    assert.ok(
      Number(match[1]) >= minimum,
      `${selector} must be at least ${minimum}px`
    );
  }
});

test('model forecasts are ordered and summarized by horizon with promoted probability fail-closed', () => {
  const observedAt = '2026-07-28T14:29:00Z';
  const availableAt = '2026-07-28T14:29:02Z';
  const candidate = ({
    horizon,
    status = 'UNCALIBRATED_RESEARCH_OUTPUT',
    publicationStatus =
      'WITHHELD_NO_MATCHING_PROMOTED_OOS_CALIBRATION',
    calibrationStatus = 'CANDIDATE_NOT_PROMOTED',
    probabilityUp = null,
  }) => ({
    symbol: 'SPX',
    setup_type: 'model_forecast',
    status,
    heuristic_structure_score: null,
    score_semantics: 'model condition',
    supporting_evidence: [],
    contrary_evidence: [],
    metrics: {
      horizon_minutes: horizon,
      statistical_orientation: 'POSITIVE_CONDITIONAL_MEAN',
      observation_cutoff: observedAt,
      latest_input_available_at: availableAt,
      data_source: 'DATABENTO:EQUS.MINI',
      published_probability_status: publicationStatus,
      probability_up_percent: probabilityUp,
      validation: {
        calibration_status: calibrationStatus,
        model_version: 'spx-v3',
        feature_version: 'feature-v4',
        model_hash: 'a'.repeat(64),
      },
    },
    freshness: [
      {
        source: 'DATABENTO:EQUS.MINI',
        observed_at: observedAt,
        available_at: availableAt,
        age_seconds: 88,
        realtime: true,
        entitlement: 'LICENSED_REALTIME_SHADOW_EVIDENCE_VERIFIED',
        coverage: 1,
      },
    ],
  });
  const envelope = {
    schema_version: 'axio.evidence-envelope.v1',
    request_id: 'multi-horizon-spx',
    query_sha256: 'b'.repeat(64),
    generated_at: '2026-07-28T14:30:31Z',
    observation_cutoff: '2026-07-28T14:30:30Z',
    status: 'UNCALIBRATED_RESEARCH_OUTPUT',
    query: compileMarketQuery('SPX').query,
    candidates: [candidate({ horizon: 60 }), candidate({ horizon: 5 })],
    exclusions: [],
    historical: [],
    data_blockers: [],
    model_contract: {},
    research_only_policy: {},
    caveats: [],
  };
  const answer = formatQuantResearchAnswer('SPX', envelope, []);
  assert.ok(answer.indexOf('5-minute horizon') < answer.indexOf('60-minute horizon'));
  assert.match(answer, /5-minute horizon: uncalibrated direction state/i);
  assert.match(answer, /60-minute horizon: uncalibrated direction state/i);

  const promoted = formatQuantResearchAnswer(
    'SPX',
    {
      ...envelope,
      status: 'AVAILABLE',
      candidates: [
        candidate({
          horizon: 15,
          status: 'VALIDATED_STATISTICAL_CANDIDATE',
          publicationStatus:
            'PROMOTED_BINARY_UP_ONLY_NO_JOINT_MULTICLASS_CALIBRATION',
          calibrationStatus: 'PROMOTED_OOS_CALIBRATION_APPLIED',
          probabilityUp: 58.4,
        }),
      ],
    },
    []
  );
  assert.match(promoted, /calibrated binary P\(up\) 58\.4%/i);
  assert.match(promoted, /Down and flat are not jointly calibrated/i);
  assert.doesNotMatch(promoted, /session VWAP|Latest completed five-minute bar/i);

  const incompleteReceipt = formatQuantResearchAnswer(
    'SPX',
    {
      ...envelope,
      status: 'AVAILABLE',
      candidates: [
        candidate({
          horizon: 15,
          status: 'VALIDATED_STATISTICAL_CANDIDATE',
          publicationStatus:
            'PROMOTED_BINARY_UP_ONLY_NO_JOINT_MULTICLASS_CALIBRATION',
          probabilityUp: 99,
        }),
      ],
    },
    []
  );
  assert.doesNotMatch(incompleteReceipt, /P\(up\) 99\.0%/i);
  assert.match(incompleteReceipt, /publication receipt is incomplete/i);

  const chat = read('components/AxioChat.tsx');
  assert.match(chat, /candidateHorizonMinutes/);
  assert.match(
    chat,
    /candidate\.symbol}-\$\{\s*candidate\.setup_type}-\$\{/
  );
  assert.match(chat, /PROMOTED_OOS_CALIBRATION_APPLIED/);
});

test('rule queries and generic backtests request missing assumptions instead of inventing them', () => {
  assert.throws(
    () => compileMarketQuery('momentum NVDA'),
    (error) =>
      error instanceof MarketQueryClarificationError &&
      error.missingFields.includes('direction') &&
      error.missingFields.includes('horizon_minutes')
  );
  assert.throws(
    () => compileMarketQuery('backtest NVDA'),
    (error) =>
      error instanceof MarketQueryClarificationError &&
      error.setupType === null &&
      error.missingFields.includes('setup_type') &&
      error.missingFields.includes('direction') &&
      error.missingFields.includes('horizon_minutes')
  );
  const route = read('app/api/ask/route.ts');
  assert.match(route, /market_query_needs_clarification/);
  assert.match(route, /missing_fields/);
});

test('query v2 rollout preserves stored v1 explicit-rule monitors', () => {
  const rustQuery = read('quant_engine_rs/src/market_query.rs');
  const schema = read('lib/quant/market-query-schema.ts');
  const migration = read('supabase/migrations/025_market_query_v2.sql');
  assert.match(rustQuery, /LEGACY_MARKET_QUERY_SCHEMA_VERSION/);
  assert.match(schema, /axio\.market-query\.v1[\s\S]*axio\.market-query\.v2/);
  assert.match(migration, /axio\.market-query\.v1/);
  assert.match(migration, /axio\.market-query\.v2/);
  assert.match(migration, /model_forecast/);
});

test('Google OAuth remains server-session based with the production callback', () => {
  const signin = read('app/auth/signin/page.tsx');
  const callback = read('app/auth/callback/route.ts');
  assert.match(signin, /provider:\s*'google'/);
  assert.match(signin, /window\.location\.origin}\/auth\/callback/);
  assert.match(callback, /exchangeCodeForSession/);
});
