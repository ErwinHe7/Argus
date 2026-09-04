import type {
  QuantEvidenceEnvelope,
  QuantHistoricalStats,
  QuantResearchCandidate,
} from '@/lib/forecast-chat-types';

function isChinese(_text: string) {
  return false;
}

function pct(value: unknown, digits = 1) {
  return typeof value === 'number' && Number.isFinite(value)
    ? `${(value * 100).toFixed(digits)}%`
    : 'unavailable';
}

function num(value: unknown, digits = 2) {
  return typeof value === 'number' && Number.isFinite(value)
    ? value.toFixed(digits)
    : 'unavailable';
}

function historicalEdgeSummary(row: QuantHistoricalStats, chinese: boolean) {
  if (!chinese) {
    return `After-cost assessment - ${row.edge_classification.replaceAll(
      '_',
      ' '
    )}: ${row.edge_classification_detail}`;
  }
  if (row.edge_classification === 'INSUFFICIENT_EVIDENCE') {
    return '\u6263\u9664\u6210\u672c\u540e\u8bc4\u4f30\uff1a\u5b8c\u6574\u6536\u76ca\u6307\u6807\u4e0d\u8db3\uff0c\u4e0d\u80fd\u5f97\u51fa\u4f18\u52bf\u7ed3\u8bba\u3002';
  }
  if (row.edge_classification === 'POSITIVE_AFTER_COST_DESCRIPTIVE') {
    return '\u6263\u9664\u6210\u672c\u540e\u8bc4\u4f30\uff1a\u63cf\u8ff0\u6027\u6837\u672c\u4e2d\u7684\u5e73\u5747\u3001\u4e2d\u4f4d\u548c\u7d2f\u8ba1\u6536\u76ca\u5747\u4e3a\u6b63\uff0c\u4f46\u8fd9\u4e0d\u8bc1\u660e\u7edf\u8ba1\u4e0a\u7684\u4f18\u52bf\u3002';
  }
  return typeof row.cumulative_net_return === 'number' &&
    row.cumulative_net_return < 0
    ? '\u6263\u9664\u6210\u672c\u540e\u8bc4\u4f30\uff1a\u8be5\u63a2\u7d22\u6027\u89c4\u5219\u5728\u6240\u5217\u6210\u672c\u540e\u4e8f\u635f\uff0c\u6ca1\u6709\u663e\u793a\u51fa\u4f18\u52bf\u3002'
    : '\u6263\u9664\u6210\u672c\u540e\u8bc4\u4f30\uff1a\u81f3\u5c11\u4e00\u9879\u5e73\u5747\u3001\u4e2d\u4f4d\u6216\u7d2f\u8ba1\u6536\u76ca\u4e0d\u4e3a\u6b63\uff0c\u6ca1\u6709\u663e\u793a\u51fa\u4f18\u52bf\u3002';
}

function chineseBlocker(blocker: string) {
  if (/AWAITING_FIRST_FINALIZED_LIVE_FORECAST/i.test(blocker)) {
    return '实时推理管线尚未为该标的发布第一份完整预测';
  }
  if (
    /PUBLIC_MARKET_DATA_(?:RIGHTS|.*LICENSE)|LICENSE.*NOT_CONFIGURED|REDISTRIBUTION/i.test(
      blocker
    )
  ) {
    return '尚未配置允许向网站用户展示或再分发的实时市场数据授权';
  }
  if (/MODEL.*(?:NOT_PROMOTED|UNPROMOTED)|PROMOTION/i.test(blocker)) {
    return '当前预测工件尚未通过独立样本外验证和正式晋升';
  }
  if (/OPRA|OPTION.*CHAIN|OPEN_INTEREST|GREEKS/i.test(blocker)) {
    return `期权数据不完整：${blocker}`;
  }
  if (/STALE|FRESH/i.test(blocker)) {
    return `数据时效未通过检查：${blocker}`;
  }
  if (/COVERAGE|INCOMPLETE/i.test(blocker)) {
    return `数据覆盖率未通过检查：${blocker}`;
  }
  return blocker;
}

function englishBlocker(blocker: string) {
  const symbol = blocker.match(/^([A-Z][A-Z0-9.]{0,9}):/)?.[1];
  const subject = symbol ? `${symbol}: ` : '';
  if (/AWAITING_FIRST_FINALIZED_LIVE_FORECAST/i.test(blocker)) {
    return `${subject}the live inference pipeline has not published its first finalized forecast yet.`;
  }
  if (/LIVE_FORECAST_NOT_PUBLISHED/i.test(blocker)) {
    return `${subject}the model has not published a complete live forecast batch.`;
  }
  if (/MODEL_FORECAST_HORIZON_MISSING/i.test(blocker)) {
    const horizon = blocker.match(/horizon_minutes=(5|15|30|60)/i)?.[1];
    return `${subject}the required${horizon ? ` ${horizon}-minute` : ''} model horizon was not published.`;
  }
  if (
    /PUBLIC_MARKET_DATA_(?:RIGHTS|.*LICENSE)|LICENSE.*NOT_CONFIGURED|REDISTRIBUTION/i.test(
      blocker
    )
  ) {
    return `${subject}this request is publication-gated, and its realtime market-data rights receipt is not active.`;
  }
  if (/MODEL.*(?:NOT_PROMOTED|UNPROMOTED)|PROMOTION/i.test(blocker)) {
    return `${subject}the required model or calibration artifact is not promoted for publication.`;
  }
  if (/OPRA|OPTION.*CHAIN|OPEN_INTEREST|GREEKS/i.test(blocker)) {
    return `${subject}the required options-chain fields are incomplete.`;
  }
  if (/STALE|FRESH/i.test(blocker)) {
    return `${subject}the latest completed market observation did not pass the freshness gate.`;
  }
  if (/CONTEXT|COVERAGE|INCOMPLETE|MISSING/i.test(blocker)) {
    return `${subject}one or more required point-in-time inputs are incomplete at the common cutoff.`;
  }
  if (/REALTIME_FORECAST_UNIVERSE_NOT_READY|NO_FRESH_CANDIDATES/i.test(blocker)) {
    return `${subject}no fresh, compatible live forecast artifact is available for this request.`;
  }
  return `${subject}a required live-data, inference, or publication gate did not pass.`;
}

function outsideUsRegularSession(timestamp: string) {
  const date = new Date(timestamp);
  if (Number.isNaN(date.getTime())) return false;
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'America/New_York',
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);
  const value = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((part) => part.type === type)?.value;
  const weekday = value('weekday');
  const hour = Number(value('hour'));
  const minute = Number(value('minute'));
  if (
    weekday === undefined ||
    !Number.isInteger(hour) ||
    !Number.isInteger(minute)
  ) {
    return false;
  }
  const minutes = hour * 60 + minute;
  return (
    weekday === 'Sat' ||
    weekday === 'Sun' ||
    minutes < 9 * 60 + 30 ||
    minutes >= 16 * 60
  );
}

function blockerSummary(envelope: QuantEvidenceEnvelope, chinese: boolean) {
  const blockers = envelope.data_blockers.slice(0, 6);
  if (blockers.length === 0) {
    return chinese
      ? '当前没有通过全部数据与模型门控的候选。'
      : 'No candidate passed every data and model readiness gate.';
  }
  if (
    envelope.query.setup_type === 'model_forecast' &&
    outsideUsRegularSession(envelope.observation_cutoff)
  ) {
    return chinese
      ? '该请求发生在模型的美国常规交易时段之外（美东时间上午 9:30 至下午 4:00）；盘后行情不会生成新的实时预测批次。'
      : 'This request was made outside the model’s regular U.S. session window (9:30 a.m.–4:00 p.m. ET); extended-hours bars do not produce a new live forecast batch.';
  }
  const lines = Array.from(
    new Set(
      blockers.map((blocker) =>
        chinese ? chineseBlocker(blocker) : englishBlocker(blocker)
      )
    )
  )
    .map((line) => `- ${line}`)
    .join('\n');
  return chinese
    ? `本次请求没有生成实时预测：\n${lines}`
    : `No live forecast was generated for this request:\n${lines}`;
}

function gammaSummary(candidate: QuantResearchCandidate, chinese: boolean) {
  const score = candidate.heuristic_structure_score;
  const metrics = candidate.metrics;
  const contrary =
    candidate.contrary_evidence
      .slice(0, 3)
      .map((item) => item.statement)
      .join(chinese ? '；' : '; ') ||
    (chinese ? '没有记录额外反向证据' : 'none recorded');

  if (chinese) {
    return [
      `${candidate.symbol}：${candidate.status}；结构分 ${num(
        score,
        1
      )}/100，这不是上涨概率。`,
      `现价上下 2% 内的 unsigned gamma 占比 ${pct(
        metrics.unsigned_gamma_share_within_two_pct
      )}；Call gamma 占比 ${pct(
        metrics.call_share_unsigned_gamma
      )}；Call 成交占比 ${pct(
        metrics.call_volume_share
      )}；Call volume/OI ${num(
        metrics.call_volume_open_interest_ratio
      )}。`,
      `反向证据：${contrary}。`,
    ].join('\n');
  }

  return [
    `${candidate.symbol}: ${candidate.status}; structure score ${num(
      score,
      1
    )}/100, not an upside probability.`,
    `Unsigned gamma within 2% of spot ${pct(
      metrics.unsigned_gamma_share_within_two_pct
    )}; call gamma share ${pct(
      metrics.call_share_unsigned_gamma
    )}; call-volume share ${pct(
      metrics.call_volume_share
    )}; call volume/OI ${num(
      metrics.call_volume_open_interest_ratio
    )}.`,
    `Counter-evidence: ${contrary}.`,
  ].join('\n');
}

function historicalSummary(row: QuantHistoricalStats, chinese: boolean) {
  const barRange = `${num(row.event_bar_q25, 0)}–${num(
    row.event_bar_q75,
    0
  )}`;
  const samplePeriod = `${row.dataset_start ?? 'unavailable'}–${
    row.dataset_end ?? 'unavailable'
  }`;
  if (chinese) {
    const definition =
      row.setup_type === 'opening_turn'
        ? '开盘后两小时内，先出现可测的上涨推进，随后出现首根满足衰竭条件的完整 5 分钟线'
        : row.setup_type === 'vwap_reversal'
          ? '首根从因果 session VWAP 一侧有效收盘穿越至另一侧的完整 5 分钟线'
          : row.event_definition;
    return [
      historicalEdgeSummary(row, true),
      `${row.symbol} 历史回测（${samplePeriod}）：${definition}。`,
      `${row.sessions} 个交易日中有 ${row.event_sessions} 次符合，其中 ${row.completed_backtests} 次具备完整的远期标签；事件出现率 ${pct(
        row.event_rate
      )}。中位数是第 ${num(row.event_bar_median, 0)} 根（${
        row.median_clock_et ?? '时间不可用'
      }），中间 50% 位于第 ${barRange} 根。`,
      `信号完成后的下一根 5 分钟线开盘进入，${row.forward_label_minutes} 分钟后退出；假设往返成本 ${num(
        row.assumed_round_trip_cost_bps,
        1
      )} bps。扣除成本后胜率 ${pct(row.net_win_rate)}，平均/中位净收益 ${pct(
        row.mean_net_return,
        2
      )} / ${pct(row.median_net_return, 2)}，逐事件复合净收益 ${pct(
        row.cumulative_net_return,
        2
      )}，最大回撤 ${pct(row.max_drawdown, 2)}。`,
      `作为核对，触发后 ${row.forward_label_minutes} 分钟标的按查询方向继续运行的原始频率为 ${pct(
        row.raw_forward_direction_frequency
      )}，标的原始中位收益 ${pct(
        row.median_forward_return,
        2
      )}，q05/q95 为 ${pct(row.forward_return_q05, 2)} / ${pct(
        row.forward_return_q95,
        2
      )}。`,
      `证据等级：${row.evidence_grade}。这是历史条件回放，不是冻结模型的样本外成绩，也不是校准概率。`,
    ].join('\n');
  }

  return [
    `${row.symbol} historical condition replay (${samplePeriod}): ${row.event_definition}`,
    historicalEdgeSummary(row, false),
    `${row.event_sessions} of ${row.sessions} sessions matched (${pct(
      row.event_rate
    )}); ${row.completed_backtests} have complete forward labels. Median event bar ${num(row.event_bar_median, 0)} (${
      row.median_clock_et ?? 'time unavailable'
    }); interquartile bar range ${barRange}.`,
    `Enter at the next five-minute bar open and exit after ${row.forward_label_minutes} minutes; assumed round-trip cost ${num(
      row.assumed_round_trip_cost_bps,
      1
    )} bps. After-cost positive-event share ${pct(row.net_win_rate)}; mean/median net return ${pct(
      row.mean_net_return,
      2
    )} / ${pct(row.median_net_return, 2)}; event-by-event compounded net return ${pct(
      row.cumulative_net_return,
      2
    )}; max drawdown ${pct(row.max_drawdown, 2)}.`,
    `Raw directional continuation frequency over ${row.forward_label_minutes} minutes: ${pct(
      row.raw_forward_direction_frequency
    )}; underlying median return ${pct(
      row.median_forward_return,
      2
    )}; q05/q95 ${pct(row.forward_return_q05, 2)} / ${pct(
      row.forward_return_q95,
      2
    )}.`,
    `Evidence grade: ${row.evidence_grade}. This is a historical condition replay, not the frozen model's out-of-sample result and not a calibrated probability.`,
  ].join('\n');
}

function modelOrientationLabel(value: unknown, chinese: boolean) {
  if (value === 'POSITIVE_CONDITIONAL_MEAN') {
    return chinese ? '\u6b63\u5411\u6761\u4ef6\u5747\u503c' : 'positive conditional mean';
  }
  if (value === 'NEGATIVE_CONDITIONAL_MEAN') {
    return chinese ? '\u8d1f\u5411\u6761\u4ef6\u5747\u503c' : 'negative conditional mean';
  }
  return chinese ? '\u65b9\u5411\u72b6\u6001\u4e0d\u53ef\u7528' : 'directional state unavailable';
}

function asRecord(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

function metricString(value: unknown) {
  return typeof value === 'string' && value.trim() ? value : undefined;
}

const PROMOTED_BINARY_UP_PUBLICATION_STATUS =
  'PROMOTED_BINARY_UP_ONLY_NO_JOINT_MULTICLASS_CALIBRATION';
const PROMOTED_CALIBRATION_STATUS = 'PROMOTED_OOS_CALIBRATION_APPLIED';

function candidateHorizonMinutes(candidate: QuantResearchCandidate) {
  const value = candidate.metrics.horizon_minutes;
  return typeof value === 'number' &&
    Number.isSafeInteger(value) &&
    value > 0
    ? value
    : null;
}

function orderedCandidates(candidates: QuantResearchCandidate[]) {
  return [...candidates].sort((left, right) => {
    const symbolOrder = left.symbol.localeCompare(right.symbol);
    if (symbolOrder !== 0) return symbolOrder;
    const leftHorizon = candidateHorizonMinutes(left) ?? Number.MAX_SAFE_INTEGER;
    const rightHorizon =
      candidateHorizonMinutes(right) ?? Number.MAX_SAFE_INTEGER;
    if (leftHorizon !== rightHorizon) return leftHorizon - rightHorizon;
    return left.status.localeCompare(right.status);
  });
}

function publishedProbabilityUp(candidate: QuantResearchCandidate) {
  const validation = asRecord(candidate.metrics.validation);
  const probability = candidate.metrics.probability_up_percent;
  if (
    candidate.status !== 'VALIDATED_STATISTICAL_CANDIDATE' ||
    candidate.metrics.published_probability_status !==
      PROMOTED_BINARY_UP_PUBLICATION_STATUS ||
    validation.calibration_status !== PROMOTED_CALIBRATION_STATUS ||
    typeof probability !== 'number' ||
    !Number.isFinite(probability) ||
    probability < 0 ||
    probability > 100
  ) {
    return null;
  }
  return probability;
}

function modelForecastSummary(
  candidate: QuantResearchCandidate,
  chinese: boolean
) {
  const horizon = candidateHorizonMinutes(candidate);
  const horizonLabel =
    horizon === null
      ? chinese
        ? '预测周期不可用'
        : 'horizon unavailable'
      : chinese
        ? `${horizon} 分钟`
        : `${horizon}-minute horizon`;
  const orientation = modelOrientationLabel(
    candidate.metrics.statistical_orientation,
    chinese
  );
  const probabilityUp = publishedProbabilityUp(candidate);
  if (probabilityUp !== null) {
    return chinese
      ? `${candidate.symbol} · ${horizonLabel}：模型方向状态为${orientation}。经晋升的样本外校准二元 P(up) 为 ${probabilityUp.toFixed(
          1
        )}%。Down 与 Flat 尚未联合校准；这不是交易动作。`
      : `${candidate.symbol} · ${horizonLabel}: model direction state ${orientation}. Promoted out-of-sample calibrated binary P(up) ${probabilityUp.toFixed(
          1
        )}%. Down and flat are not jointly calibrated; no trade action is produced.`;
  }
  const rawExpectedReturn = candidate.metrics.expected_return;
  if (
    candidate.status === 'UNCALIBRATED_RESEARCH_OUTPUT' &&
    typeof rawExpectedReturn === 'number' &&
    Number.isFinite(rawExpectedReturn)
  ) {
    const quantiles = Array.isArray(candidate.metrics.return_quantiles)
      ? candidate.metrics.return_quantiles.map(asRecord)
      : [];
    const quantile = (probability: number) =>
      quantiles.find(
        (point) =>
          typeof point.probability === 'number' &&
          Math.abs(point.probability - probability) < 1e-6
      )?.value;
    const lower = quantile(0.25);
    const upper = quantile(0.75);
    const rawDirectionFrequency =
      candidate.metrics.statistical_orientation ===
      'POSITIVE_CONDITIONAL_MEAN'
        ? candidate.metrics.raw_analog_up_frequency
        : candidate.metrics.raw_analog_down_frequency;
    return chinese
      ? `${candidate.symbol} · ${horizonLabel}：未校准方向为${orientation}；原始条件均值 ${pct(
          rawExpectedReturn,
          2
        )}，历史邻居中间 50% 为 ${pct(lower, 2)} 至 ${pct(
          upper,
          2
        )}，同方向原始频率 ${pct(rawDirectionFrequency)}。这些是本机实时研究诊断，不是校准概率、公开数据发布或交易指令。`
      : `${candidate.symbol} · ${horizonLabel}: uncalibrated direction ${orientation}; raw conditional mean ${pct(
          rawExpectedReturn,
          2
        )}, historical-neighbor middle 50% ${pct(lower, 2)} to ${pct(
          upper,
          2
        )}, raw same-direction frequency ${pct(
          rawDirectionFrequency
        )}. These are loopback live-research diagnostics, not calibrated probabilities, public data publication, or trade instructions.`;
  }
  const validated =
    candidate.status === 'VALIDATED_STATISTICAL_CANDIDATE';
  return chinese
    ? `${candidate.symbol} · ${horizonLabel}：${
        validated ? '模型条件已验证，但概率发布回执不完整' : `未校准方向状态为${orientation}`
      }。校准概率、预期涨跌幅、排名分数与交易动作均保持隐藏。`
    : `${candidate.symbol} · ${horizonLabel}: ${
        validated
          ? 'the model condition is validated, but its promoted probability publication receipt is incomplete'
          : `uncalibrated direction state ${orientation}`
      }. Calibrated probability, expected move, ranking score, and every trade action remain withheld.`;
}

function formatEt(value: unknown, chinese: boolean) {
  const raw = metricString(value);
  if (!raw) return chinese ? '不可用' : 'unavailable';
  const parsed = new Date(raw);
  if (Number.isNaN(parsed.valueOf())) return chinese ? '不可用' : 'unavailable';
  return `${parsed.toLocaleString(chinese ? 'zh-CN' : 'en-US', {
    timeZone: 'America/New_York',
  })} ET`;
}

function candidateProvenance(
  candidate: QuantResearchCandidate,
  chinese: boolean
) {
  const freshness = candidate.freshness[0];
  const validation = asRecord(candidate.metrics.validation);
  const source =
    freshness?.source ??
    metricString(candidate.metrics.data_source) ??
    (chinese ? '来源不可用' : 'source unavailable');
  const observedAt =
    freshness?.observed_at ?? candidate.metrics.observation_cutoff;
  const availableAt =
    freshness?.available_at ?? candidate.metrics.latest_input_available_at;
  const age =
    typeof freshness?.age_seconds === 'number'
      ? `${freshness.age_seconds}s`
      : chinese
        ? '不可用'
        : 'unavailable';
  const entitlement =
    freshness?.entitlement ?? (chinese ? '授权不可用' : 'entitlement unavailable');
  const modelVersion =
    metricString(validation.model_version) ?? (chinese ? '模型版本不可用' : 'model unavailable');
  const featureVersion =
    metricString(validation.feature_version) ?? (chinese ? '特征版本不可用' : 'feature unavailable');
  const modelHash = metricString(validation.model_hash)?.slice(0, 12) ?? 'unavailable';

  return chinese
    ? `${candidate.symbol} 数据来源 ${source}；观测截止 ${formatEt(observedAt, true)}；可用时间 ${formatEt(availableAt, true)}；数据年龄 ${age}；覆盖率 ${pct(freshness?.coverage)}；授权 ${entitlement}；模型 ${modelVersion}；特征 ${featureVersion}；模型哈希 ${modelHash}。`
    : `${candidate.symbol} source ${source}; observed ${formatEt(observedAt, false)}; available ${formatEt(availableAt, false)}; age ${age}; coverage ${pct(freshness?.coverage)}; entitlement ${entitlement}; model ${modelVersion}; feature ${featureVersion}; model hash ${modelHash}.`;
}

export function formatQuantResearchAnswer(
  question: string,
  envelope: QuantEvidenceEnvelope,
  compilerNotes: string[]
) {
  const chinese = isChinese(question);
  const sections: string[] = [];
  const historicalRequested =
    envelope.query.filters.include_historical === true;
  const candidates = orderedCandidates(envelope.candidates);

  if (envelope.status === 'DATA_UNAVAILABLE') {
    sections.push(blockerSummary(envelope, chinese));
  } else if (
    envelope.status === 'PARTIAL' &&
    envelope.historical.length > 0 &&
    historicalRequested
  ) {
    sections.push(
      chinese
        ? `本次请求没有生成实时预测。下方仅显示您明确要求的探索性历史条件回放；它不是当前冻结模型的样本外成绩。`
        : `No live forecast was generated. The explicitly requested exploratory historical condition replay appears below; it is not out-of-sample performance from the current frozen model.`
    );
    sections.push(blockerSummary(envelope, chinese));
  } else if (envelope.status === 'PARTIAL') {
    sections.push(blockerSummary(envelope, chinese));
  } else if (
    envelope.query.setup_type === 'model_forecast' &&
    candidates.length > 0
  ) {
    sections.push(
      candidates
        .map((candidate) => modelForecastSummary(candidate, chinese))
        .join('\n')
    );
  } else if (
    envelope.status === 'UNCALIBRATED_RESEARCH_OUTPUT' &&
    candidates.length > 0
  ) {
    const candidate = candidates[0];
    const orientation = modelOrientationLabel(
      candidate.metrics.statistical_orientation,
      chinese
    );
    sections.push(
      chinese
        ? `${candidate.symbol} \u6a21\u578b\u5df2\u5b8c\u6210\u672c\u6b21\u5b9e\u65f6\u63a8\u7406\u3002\u672a\u6821\u51c6\u65b9\u5411\u72b6\u6001\uff1a${orientation}\u3002\u6821\u51c6\u6982\u7387\u3001\u9884\u671f\u6da8\u8dcc\u5e45\u3001\u6392\u540d\u5206\u6570\u4e0e\u4ea4\u6613\u52a8\u4f5c\u5747\u5df2\u64a4\u56de\uff1b\u8fd9\u4e0d\u662f\u6295\u8d44\u5efa\u8bae\u3002`
        : `${candidate.symbol} completed a fresh model inference. Uncalibrated direction state: ${orientation}. Calibrated probability, expected move, ranking score, and every trade action remain withheld.`
    );
  } else if (envelope.query.setup_type === 'gamma_squeeze') {
    sections.push(
      candidates.length === 0
        ? blockerSummary(envelope, chinese)
        : candidates
            .slice(0, envelope.query.limit)
            .map((candidate) => gammaSummary(candidate, chinese))
            .join('\n\n')
    );
  } else if (candidates.length > 0) {
    const candidate = candidates[0];
    const metrics = candidate.metrics;
    sections.push(
      chinese
        ? `${candidate.symbol} 当前状态：${candidate.status}。最新完整 5 分钟线为第 ${num(
            metrics.bar_number,
            0
          )} 根（${String(
            metrics.clock_et ?? '时间不可用'
          )}），收盘 ${num(metrics.close)}，因果 session VWAP ${num(
            metrics.session_vwap
          )}，距离 ${pct(metrics.distance_from_vwap, 2)}。`
        : `${candidate.symbol}: ${candidate.status}. Latest completed five-minute bar ${num(
            metrics.bar_number,
            0
          )} (${String(
            metrics.clock_et ?? 'time unavailable'
          )}), close ${num(metrics.close)}, causal session VWAP ${num(
            metrics.session_vwap
          )}, distance ${pct(metrics.distance_from_vwap, 2)}.`
    );
  }

  if (candidates.length > 0) {
    const provenanceCandidates =
      envelope.query.setup_type === 'model_forecast'
        ? candidates
        : candidates.slice(0, envelope.query.limit);
    sections.push(
      provenanceCandidates
        .map((candidate) => candidateProvenance(candidate, chinese))
        .join('\n')
    );
  }
  const relevantCaveats = envelope.caveats.filter((caveat) => {
    if (
      envelope.query.setup_type !== 'gamma_squeeze' &&
      /gamma|dealer|open interest|\bOI\b|OPRA|option chain/i.test(caveat)
    ) {
      return false;
    }
    if (!historicalRequested && /historical condition|historical replay|backtest/i.test(caveat)) {
      return false;
    }
    return true;
  });
  if (relevantCaveats.length > 0) {
    const caveats = relevantCaveats
      .slice(0, 10)
      .map((caveat) => `- ${caveat}`);
    sections.push(
      `${chinese ? '重要限制' : 'Material caveats'}:\n${caveats.join('\n')}`
    );
  }

  if (historicalRequested && envelope.historical.length > 0) {
    sections.push(
      envelope.historical
        .slice(0, 3)
        .map((row) => historicalSummary(row, chinese))
        .join('\n\n')
    );
  }
  if (compilerNotes.length > 0) {
    sections.push(compilerNotes.join('\n'));
  }

  const cutoff = formatEt(envelope.observation_cutoff, chinese);
  const generated = formatEt(envelope.generated_at, chinese);
  sections.push(
    chinese
      ? `查询截止 ${cutoff}；响应生成 ${generated}；审计编号 ${envelope.request_id}。候选标的自身的观测截止与可用时间见上方逐候选来源记录。`
      : `Query cutoff ${cutoff}; response generated ${generated}; audit id ${envelope.request_id}. Each candidate's own observation cutoff and availability time are reported in its provenance above.`
  );

  return sections.filter(Boolean).join('\n\n');
}
