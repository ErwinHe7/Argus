import Redis from 'ioredis';
import {
  buildGlobalSignalsReport,
  type AlertLevel,
  type GlobalSignalEvent,
  type GlobalSignalsReport,
} from '@/lib/quant/global-signals';

type DispatchTargetResult = {
  target: 'telegram' | 'webhook';
  ok: boolean;
  status?: number;
  error?: string;
};

export type GlobalSignalAlertDispatchResult = {
  ok: boolean;
  generatedAt: string;
  dispatched: boolean;
  dryRun: boolean;
  reason: string;
  level: AlertLevel;
  score: number;
  targets: DispatchTargetResult[];
  cooldownKey?: string;
  cooldownActive?: boolean;
  redisCooldownConfigured: boolean;
};

declare global {
  // eslint-disable-next-line no-var
  var __axio7GlobalSignalRedis: Redis | undefined;
}

const LEVEL_RANK: Record<AlertLevel, number> = {
  GREEN: 0,
  LIGHT_YELLOW: 1,
  YELLOW: 2,
  ORANGE: 3,
  RED: 4,
};

export async function dispatchGlobalSignalAlerts({ force = false } = {}): Promise<GlobalSignalAlertDispatchResult> {
  const report = await buildGlobalSignalsReport({ includeReplay: false });
  const config = report.alertDelivery;
  const reason = getDispatchReason(report);
  const base = {
    generatedAt: report.generatedAt,
    level: report.scores.level,
    score: report.scores.marketRiskScore,
    redisCooldownConfigured: config.redisCooldownConfigured,
  };

  if (!config.enabled && !force) {
    return {
      ...base,
      ok: true,
      dispatched: false,
      dryRun: true,
      reason: 'GLOBAL_SIGNAL_ALERTS_ENABLED is not true.',
      targets: [],
    };
  }

  if (!config.telegramConfigured && !config.webhookConfigured) {
    return {
      ...base,
      ok: false,
      dispatched: false,
      dryRun: true,
      reason: 'No alert target configured. Set Telegram or GLOBAL_SIGNAL_ALERT_WEBHOOK_URL.',
      targets: [],
    };
  }

  if (!force && reason) {
    return {
      ...base,
      ok: true,
      dispatched: false,
      dryRun: true,
      reason,
      targets: [],
    };
  }

  const cooldownKey = buildCooldownKey(report);
  const cooldownActive = force ? false : await isCooldownActive(cooldownKey, config.cooldownMinutes);
  if (cooldownActive) {
    return {
      ...base,
      ok: true,
      dispatched: false,
      dryRun: true,
      reason: 'Alert fingerprint is still inside cooldown window.',
      targets: [],
      cooldownKey,
      cooldownActive: true,
    };
  }

  const message = formatAlertMessage(report, force);
  const targets: DispatchTargetResult[] = [];
  if (config.telegramConfigured) targets.push(await sendTelegram(message));
  if (config.webhookConfigured) targets.push(await sendWebhook(report, message, force));

  const ok = targets.every((target) => target.ok);
  return {
    ...base,
    ok,
    dispatched: ok,
    dryRun: false,
    reason: ok ? 'Alert dispatched.' : 'One or more alert targets failed.',
    targets,
    cooldownKey,
    cooldownActive: false,
  };
}

function getDispatchReason(report: GlobalSignalsReport): string | null {
  const config = report.alertDelivery;
  const levelOk = LEVEL_RANK[report.scores.level] >= LEVEL_RANK[config.minLevel];
  const scoreOk = report.scores.marketRiskScore >= config.minScore;
  const severeLiveEvent = report.activeEvents.some(
    (event) => event.canEscalateRed && event.severity >= 85 && event.confidence >= 70 && event.confirmationStatus !== 'replay'
  );
  const severeLiveAnomaly = report.priceAnomalyReport.signals.some(
    (signal) => signal.mode === 'live' && (signal.level === 'RED' || signal.level === 'ORANGE') && signal.confidence >= 70
  );

  if (!levelOk) return `Level ${report.scores.level} is below ${config.minLevel}.`;
  if (!scoreOk && !severeLiveEvent && !severeLiveAnomaly) {
    return `Score ${report.scores.marketRiskScore} is below ${config.minScore} and no severe live event/anomaly is present.`;
  }
  return null;
}

function formatAlertMessage(report: GlobalSignalsReport, force: boolean): string {
  const topEvents = report.activeEvents
    .filter((event) => event.confirmationStatus !== 'replay')
    .sort((a, b) => b.severity * b.confidence - a.severity * a.confidence)
    .slice(0, 4);
  const topAnomalies = report.priceAnomalyReport.signals
    .filter((signal) => signal.mode === 'live')
    .sort((a, b) => b.score * b.confidence - a.score * a.confidence)
    .slice(0, 3);
  const site = process.env.NEXT_PUBLIC_SITE_URL || 'https://axio7.com';
  const lines = [
    `${force ? '[FORCED] ' : ''}AXIO7 ${report.scores.level} Global Signal Alert`,
    `Score: ${report.scores.marketRiskScore}/100`,
    `Regime: ${report.scores.regime}`,
    `Action: ${report.scores.action}`,
    '',
    'Price/flow anomalies:',
    ...(topAnomalies.length ? topAnomalies.map(formatAnomalyLine) : ['- No live price-led anomaly.']),
    '',
    'Live drivers:',
    ...(topEvents.length ? topEvents.map(formatEventLine) : ['- No live event detail available; score threshold triggered.']),
    '',
    `Open: ${site}/quant/global-signals`,
  ];
  return lines.join('\n');
}

function formatAnomalyLine(signal: GlobalSignalsReport['priceAnomalyReport']['signals'][number]): string {
  return `- ${signal.ticker} ${signal.level} ${signal.direction} | score ${signal.score}/${signal.confidence} | ${signal.reason} | cause: ${signal.likelyCause}`;
}

function formatEventLine(event: GlobalSignalEvent): string {
  const impact = event.impactAssessment ? `${event.impactAssessment.bias}/${event.impactAssessment.horizon}` : event.direction;
  const analog = event.impactAssessment?.historicalAnalogs?.[0]?.label;
  return `- ${event.sourceTier} ${event.title} | ${impact} | ${event.severity}/${event.confidence} | ${event.affectedAssets.slice(0, 6).join(', ')}${
    analog ? ` | analog: ${analog}` : ''
  }`;
}

async function sendTelegram(text: string): Promise<DispatchTargetResult> {
  const token = process.env.TELEGRAM_BOT_TOKEN;
  const chatId = process.env.TELEGRAM_CHAT_ID;
  if (!token || !chatId) return { target: 'telegram', ok: false, error: 'Telegram env vars missing.' };

  try {
    const res = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: chatId,
        text,
        disable_web_page_preview: true,
      }),
    });
    return { target: 'telegram', ok: res.ok, status: res.status, ...(res.ok ? {} : { error: await res.text() }) };
  } catch (err) {
    return { target: 'telegram', ok: false, error: err instanceof Error ? err.message : String(err) };
  }
}

async function sendWebhook(report: GlobalSignalsReport, message: string, force: boolean): Promise<DispatchTargetResult> {
  const url = process.env.GLOBAL_SIGNAL_ALERT_WEBHOOK_URL;
  if (!url) return { target: 'webhook', ok: false, error: 'GLOBAL_SIGNAL_ALERT_WEBHOOK_URL missing.' };

  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        type: 'global_signal_alert',
        force,
        message,
        generatedAt: report.generatedAt,
        level: report.scores.level,
        score: report.scores.marketRiskScore,
        regime: report.scores.regime,
        action: report.scores.action,
        priceAnomalies: report.priceAnomalyReport.signals.slice(0, 5),
        activeEvents: report.activeEvents.slice(0, 8),
      }),
    });
    return { target: 'webhook', ok: res.ok, status: res.status, ...(res.ok ? {} : { error: await res.text() }) };
  } catch (err) {
    return { target: 'webhook', ok: false, error: err instanceof Error ? err.message : String(err) };
  }
}

async function isCooldownActive(key: string, cooldownMinutes: number): Promise<boolean> {
  const redis = getRedis();
  if (!redis) return false;
  const result = await redis.set(key, new Date().toISOString(), 'EX', cooldownMinutes * 60, 'NX');
  return result !== 'OK';
}

function getRedis(): Redis | null {
  if (!process.env.REDIS_URL) return null;
  if (!globalThis.__axio7GlobalSignalRedis) {
    globalThis.__axio7GlobalSignalRedis = new Redis(process.env.REDIS_URL, {
      maxRetriesPerRequest: 1,
      lazyConnect: false,
    });
  }
  return globalThis.__axio7GlobalSignalRedis;
}

function buildCooldownKey(report: GlobalSignalsReport): string {
  const topIds = report.activeEvents
    .filter((event) => event.confirmationStatus !== 'replay')
    .sort((a, b) => b.severity * b.confidence - a.severity * a.confidence)
    .slice(0, 3)
    .map((event) => event.id)
    .join('|');
  const scoreBucket = Math.floor(report.scores.marketRiskScore / 5) * 5;
  return `global-signal-alert:${report.scores.level}:${scoreBucket}:${hash(`${report.scores.regime}:${topIds}`)}`;
}

function hash(input: string): string {
  let value = 0;
  for (let i = 0; i < input.length; i += 1) {
    value = (value * 31 + input.charCodeAt(i)) >>> 0;
  }
  return value.toString(36);
}
