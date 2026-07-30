'use client';

import {
  ArrowRight,
  ArrowUp,
  BellRing,
  BrainCircuit,
  Check,
  CircleUserRound,
  Copy,
  CreditCard,
  History,
  LogOut,
  Menu,
  MessageSquareText,
  PanelLeftClose,
  PanelLeftOpen,
  Pause,
  Play,
  Plus,
  RefreshCw,
  Settings2,
  ShieldCheck,
  X,
} from 'lucide-react';
import {
  FormEvent,
  KeyboardEvent,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import Image from 'next/image';
import type {
  ForecastChatResult,
  ForecastSourceState,
  MarketMonitorAction,
  MarketMonitorView,
  QuantDailyRegimeReport,
  QuantEvidenceEnvelope,
  QuantHistoricalStats,
  QuantPipelineReadiness,
  QuantResearchCandidate,
  QuantSessionSummary,
} from '@/lib/forecast-chat-types';
import styles from './AxioChat.module.css';

type ChatMessage = {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  question?: string;
  forecast?: ForecastChatResult;
  monitor?: MarketMonitorAction;
  ownerPreview?: MoomooOwnerPreview;
  conversation?: ConversationReceipt;
  failed?: boolean;
};

type ConversationReceipt = {
  mode: 'model_knowledge' | 'quant_research' | 'daily_regime_analog';
  knowledge_version: string;
  llm_role: 'grounded_explainer' | 'deterministic_fallback';
  llm_model?: string;
  locale: 'en-US' | 'zh-CN';
};

type AskResponse = {
  answer?: string;
  error?: string;
  forecast?: ForecastChatResult;
  monitor?: MarketMonitorAction;
  conversation?: ConversationReceipt;
  clarification?: {
    setup_type?: string;
    symbols?: string[];
    missing_fields?: string[];
    allowed_values?: Record<string, unknown>;
  };
};

type AuthUser = {
  authenticated: boolean;
  name: string;
  email: string | null;
  privateMarketDataAccess: boolean;
  researchAccess: boolean;
};

type RuntimeState =
  | 'checking'
  | 'models_loaded'
  | 'feed_streaming'
  | 'unavailable';
type RuntimeReceipt = {
  connected?: boolean;
  code?: string;
  modelStatus?: 'LOADED' | 'PARTIAL' | 'UNAVAILABLE';
  requestedModelCount?: number;
  loadedModelCount?: number;
  failedModelCount?: number;
  liveForecastReady?: false;
  readiness?: QuantPipelineReadiness;
  marketData?: {
    ok?: boolean;
    state?: string;
    rightsReason?: string;
  };
};
type MoomooOwnerForecastRow = {
  horizon_minutes?: number;
  reference_price?: number;
  expected_return?: number;
  observation_cutoff?: string;
  model_hash?: string;
  research_status?: string;
};
type MoomooOwnerPreview = {
  status?: string;
  symbol?: string;
  preview_mode?: 'LIVE_FORWARD_SHADOW' | 'DETERMINISTIC_REPLAY';
  freshness_status?: string;
  observation_cutoff?: string;
  owner_only?: boolean;
  customer_publication_authorized?: false;
  probability_publication_status?: string;
  prediction_layer?: MoomooOwnerForecastRow[];
  truth?: string;
};
type CopyState = 'idle' | 'copied' | 'error';

const STARTERS = [
  {
    label: 'Momentum monitor',
    prompt:
      'Monitor upward momentum in QQQ, NVDA, AAPL, MU, SOXX, NBIS, BE and IGV every 5 minutes.',
  },
  {
    label: 'Options structure',
    prompt:
      'Monitor bullish gamma-squeeze structures in NVDA, AAPL, MU, NBIS and BE over the next 15 minutes.',
  },
  {
    label: 'Opening exhaustion',
    prompt:
      'Which 5-minute bar most often confirms a bearish SPX opening buy exhaustion? Backtest it.',
  },
  {
    label: 'VWAP state',
    prompt: 'Is SPX or QQQ triggering a bearish VWAP reversal on the latest completed 5-minute bar?',
  },
] as const;

function newId() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
}

function requestedOwnerPreviewSymbol(question: string) {
  const match = question
    .toUpperCase()
    .match(/\b(SPX|SPY|QQQ|NVDA|AAPL|MU|SOXX|NBIS|IGV)\b/);
  if (!match) return null;
  return match[1] === 'SPX' ? 'SPY' : match[1];
}

function humanizeDataBlocker(
  blocker: string,
  locale: ConversationReceipt['locale'] = 'en-US'
) {
  const symbol = blocker.match(/^([A-Z][A-Z0-9.]{0,9}):/)?.[1];
  const subject = symbol ? `${symbol}: ` : '';
  const chinese = locale === 'zh-CN';
  if (/AWAITING_FIRST_FINALIZED_LIVE_FORECAST/i.test(blocker)) {
    return chinese
      ? `${subject}实时管线尚未发布第一份完整预测。`
      : `${subject}the live pipeline has not published its first finalized forecast yet.`;
  }
  if (
    /PUBLIC_MARKET_DATA.*LICENSE|LICENSE.*NOT_CONFIGURED|REDISTRIBUTION/i.test(
      blocker
    )
  ) {
    return chinese
      ? `${subject}面向网站用户的实时数据授权凭据尚未生效。`
      : `${subject}the customer-facing realtime data authorization receipt is not active.`;
  }
  if (/MODEL.*(?:NOT_PROMOTED|UNPROMOTED)|PROMOTION|CALIBRATION/i.test(blocker)) {
    return chinese
      ? `${subject}模型或校准工件尚未获准发布。`
      : `${subject}the model or calibration artifact is not promoted for publication.`;
  }
  if (/STALE|FRESH/i.test(blocker)) {
    return chinese
      ? `${subject}最新完整行情没有通过新鲜度检查。`
      : `${subject}the latest completed market observation did not pass the freshness gate.`;
  }
  if (/CONTEXT|COVERAGE|INCOMPLETE|MISSING/i.test(blocker)) {
    return chinese
      ? `${subject}共同截止时点的一项或多项必要输入不完整。`
      : `${subject}one or more required point-in-time inputs are incomplete at the common cutoff.`;
  }
  return chinese
    ? `${subject}必要的实时数据、推理或发布闸门没有通过。`
    : `${subject}a required live-data, inference, or publication gate did not pass.`;
}

function explainDataBlockers(
  blockers: string[],
  locale: ConversationReceipt['locale'] = 'en-US'
) {
  return blockers.length > 0
    ? blockers
        .slice(0, 3)
        .map((blocker) => humanizeDataBlocker(blocker, locale))
        .join(' ')
    : locale === 'zh-CN'
      ? '本次请求没有生成实时预测，后端也没有返回可公开的诊断信息。'
      : 'The request did not produce a live forecast, and the backend did not report a public diagnostic.';
}

export function AxioChat({ initialUser }: { initialUser: AuthUser }) {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [monitors, setMonitors] = useState<MarketMonitorView[]>([]);
  const [monitorAccess, setMonitorAccess] = useState<
    | 'loading'
    | 'ready'
    | 'authentication_required'
    | 'payment_required'
    | 'unavailable'
  >(
    initialUser.researchAccess
      ? 'loading'
      : initialUser.authenticated
        ? 'payment_required'
        : 'authentication_required'
  );
  const [runtimeState, setRuntimeState] = useState<RuntimeState>('checking');
  const [runtimeReceipt, setRuntimeReceipt] =
    useState<RuntimeReceipt | null>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const conversationRef = useRef<HTMLDivElement>(null);
  const requestVersionRef = useRef(0);

  const currentTitle = useMemo(
    () => messages.find((message) => message.role === 'user')?.content ?? '',
    [messages]
  );

  useEffect(() => {
    const textarea = textareaRef.current;
    if (!textarea) return;
    textarea.style.height = '0px';
    textarea.style.height = `${Math.min(textarea.scrollHeight, 190)}px`;
  }, [input]);

  useEffect(() => {
    const conversation = conversationRef.current;
    if (!conversation || messages.length === 0) return;
    requestAnimationFrame(() => {
      if (loading) {
        conversation.scrollTo({
          top: conversation.scrollHeight,
          behavior: 'smooth',
        });
        return;
      }
      const renderedMessages =
        conversation.querySelectorAll<HTMLElement>('[data-chat-message]');
      const latest = renderedMessages.item(renderedMessages.length - 1);
      latest?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  }, [loading, messages]);

  useEffect(() => {
    if (
      monitorAccess === 'authentication_required' ||
      monitorAccess === 'payment_required'
    ) {
      return;
    }
    void loadMonitors();
    const refresh = () => {
      if (document.visibilityState === 'visible') void loadMonitors();
    };
    const interval = window.setInterval(refresh, 30_000);
    document.addEventListener('visibilitychange', refresh);
    return () => {
      window.clearInterval(interval);
      document.removeEventListener('visibilitychange', refresh);
    };
  }, [monitorAccess]);

  useEffect(() => {
    let cancelled = false;

    async function probeRuntime() {
      try {
        const response = await fetch('/api/quant/research/status', {
          cache: 'no-store',
        });
        const data = (await response.json().catch(() => ({}))) as RuntimeReceipt;
        if (!cancelled) {
          setRuntimeReceipt(data);
          setRuntimeState(
            response.ok && data.connected
              ? data.readiness?.feed?.state === 'ready'
                ? 'feed_streaming'
                : 'models_loaded'
              : 'unavailable'
          );
        }
      } catch {
        if (!cancelled) {
          setRuntimeReceipt(null);
          setRuntimeState('unavailable');
        }
      }
    }

    void probeRuntime();
    const interval = window.setInterval(probeRuntime, 30_000);
    return () => {
      cancelled = true;
      window.clearInterval(interval);
    };
  }, []);

  async function loadMonitors() {
    try {
      const response = await fetch('/api/monitors', { cache: 'no-store' });
      const data = (await response.json().catch(() => ({}))) as {
        monitors?: MarketMonitorView[];
      };
      if (response.status === 401) {
        setMonitorAccess('authentication_required');
        return;
      }
      if (response.status === 402) {
        setMonitorAccess('payment_required');
        return;
      }
      if (!response.ok) {
        setMonitorAccess('unavailable');
        return;
      }
      setMonitors(data.monitors ?? []);
      setMonitorAccess('ready');
    } catch {
      setMonitorAccess('unavailable');
    }
  }

  function upsertMonitor(monitor: MarketMonitorView) {
    setMonitors((current) => [
      monitor,
      ...current.filter((row) => row.id !== monitor.id),
    ]);
    setMonitorAccess('ready');
  }

  async function toggleMonitor(monitor: MarketMonitorView) {
    const status = monitor.status === 'active' ? 'paused' : 'active';
    try {
      const response = await fetch(`/api/monitors/${monitor.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status }),
      });
      const data = (await response.json().catch(() => ({}))) as {
        monitor?: MarketMonitorView;
      };
      if (response.ok && data.monitor) upsertMonitor(data.monitor);
    } catch {
      // The current server state remains authoritative; leave the row unchanged.
    }
  }

  function startNewChat() {
    requestVersionRef.current += 1;
    setMessages([]);
    setInput('');
    setLoading(false);
    setSidebarOpen(false);
    requestAnimationFrame(() => textareaRef.current?.focus());
  }

  function preparePrompt(prompt: string) {
    setInput(prompt);
    requestAnimationFrame(() => textareaRef.current?.focus());
  }

  async function send(questionOverride?: string) {
    if (!initialUser.researchAccess) return;
    const question = (questionOverride ?? input).trim();
    if (!question || loading) return;

    const lastUserQuestion = [...messages]
      .reverse()
      .find((message) => message.role === 'user')?.content;
    const query = lastUserQuestion
      ? `Previous question: ${lastUserQuestion}\n\nFollow-up question: ${question}`.slice(
          -2000
        )
      : question;
    const version = requestVersionRef.current;

    setMessages((current) => [
      ...current,
      { id: newId(), role: 'user', content: question },
    ]);
    setInput('');
    setLoading(true);

    try {
      const response = await fetch('/api/ask', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query }),
      });
      const data = (await response.json().catch(() => ({}))) as AskResponse;
      if (!response.ok && !data.answer) {
        throw new Error(data.error || 'AXIO7 could not complete that research request.');
      }
      let ownerPreviewForMessage: MoomooOwnerPreview | undefined;
      const ownerSymbol = initialUser.privateMarketDataAccess
        ? requestedOwnerPreviewSymbol(question)
        : null;
      if (ownerSymbol) {
        try {
          const previewResponse = await fetch(
            `/api/quant/intraday/predictor/owner-preview?symbol=${encodeURIComponent(ownerSymbol)}`,
            { cache: 'no-store', signal: AbortSignal.timeout(5_000) }
          );
          const preview = (await previewResponse.json().catch(() => ({}))) as MoomooOwnerPreview;
          if (
            previewResponse.ok &&
            preview.owner_only === true &&
            Array.isArray(preview.prediction_layer) &&
            preview.prediction_layer.length > 0
          ) {
            ownerPreviewForMessage = preview;
          }
        } catch {
          // The public research response remains valid even if the private preview is absent.
        }
      }
      if (requestVersionRef.current !== version) return;
      if (data.monitor?.monitor) upsertMonitor(data.monitor.monitor);

      setMessages((current) => [
        ...current,
        {
          id: newId(),
          role: 'assistant',
          content:
            data.answer?.trim() ||
            'The model completed the research run but returned no written conclusion.',
          question,
          forecast: data.forecast,
          monitor: data.monitor,
          ownerPreview: ownerPreviewForMessage,
          conversation: data.conversation,
        },
      ]);
    } catch (error) {
      if (requestVersionRef.current !== version) return;
      setMessages((current) => [
        ...current,
        {
          id: newId(),
          role: 'assistant',
          content:
            error instanceof Error
              ? error.message
              : 'AXIO7 could not complete that research request. Please try again.',
          question,
          failed: true,
        },
      ]);
    } finally {
      if (requestVersionRef.current === version) setLoading(false);
    }
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    void send();
  }

  function handleKeyDown(event: KeyboardEvent<HTMLTextAreaElement>) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      void send();
    }
  }

  const hasConversation = messages.length > 0;

  return (
    <main
      className={`${styles.shell} ${
        sidebarCollapsed ? styles.sidebarIsCollapsed : ''
      }`}
    >
      <aside
        className={`${styles.sidebar} ${sidebarOpen ? styles.sidebarOpen : ''}`}
        aria-label="Chat navigation"
      >
        <div className={styles.sidebarTop}>
          <button
            type="button"
            className={styles.brand}
            onClick={startNewChat}
            aria-label="AXIO7 home"
          >
            <span className={styles.brandWord}>AXIO7</span>
            <span className={styles.brandDescriptor}>Research</span>
          </button>
          <button
            type="button"
            className={styles.collapseButton}
            onClick={() => setSidebarCollapsed((current) => !current)}
            aria-label={sidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          >
            {sidebarCollapsed ? (
              <PanelLeftOpen size={18} />
            ) : (
              <PanelLeftClose size={18} />
            )}
          </button>
          <button
            type="button"
            className={styles.mobileClose}
            onClick={() => setSidebarOpen(false)}
            aria-label="Close navigation"
          >
            <X size={19} />
          </button>
        </div>

        <button type="button" className={styles.newChat} onClick={startNewChat}>
          <Plus size={17} />
          <span>New analysis</span>
        </button>

        <div className={styles.sidebarSection}>
          <p className={styles.sidebarLabel}>
            <History size={14} />
            <span>Recent</span>
          </p>
          {currentTitle ? (
            <button
              type="button"
              className={styles.historyItem}
              onClick={() => setSidebarOpen(false)}
              title={currentTitle}
            >
              <MessageSquareText size={15} />
              <span>{currentTitle}</span>
            </button>
          ) : (
            <p className={styles.emptyHistory}>Your research requests will appear here.</p>
          )}

          <div className={styles.monitorSection}>
            <p className={styles.sidebarLabel}>
              <BellRing size={14} />
              <span>Monitors</span>
            </p>
            {monitors.length > 0 ? (
              <div className={styles.monitorList}>
                {monitors.map((monitor) => (
                  <div
                    className={styles.monitorItem}
                    data-status={monitor.status}
                    data-triggered={monitor.latest_event ? 'true' : 'false'}
                    key={monitor.id}
                    title={monitor.title}
                  >
                    <i />
                    <span>
                      <strong>{monitor.title}</strong>
                      <small>
                        {monitor.latest_event?.title ||
                          monitor.last_result_status ||
                          'Awaiting first scan'}
                      </small>
                    </span>
                    <button
                      type="button"
                      onClick={() => void toggleMonitor(monitor)}
                      aria-label={
                        monitor.status === 'active'
                          ? `Pause ${monitor.title}`
                          : `Resume ${monitor.title}`
                      }
                    >
                      {monitor.status === 'active' ? (
                        <Pause size={12} />
                      ) : (
                        <Play size={12} />
                      )}
                    </button>
                  </div>
                ))}
              </div>
            ) : monitorAccess === 'authentication_required' ? (
              <a
                className={styles.monitorEmpty}
                href="/auth/signin?next=%2F"
              >
                Sign in to save monitors
              </a>
            ) : monitorAccess === 'payment_required' ? (
              <a className={styles.monitorEmpty} href="/pricing">
                Upgrade to create monitors
              </a>
            ) : (
              <p className={styles.monitorEmpty}>
                {monitorAccess === 'unavailable'
                  ? 'Monitor storage is not ready.'
                  : 'Ask AXIO7 to monitor a setup.'}
              </p>
            )}
          </div>
        </div>

        <div className={styles.sidebarBottom}>
          <nav className={styles.membershipLinks} aria-label="Membership navigation">
            <a href="/pricing">
              <CreditCard size={16} aria-hidden="true" />
              <span>Plans</span>
            </a>
            {initialUser.authenticated ? (
              <a href="/billing">
                <CircleUserRound size={16} aria-hidden="true" />
                <span>Membership</span>
              </a>
            ) : null}
          </nav>
          <div className={styles.modelBadge}>
            <BrainCircuit size={17} />
            <div>
              <strong>AXIO7 Research</strong>
              <span>Native Rust inference</span>
            </div>
          </div>
          <p className={styles.sidebarDisclaimer}>
            Research use only
          </p>
        </div>
      </aside>

      {sidebarOpen ? (
        <button
          type="button"
          className={styles.backdrop}
          onClick={() => setSidebarOpen(false)}
          aria-label="Close navigation"
        />
      ) : null}

      <section className={styles.workspace}>
        <header className={styles.topbar}>
          <button
            type="button"
            className={styles.menuButton}
            onClick={() => setSidebarOpen(true)}
            aria-label="Open navigation"
          >
            <Menu size={20} />
          </button>
          <div className={styles.topbarModel} aria-label="AXIO7 website">
            <span className={styles.topbarLogo}>
              <Image
                src="/axio7-logo.png"
                alt="AXIO7 logo"
                width={52}
                height={52}
                priority
              />
            </span>
            <span>AXIO7</span>
          </div>
          <div className={styles.topbarActions}>
            <div
              className={styles.liveStatus}
              data-state={runtimeState}
              role="status"
              aria-live="polite"
               title={
                 runtimeState === 'feed_streaming'
                   ? runtimeReceipt?.marketData?.rightsReason ===
                     'OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT'
                     ? `${runtimeReceipt?.loadedModelCount ?? 'All'} of ${
                         runtimeReceipt?.requestedModelCount ?? 'all'
                       } model artifacts are loaded. Rights basis: OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT. This is an account-owner attestation plus a fresh technical-entitlement receipt, not vendor-issued confirmation. Target context, inference, and forecast publication are checked when a request runs.`
                     : `${runtimeReceipt?.loadedModelCount ?? 'All'} of ${
                         runtimeReceipt?.requestedModelCount ?? 'all'
                       } model artifacts are loaded. The authoritative Rust receipt verifies customer-display rights, provider entitlement, stream freshness, and required-symbol feed freshness. Target context, inference, and forecast publication are checked when a request runs.`
                   : runtimeState === 'models_loaded'
                     ? `${runtimeReceipt?.loadedModelCount ?? 'All'} of ${
                         runtimeReceipt?.requestedModelCount ?? 'all'
                       } model artifacts are loaded. The live feed is not ready, and no live forecast readiness is implied.`
                   : runtimeState === 'checking'
                     ? 'Checking the AXIO7 Rust research service.'
                     : runtimeReceipt?.code
                       ? `The Rust model runtime is unavailable (${runtimeReceipt.code}). Research requests fail closed.`
                       : 'The AXIO7 Rust research service is unavailable. Research requests fail closed.'
               }
             >
               <i />
               {runtimeState === 'feed_streaming'
                 ? 'Models loaded · live feed ready'
                 : runtimeState === 'models_loaded'
                   ? 'Models loaded · live feed waiting'
                 : runtimeState === 'checking'
                   ? 'Checking model'
                 : 'Model offline'}
            </div>
            <a
              className={styles.plansLink}
              href="/pricing"
              aria-label="View membership plans"
            >
              <CreditCard size={14} aria-hidden="true" />
              <span>Plans</span>
            </a>
            {initialUser.authenticated ? (
              <div className={styles.account}>
                <a
                  href="/billing"
                  className={styles.accountIdentity}
                  title={initialUser.email ?? initialUser.name}
                  aria-label="Manage membership"
                >
                  <CircleUserRound size={15} />
                  <span>{initialUser.name}</span>
                </a>
                <form
                  action="/auth/signout?next=%2F"
                  method="post"
                  className={styles.signOutForm}
                >
                  <button type="submit" aria-label="Sign out" title="Sign out">
                    <LogOut size={14} />
                  </button>
                </form>
              </div>
            ) : (
              <a
                className={styles.signInLink}
                href="/auth/signin?next=%2F"
                aria-label="Sign in to AXIO7"
              >
                <CircleUserRound size={15} aria-hidden="true" />
                <span>Sign in</span>
              </a>
            )}
          </div>
        </header>

        {!hasConversation ? (
          <div className={styles.welcome}>
            <div className={styles.welcomeInner}>
              <h1>What would you like to predict or research?</h1>
              <p className={styles.welcomeCopy}>
                Scan, backtest, or monitor an impersonal condition. AXIO7 shows
                the data cutoff, evidence, model limits, and reproducibility trail.
              </p>
              {initialUser.researchAccess ? (
                <Composer
                  value={input}
                  setValue={setInput}
                  loading={loading}
                  textareaRef={textareaRef}
                  onSubmit={handleSubmit}
                  onKeyDown={handleKeyDown}
                  autoFocus
                />
              ) : (
                <div className={styles.readOnlyGate}>
                  <ShieldCheck size={22} aria-hidden="true" />
                  <div>
                    <strong>Free access is read-only</strong>
                    <p>
                      View public research and methodology. Choose Pro or Annual
                      to run scans, backtests, research, and monitors.
                    </p>
                  </div>
                  <a href="/pricing">
                    View plans <ArrowRight size={15} aria-hidden="true" />
                  </a>
                </div>
              )}

              <div className={styles.starterHeader}>
                <span>Example research questions</span>
                <span>Press Enter to submit</span>
              </div>
              <div className={styles.starterGrid} aria-label="Example questions">
                {STARTERS.map(({ label, prompt }, index) => (
                  <button
                    type="button"
                    key={label}
                    onClick={() => void send(prompt)}
                    disabled={!initialUser.researchAccess}
                  >
                    <span className={styles.starterIndex}>
                      {String(index + 1).padStart(2, '0')}
                    </span>
                    <span className={styles.starterText}>
                      <small>{label}</small>
                      <strong>{prompt}</strong>
                    </span>
                    <ArrowRight size={15} />
                  </button>
                ))}
              </div>
            </div>
          </div>
        ) : (
          <>
            <div className={styles.conversation} ref={conversationRef}>
              <div className={styles.thread}>
                {messages.map((message) =>
                  message.role === 'user' ? (
                    <div
                      className={styles.userRow}
                      data-chat-message={message.id}
                      key={message.id}
                    >
                      <div className={styles.userMessage}>{message.content}</div>
                    </div>
                  ) : (
                    <article
                      className={styles.assistantMessage}
                      data-chat-message={message.id}
                      key={message.id}
                    >
                      <div
                        className={`${styles.assistantAvatar} ${
                          message.failed ? styles.failedAvatar : ''
                        }`}
                      >
                        A7
                      </div>
                      <div className={styles.assistantBody}>
                        <p className={styles.assistantName}>AXIO7</p>
                        <AssistantAnswer message={message} />
                        {message.forecast ? (
                          <PredictionDetails
                            forecast={message.forecast}
                            locale={message.conversation?.locale ?? 'en-US'}
                            onRetry={() => {
                              if (message.question) void send(message.question);
                            }}
                            onPreparePrompt={preparePrompt}
                          />
                        ) : null}
                        {message.ownerPreview ? (
                          <OwnerModelPreview preview={message.ownerPreview} />
                        ) : null}
                        {message.monitor ? (
                          <MonitorReceipt action={message.monitor} />
                        ) : null}
                        {message.conversation ? (
                          <ConversationProvenance
                            receipt={message.conversation}
                          />
                        ) : null}
                      </div>
                    </article>
                  )
                )}

                {loading ? (
                  <article className={styles.assistantMessage}>
                    <div className={styles.assistantAvatar}>A7</div>
                    <div className={styles.assistantBody}>
                      <p className={styles.assistantName}>AXIO7</p>
                      <div className={styles.thinking}>
                        <span />
                        <span />
                        <span />
                        <em>Running the evidence model</em>
                      </div>
                    </div>
                  </article>
                ) : null}
              </div>
            </div>

            <div className={styles.composerDock}>
              <Composer
                value={input}
                setValue={setInput}
                loading={loading}
                textareaRef={textareaRef}
                onSubmit={handleSubmit}
                onKeyDown={handleKeyDown}
              />
            </div>
          </>
        )}

        <p className={styles.legal}>
          Impersonal research only — not investment advice or order execution.
          Verify sources and material caveats.
        </p>
      </section>
    </main>
  );
}

function AssistantAnswer({ message }: { message: ChatMessage }) {
  const research = message.forecast?.research;
  const gatedResearch =
    research &&
    research.candidates.length === 0 &&
    research.data_blockers.length > 0 &&
    !message.forecast?.sessionSummary &&
    !(
      research.query.filters.include_historical &&
      research.historical.length > 0
    )
      ? research
      : null;

  if (gatedResearch) {
    return (
      <FailClosedNotice
        envelope={gatedResearch}
        locale={message.conversation?.locale ?? 'en-US'}
      />
    );
  }

  return (
    <div
      className={`${styles.answer} ${
        message.failed ? styles.failedAnswer : ''
      }`}
    >
      {message.content}
    </div>
  );
}

function FailClosedNotice({
  envelope,
  locale,
}: {
  envelope: QuantEvidenceEnvelope;
  locale: ConversationReceipt['locale'];
}) {
  const [copyState, setCopyState] = useState<CopyState>('idle');
  const blockers = envelope.data_blockers;
  const chinese = locale === 'zh-CN';

  async function copyTechnicalReasons() {
    try {
      if (!navigator.clipboard) {
        throw new Error('Clipboard unavailable');
      }
      await navigator.clipboard.writeText(blockers.join('\n'));
      setCopyState('copied');
    } catch {
      setCopyState('error');
    }
  }

  return (
    <section
      className={styles.gatedNotice}
      role="status"
      aria-label={chinese ? '研究结果已暂缓' : 'Research result withheld'}
    >
      <p className={styles.gatedEyebrow}>
        {chinese ? '结果已暂缓' : 'Result withheld'}
      </p>
      <h2>
        {chinese
          ? '本次请求没有生成实时预测。'
          : 'No live forecast was generated for this request.'}
      </h2>
      <p>{explainDataBlockers(blockers, locale)}</p>
      <p className={styles.gatedAssurance}>
        {chinese
          ? '系统没有显示未授权、过期、历史规则或合成数据替代品。'
          : 'No unlicensed, stale, historical-rule, or synthetic substitute was shown.'}
      </p>
      <p className={styles.gatedMeta}>
        {chinese ? '检查截止' : 'Checked through'}{' '}
        {new Date(envelope.observation_cutoff).toLocaleString(locale)} ·{' '}
        {chinese ? '审计编号' : 'Audit'}{' '}
        {envelope.request_id.slice(0, 8)}
      </p>

      {blockers.length > 0 ? (
        <details className={styles.technicalDetails}>
          <summary>
            <span>{chinese ? '技术详情' : 'Technical details'}</span>
            <span>
              {blockers.length}{' '}
              {chinese
                ? '项原因'
                : blockers.length === 1
                  ? 'reason'
                  : 'reasons'}
            </span>
          </summary>
          <div>
            <button type="button" onClick={() => void copyTechnicalReasons()}>
              {copyState === 'copied' ? (
                <Check size={13} aria-hidden="true" />
              ) : (
                <Copy size={13} aria-hidden="true" />
              )}
              {copyState === 'copied'
                ? chinese
                  ? '已复制'
                  : 'Copied'
                : chinese
                  ? '复制原因'
                  : 'Copy reason'}
            </button>
            {blockers.map((blocker) => (
              <code key={blocker}>
                {humanizeDataBlocker(blocker, locale)}
                {'\n'}
                {chinese ? '诊断代码' : 'Diagnostic code'}: {blocker}
              </code>
            ))}
            <span className={styles.copyStatus} role="status" aria-live="polite">
              {copyState === 'error'
                ? chinese
                  ? '无法访问剪贴板，请手动选择上方原因。'
                  : 'Clipboard access was unavailable. Select the reason above to copy it.'
                : ''}
            </span>
          </div>
        </details>
      ) : null}
    </section>
  );
}

function OwnerModelPreview({ preview }: { preview: MoomooOwnerPreview }) {
  const rows = [...(preview.prediction_layer ?? [])].sort(
    (left, right) => (left.horizon_minutes ?? 0) - (right.horizon_minutes ?? 0)
  );
  const replay = preview.preview_mode === 'DETERMINISTIC_REPLAY';
  return (
    <div className={styles.predictionDetails}>
      <div className={styles.reportMeta}>
        <span className={`${styles.compliancePill} ${styles.allowed}`}>
          <ShieldCheck size={13} />
          Owner-only Rust model output
        </span>
        <span className={`${styles.compliancePill} ${styles.blocked}`}>
          Customer publication withheld
        </span>
        <span>{replay ? 'Historical replay - not live' : 'Moomoo live forward shadow'}</span>
      </div>
      <div className={styles.signalGrid}>
        {rows.map((row) => {
          const expectedPct =
            typeof row.expected_return === 'number' ? row.expected_return * 100 : null;
          return (
            <div
              className={styles.signalCard}
              key={`${preview.symbol || 'UNKNOWN'}-${row.horizon_minutes || 0}`}
            >
              <div className={styles.signalTopline}>
                <strong>{preview.symbol || 'Unknown symbol'}</strong>
                <span>{row.horizon_minutes || 0} minute horizon</span>
              </div>
              <p>
                Reference{' '}
                {typeof row.reference_price === 'number'
                  ? `$${row.reference_price.toFixed(2)}`
                  : 'withheld'}{' '}
                - raw conditional mean{' '}
                {expectedPct === null
                  ? 'withheld'
                  : `${expectedPct >= 0 ? '+' : ''}${expectedPct.toFixed(3)}%`}
              </p>
              <small>
                Unpromoted shadow research. Calibrated up/down probability, ranking,
                advice, and execution are withheld.
              </small>
            </div>
          );
        })}
      </div>
      <p className={styles.detailNote}>
        Cutoff: {preview.observation_cutoff || 'unavailable'} - source: official Moomoo
        OpenD owner session - {preview.probability_publication_status || 'probability withheld'}.{' '}
        <a href="/quant/intraday">Open full owner dashboard</a>.
      </p>
    </div>
  );
}

function MonitorReceipt({ action }: { action: MarketMonitorAction }) {
  const ready =
    action.status === 'CREATED' || action.status === 'ALREADY_ACTIVE';
  const monitor = action.monitor;
  const cadence =
    monitor?.cadence_minutes != null
      ? `${monitor.cadence_minutes} min`
      : null;

  return (
    <div
      className={`${styles.monitorReceipt} ${
        ready ? styles.monitorReceiptReady : styles.monitorReceiptBlocked
      }`}
    >
      <BellRing size={15} aria-hidden="true" />
      <div>
        <strong>
          {ready
            ? action.status === 'ALREADY_ACTIVE'
              ? 'Monitor already active'
              : 'Monitor created'
            : action.status === 'AUTHENTICATION_REQUIRED'
              ? 'Sign in required'
              : 'Monitor unavailable'}
        </strong>
        <p>{action.message}</p>
        {monitor ? (
          <span>
            {monitor.query.setup_type.replaceAll('_', ' ')}
            {monitor.query.symbols.length > 0
              ? ` · ${monitor.query.symbols.join(', ')}`
              : ''}
            {cadence ? ` · every ${cadence}` : ''}
          </span>
        ) : null}
      </div>
    </div>
  );
}

function ConversationProvenance({
  receipt,
}: {
  receipt: ConversationReceipt;
}) {
  const chinese = receipt.locale === 'zh-CN';
  const grounded = receipt.llm_role === 'grounded_explainer';
  return (
    <div
      className={styles.explanationProvenance}
      data-role={receipt.llm_role}
      aria-label={chinese ? '解释来源' : 'Explanation provenance'}
    >
      <BrainCircuit size={15} aria-hidden="true" />
      <div>
        <strong>
          {grounded
            ? chinese
              ? '基于证据的语言解释'
              : 'Grounded language explanation'
            : chinese
              ? '确定性备用解释'
              : 'Deterministic fallback explanation'}
        </strong>
        <p>
          {grounded
            ? chinese
              ? '语言模型只解释上方 Rust 证据；它没有生成行情、概率或方向。'
              : 'The language model only explained the Rust evidence above; it did not generate market facts, probabilities, or direction.'
            : chinese
              ? '本次未使用语言模型生成结论；文字由受约束模板直接渲染。'
              : 'No language model generated this conclusion; constrained templates rendered it directly.'}{' '}
          {chinese ? '知识版本' : 'Knowledge version'}{' '}
          <code>{receipt.knowledge_version}</code>
          {' · '}
          {chinese ? '解释模型' : 'Explanation model'}{' '}
          <code>
            {receipt.llm_model ??
              (grounded ? 'server-configured LLM' : 'deterministic-template')}
          </code>
        </p>
      </div>
    </div>
  );
}

function Composer({
  value,
  setValue,
  loading,
  textareaRef,
  onSubmit,
  onKeyDown,
  autoFocus = false,
}: {
  value: string;
  setValue: (value: string) => void;
  loading: boolean;
  textareaRef: React.RefObject<HTMLTextAreaElement>;
  onSubmit: (event: FormEvent<HTMLFormElement>) => void;
  onKeyDown: (event: KeyboardEvent<HTMLTextAreaElement>) => void;
  autoFocus?: boolean;
}) {
  return (
    <form className={styles.composer} onSubmit={onSubmit}>
      <textarea
        ref={textareaRef}
        value={value}
        onChange={(event) => setValue(event.target.value)}
        onKeyDown={onKeyDown}
        placeholder="Ask AXIO7 to scan, backtest, or continuously monitor a setup..."
        rows={1}
        maxLength={2000}
        autoFocus={autoFocus}
        aria-label="Your market research question"
      />
      <div className={styles.composerFooter}>
        <div className={styles.modelPill}>
          AXIO7 Research
        </div>
        <button
          type="submit"
          className={styles.sendButton}
          disabled={loading || !value.trim()}
          aria-label="Send question"
        >
          <ArrowUp size={18} strokeWidth={2.4} />
        </button>
      </div>
    </form>
  );
}

function formatNumber(value: number | null, digits = 2) {
  if (value === null || !Number.isFinite(value)) return '—';
  return new Intl.NumberFormat('en-US', {
    maximumFractionDigits: digits,
  }).format(value);
}

function formatPercent(value: number | null) {
  if (value === null || !Number.isFinite(value)) return '—';
  return `${value >= 0 ? '+' : ''}${value.toFixed(2)}%`;
}

function sourceStateLabel(state: ForecastSourceState) {
  const labels: Record<ForecastSourceState, string> = {
    real_time: 'Real-time',
    delayed: 'Delayed',
    historical: 'Historical',
    partial: 'Partial',
    computed: 'Computed',
    unavailable: 'Unavailable',
  };
  return labels[state];
}

function PredictionDetails({
  forecast,
  locale,
  onRetry,
  onPreparePrompt,
}: {
  forecast: ForecastChatResult;
  locale: ConversationReceipt['locale'];
  onRetry: () => void;
  onPreparePrompt: (prompt: string) => void;
}) {
  if (forecast.dailyRegime) {
    return (
      <DailyRegimeDetails
        report={forecast.dailyRegime}
        forecast={forecast}
        locale={locale}
      />
    );
  }
  if (forecast.research && forecast.sessionSummary) {
    return (
      <SessionSummaryDetails
        summary={forecast.sessionSummary}
        disclaimer={forecast.disclaimer}
        locale={locale}
      />
    );
  }
  if (forecast.research) {
    return (
      <ResearchDetails
        envelope={forecast.research}
        disclaimer={forecast.disclaimer}
        locale={locale}
        onRetry={onRetry}
        onPreparePrompt={onPreparePrompt}
      />
    );
  }
  const assets = forecast.assets.slice(0, 4);
  const activeSources = forecast.sources.filter(
    (source) => source.state !== 'unavailable'
  );
  const evidence = forecast.evidence.slice(0, 6);

  return (
    <div className={styles.predictionDetails}>
      <div className={styles.reportMeta}>
        <span className={`${styles.compliancePill} ${styles.allowed}`}>
          <ShieldCheck size={13} />
          Model connected
        </span>
        <span>{forecast.horizon.replaceAll('_', ' ')}</span>
        <span>{activeSources.length} connected sources</span>
      </div>

      {assets.length > 0 ? (
        <div className={styles.signalGrid}>
          {assets.map((asset) => {
            const probabilityUp = asset.prediction?.probabilityUpPct ?? 0;
            return (
              <div className={styles.signalCard} key={asset.dataSymbol}>
                <div className={styles.signalTopline}>
                  <strong>{asset.symbol}</strong>
                  <span>{asset.trendLabel}</span>
                </div>
                <p>
                  {formatNumber(asset.price)} · 1D{' '}
                  {formatPercent(asset.changePct)} · 1M{' '}
                  {formatPercent(asset.change1mPct)} · RSI{' '}
                  {formatNumber(asset.rsi14, 1)}
                  {asset.prediction
                    ? ` · Model ${formatPercent(
                        asset.prediction.expectedReturnPct
                      )}`
                    : ''}
                </p>
                <div className={styles.confidence}>
                  <span>
                    {asset.prediction
                      ? `${asset.prediction.horizonTradingDays}D P(up)`
                      : 'History'}
                  </span>
                  <i>
                    <b
                      style={{
                        width: asset.prediction
                          ? `${probabilityUp}%`
                          : `${Math.min(
                              100,
                              Math.round(
                                (asset.historyObservations / 504) * 100
                              )
                            )}%`,
                      }}
                    />
                  </i>
                  <strong>
                    {asset.prediction
                      ? `${probabilityUp.toFixed(1)}% · ${asset.prediction.analogCount} analogs`
                      : `${asset.historyObservations} bars`}
                  </strong>
                </div>
              </div>
            );
          })}
        </div>
      ) : null}

      <details className={styles.evidence}>
        <summary>
          <span>Data connections</span>
          <span>{activeSources.length} active</span>
        </summary>
        <div>
          {forecast.sources.map((source) => (
            <article key={source.id}>
              <i data-state={source.state} />
              <div>
                <strong>{source.name}</strong>
                <p>
                  {sourceStateLabel(source.state)} · {source.role}
                  {source.asOf
                    ? ` · ${new Date(source.asOf).toLocaleString()}`
                    : ''}
                </p>
              </div>
            </article>
          ))}
        </div>
      </details>

      {evidence.length > 0 ? (
        <details className={styles.evidence}>
          <summary>
            <span>Research evidence</span>
            <span>{evidence.length} items</span>
          </summary>
          <div>
            {evidence.map((event) => (
              <article key={event.id}>
                <i />
                <div>
                  {event.url ? (
                    <a href={event.url} target="_blank" rel="noreferrer">
                      {event.title}
                    </a>
                  ) : (
                    <strong>{event.title}</strong>
                  )}
                  <p>
                    {event.source} · {event.kind.replaceAll('_', ' ')}
                  </p>
                </div>
              </article>
            ))}
          </div>
        </details>
      ) : null}

      <p className={styles.reportDisclaimer}>{forecast.disclaimer}</p>
    </div>
  );
}

function metricNumber(value: unknown, digits = 2) {
  return typeof value === 'number' && Number.isFinite(value)
    ? value.toFixed(digits)
    : '—';
}

function metricPercent(value: unknown, digits = 1) {
  return typeof value === 'number' && Number.isFinite(value)
    ? `${(value * 100).toFixed(digits)}%`
    : '—';
}

function asRecord(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

function metricString(value: unknown) {
  return typeof value === 'string' && value.trim() ? value : undefined;
}

function formatResearchTime(
  value: string | null | undefined,
  locale: ConversationReceipt['locale'] = 'en-US'
) {
  if (!value) return locale === 'zh-CN' ? '不可用' : 'unavailable';
  const parsed = new Date(value);
  if (Number.isNaN(parsed.valueOf())) {
    return locale === 'zh-CN' ? '不可用' : 'unavailable';
  }
  return `${parsed.toLocaleString(locale, {
    timeZone: 'America/New_York',
  })} ET`;
}

type DisplayReadinessState = 'ready' | 'waiting' | 'blocked' | 'not_checked';

function normalizedReadinessState(value: unknown): DisplayReadinessState {
  if (value === 'ready' || value === 'waiting' || value === 'blocked') {
    return value;
  }
  return 'not_checked';
}

function readinessStateLabel(
  state: DisplayReadinessState,
  locale: ConversationReceipt['locale']
) {
  if (locale !== 'zh-CN') return state.replaceAll('_', ' ');
  if (state === 'ready') return '已就绪';
  if (state === 'waiting') return '等待中';
  if (state === 'blocked') return '被阻止';
  return '未检查';
}

function researchStatusLabel(
  status: string,
  locale: ConversationReceipt['locale']
) {
  if (locale !== 'zh-CN') return status.replaceAll('_', ' ');
  const labels: Record<string, string> = {
    AVAILABLE: '可用',
    PARTIAL: '部分可用',
    DATA_UNAVAILABLE: '数据不可用',
    UNCALIBRATED_RESEARCH_OUTPUT: '未校准研究输出',
    VALIDATED_STATISTICAL_CANDIDATE: '已验证统计候选',
    TRIGGERED: '条件已触发',
    NOT_TRIGGERED: '条件未触发',
    INSUFFICIENT_EVIDENCE: '证据不足',
    NO_DEMONSTRATED_EDGE: '未证明存在优势',
    POSITIVE_AFTER_COST_DESCRIPTIVE: '成本后描述性为正',
  };
  return labels[status] ?? status;
}

function historicalAssessmentText(
  row: QuantHistoricalStats,
  locale: ConversationReceipt['locale']
) {
  if (locale !== 'zh-CN') return row.edge_classification_detail;
  if (row.edge_classification === 'INSUFFICIENT_EVIDENCE') {
    return '完整的成本后收益指标不足，不能得出优势结论。';
  }
  if (row.edge_classification === 'POSITIVE_AFTER_COST_DESCRIPTIVE') {
    return '描述性样本的成本后均值、中位数和累计收益均为正，但这不证明统计优势。';
  }
  return typeof row.cumulative_net_return === 'number' &&
    row.cumulative_net_return < 0
    ? '该探索性规则在所列成本后亏损，没有显示出优势。'
    : '至少一项关键成本后收益指标不为正，没有显示出优势。';
}

function localizedCaveat(
  caveat: string,
  locale: ConversationReceipt['locale']
) {
  if (locale !== 'zh-CN') return caveat;
  if (/No candidate is an order/i.test(caveat)) {
    return '任何候选都不是订单、个性化建议或保证结果。';
  }
  if (/gamma structure score/i.test(caveat)) {
    return 'Gamma 结构分数是确定性研究启发式指标，不是挤压概率。';
  }
  if (/Dealer position sign/i.test(caveat)) {
    return '系统无法直接观察做市商持仓方向、开平仓意图、场外库存或复杂订单净方向。';
  }
  if (/UNCALIBRATED_RESEARCH_OUTPUT/i.test(caveat)) {
    return '未校准研究输出只显示新鲜的模型状态；概率、预期涨跌幅、排名和执行字段均暂缓发布。';
  }
  if (/neutral model forecast is atomic/i.test(caveat)) {
    return '中性核心模型预测必须同时发布全部配置周期；任一周期缺失、重复、过期或不兼容时，整组结果都会暂缓。';
  }
  if (/deterministic completed-bar condition/i.test(caveat)) {
    return '完整 K 线上的确定性条件仅为研究背景，不是校准预测概率。';
  }
  return `后端原始限制：${caveat}`;
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

function orderedResearchCandidates(candidates: QuantResearchCandidate[]) {
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

function interpretedProxy(
  query: QuantEvidenceEnvelope['query'],
  locale: ConversationReceipt['locale']
) {
  return query.symbols.includes('SPX')
    ? locale === 'zh-CN'
      ? 'SPX → SPY（量价与 VWAP 代理）'
      : 'SPX → SPY (price/volume and VWAP proxy)'
    : 'None';
}

function historicalPrompt(
  query: QuantEvidenceEnvelope['query'],
  locale: ConversationReceipt['locale']
) {
  const symbols = query.symbols.join(', ');
  const explicitRule =
    query.setup_type !== 'model_forecast' &&
    query.filters.direction !== undefined &&
    query.horizon_minutes !== undefined;
  if (explicitRule) {
    return locale === 'zh-CN'
      ? `仅使用历史数据回放 ${symbols} 的 ${query.filters.direction === 'up' ? '上涨' : '下跌'} ${query.setup_type.replaceAll('_', ' ')} 条件，周期 ${query.horizon_minutes} 分钟。不要把结果当作当前模型预测。`
      : `Run a historical-only replay for ${symbols}: ${query.filters.direction} ${query.setup_type.replaceAll('_', ' ')}, ${query.horizon_minutes}-minute horizon. Do not present it as the current model forecast.`;
  }
  return locale === 'zh-CN'
    ? `为 ${symbols} 设置一个仅历史回放。请先让我明确选择形态、上涨或下跌方向，以及 5/15/30/60 分钟周期；不要替我假设。`
    : `Set up a historical-only replay for ${symbols}. First ask me to choose the setup, up/down direction, and a 5/15/30/60-minute horizon; do not assume them for me.`;
}

function assumptionsPrompt(
  query: QuantEvidenceEnvelope['query'],
  locale: ConversationReceipt['locale']
) {
  const symbols = query.symbols.join(', ');
  return locale === 'zh-CN'
    ? `修改 ${symbols} 研究条件。当前形态：${query.setup_type.replaceAll('_', ' ')}；当前方向：${query.filters.direction ?? '由模型判断'}；当前周期：${query.horizon_minutes ?? '全部已配置周期'}。我要修改：`
    : `Change the research assumptions for ${symbols}. Current setup: ${query.setup_type.replaceAll('_', ' ')}; direction: ${query.filters.direction ?? 'model-owned'}; horizon: ${query.horizon_minutes ?? 'all configured horizons'}. I want to change:`;
}

function InterpretedQuery({
  envelope,
  locale,
}: {
  envelope: QuantEvidenceEnvelope;
  locale: ConversationReceipt['locale'];
}) {
  const query = envelope.query;
  const chinese = locale === 'zh-CN';
  const direction =
    query.filters.direction === undefined
      ? chinese
        ? '由模型判断（未假设）'
        : 'Model-owned (not assumed)'
      : query.filters.direction === 'up'
        ? chinese
          ? '上涨'
          : 'Up'
        : chinese
          ? '下跌'
          : 'Down';
  const horizon =
    query.horizon_minutes === undefined
      ? chinese
        ? '全部已配置周期'
        : 'All configured horizons'
      : chinese
        ? `${query.horizon_minutes} 分钟`
        : `${query.horizon_minutes} minutes`;
  const mode = query.filters.include_historical
    ? query.filters.require_realtime
      ? chinese
        ? '实时 + 明确请求的历史回放'
        : 'Live + explicitly requested history'
      : chinese
        ? '仅历史'
        : 'Historical only'
    : query.filters.require_realtime
      ? chinese
        ? '仅实时'
        : 'Live only'
      : chinese
        ? '非实时研究'
        : 'Non-realtime research';
  const proxy = interpretedProxy(query, locale);

  const rows = [
    [chinese ? '标的' : 'Symbols', query.symbols.join(', ')],
    [
      chinese ? '量价代理' : 'Price/volume proxy',
      proxy === 'None' ? (chinese ? '无' : proxy) : proxy,
    ],
    [
      chinese ? '形态' : 'Setup',
      query.setup_type === 'model_forecast'
        ? chinese
          ? '核心模型预测'
          : 'Core model forecast'
        : query.setup_type.replaceAll('_', ' '),
    ],
    [chinese ? '方向' : 'Direction', direction],
    [chinese ? '周期' : 'Horizon', horizon],
    [chinese ? '模式' : 'Mode', mode],
  ];

  return (
    <section
      className={styles.interpretedQuery}
      aria-label={chinese ? 'AXIO7 对查询的解释' : 'AXIO7 interpreted query'}
    >
      <div className={styles.interpretedHeading}>
        <strong>{chinese ? 'AXIO7 对查询的解释' : 'AXIO7 interpreted query'}</strong>
        <span>
          {chinese ? '未从 ticker 猜测形态、方向或周期' : 'No setup, direction, or horizon inferred from a ticker'}
        </span>
      </div>
      <dl>
        {rows.map(([label, value]) => (
          <div key={label}>
            <dt>{label}</dt>
            <dd>{value}</dd>
          </div>
        ))}
      </dl>
      <p>
        {chinese
          ? `假设：最多返回 ${query.limit} 个结果；实时数据最大年龄 ${query.filters.max_data_age_seconds} 秒；缺失、过期、未授权或非因果输入一律拒绝发布；自动下单始终关闭。`
          : `Assumptions: up to ${query.limit} results; maximum realtime age ${query.filters.max_data_age_seconds}s; missing, stale, unentitled, or non-causal inputs fail closed; automatic execution is always disabled.`}
      </p>
    </section>
  );
}

function DailyRegimeDetails({
  report,
  forecast,
  locale,
}: {
  report: QuantDailyRegimeReport;
  forecast: ForecastChatResult;
  locale: ConversationReceipt['locale'];
}) {
  const chinese = locale === 'zh-CN';
  const hit = report.walk_forward_validation.raw_directional_hit_frequency;
  const newsItems = [
    ...(forecast.newsContext?.gdelt ?? []),
    ...(forecast.newsContext?.hackerNews ?? []),
  ].slice(0, 10);
  const inventory = forecast.modelCodeInventory ?? [];
  const regimeLabel = report.current_regime.label
    .replaceAll('_', ' ')
    .toLowerCase();

  return (
    <div className={styles.predictionDetails}>
      <div className={styles.reportMeta}>
        <span className={`${styles.compliancePill} ${styles.allowed}`}>
          <ShieldCheck size={13} />
          {chinese
            ? '下一交易日类比结果可用'
            : 'Next-session analog result available'}
        </span>
        <span>
          {chinese ? '未经校准的研究倾向' : 'Uncalibrated research lean'}
        </span>
        <span>SPX → SPY</span>
      </div>

      <div className={styles.signalGrid}>
        <div className={styles.signalCard}>
          <div className={styles.signalTopline}>
            <strong>
              {chinese ? '下一交易日倾向' : 'Next-session lean'}
            </strong>
            <span>{report.prediction.lean}</span>
          </div>
          <p>
            {report.prediction.raw_up_count}/{report.prediction.analog_sample_size}{' '}
            {chinese ? '个类比随后上涨' : 'analogs followed by an up session'} ·{' '}
            {formatNumber(report.prediction.raw_up_frequency * 100)}%
          </p>
          <p>
            {chinese ? '下一交易日收益中位数' : 'Median next-session return'}{' '}
            {formatPercent(report.prediction.median_next_session_return_pct)} ·{' '}
            {chinese ? '均值' : 'mean'}{' '}
            {formatPercent(report.prediction.mean_next_session_return_pct)}
          </p>
          <div className={styles.signalLineage}>
            <p>
              {chinese
                ? '原始历史频率，不是校准概率。'
                : 'Raw historical frequency, not a calibrated probability.'}
            </p>
          </div>
        </div>

        <div className={styles.signalCard}>
          <div className={styles.signalTopline}>
            <strong>{chinese ? '当前市场状态' : 'Current market regime'}</strong>
            <span>{regimeLabel}</span>
          </div>
          <p>{report.current_regime.definition}</p>
          <p>
            {chinese ? '波动率历史分位' : 'Volatility percentile'}{' '}
            {formatNumber(
              report.current_regime.volatility_percentile_prior_252 * 100
            )}
            % · {chinese ? '跨资产广度' : 'cross-asset breadth'}{' '}
            {formatNumber(report.current_regime.cross_asset_breadth * 100)}%
          </p>
        </div>

        <div className={styles.signalCard}>
          <div className={styles.signalTopline}>
            <strong>{report.current_market.session_date_et}</strong>
            <span>{formatPercent(report.current_market.session_return_pct)}</span>
          </div>
          <p>
            O {formatNumber(report.current_market.open)} · H{' '}
            {formatNumber(report.current_market.high)} · L{' '}
            {formatNumber(report.current_market.low)} · C{' '}
            {formatNumber(report.current_market.close)}
          </p>
          <p>
            20D {formatPercent(report.current_market.twenty_session_return_pct)} ·{' '}
            {chinese ? '20日年化波动' : '20D annualized volatility'}{' '}
            {formatPercent(
              report.current_market.twenty_session_annualized_volatility_pct
            )}
          </p>
        </div>

        <div className={styles.signalCard}>
          <div className={styles.signalTopline}>
            <strong>
              {chinese ? '滚动样本外检查' : 'Walk-forward check'}
            </strong>
            <span>{report.walk_forward_validation.method.replaceAll('_', ' ')}</span>
          </div>
          <p>
            {report.walk_forward_validation.directional_calls}{' '}
            {chinese ? '次方向判断' : 'directional calls'} ·{' '}
            {report.walk_forward_validation.correct_directional_calls}{' '}
            {chinese ? '次方向正确' : 'directionally correct'}
          </p>
          <p>
            {chinese ? '原始命中频率' : 'Raw hit frequency'}{' '}
            {hit === null ? 'unavailable' : `${formatNumber(hit * 100)}%`}
          </p>
          <div className={styles.signalLineage}>
            <p>
              {chinese
                ? '扩展窗口、严格按时间顺序、隔离一个完整交易日；仍不是未来概率。'
                : 'Expanding, chronological, and purged by one complete session; still not a future probability.'}
            </p>
          </div>
        </div>
      </div>

      <details className={styles.evidence} open>
        <summary>
          <span>
            {chinese ? '最相似的历史市场状态' : 'Most similar historical regimes'}
          </span>
          <span>{report.similar_historical_sessions.length}</span>
        </summary>
        <div>
          {report.similar_historical_sessions.map((analog) => (
            <article key={`${analog.rank}-${analog.session_date_et}`}>
              <i />
              <div>
                <strong>
                  #{analog.rank} · {analog.session_date_et} ·{' '}
                  {analog.regime.replaceAll('_', ' ').toLowerCase()}
                </strong>
                <p>
                  {chinese ? '当日' : 'session'}{' '}
                  {formatPercent(analog.session_return_pct)} →{' '}
                  {analog.next_session_date_et}{' '}
                  {formatPercent(analog.next_session_return_pct)} ·{' '}
                  {chinese ? '标准化距离' : 'standardized distance'}{' '}
                  {formatNumber(analog.standardized_euclidean_distance, 3)}
                </p>
              </div>
            </article>
          ))}
        </div>
      </details>

      <details className={styles.evidence}>
        <summary>
          <span>{chinese ? '宏观背景（仅展示）' : 'Macro context (display only)'}</span>
          <span>{forecast.macroContext?.reliability ?? 'unavailable'}</span>
        </summary>
        <div>
          {(forecast.macroContext?.series ?? []).map((series) => (
            <article key={series.id}>
              <i data-state={series.status} />
              <div>
                <a href={series.sourceUrl} target="_blank" rel="noreferrer">
                  {series.id} · {series.title}
                </a>
                <p>
                  {series.latest === null
                    ? 'unavailable'
                    : `${formatNumber(series.latest)} ${series.unit}`}{' '}
                  · {series.asOf ?? 'no as-of date'} · {series.source}
                </p>
              </div>
            </article>
          ))}
        </div>
      </details>

      <details className={styles.evidence}>
        <summary>
          <span>{chinese ? '新闻背景（仅展示）' : 'News context (display only)'}</span>
          <span>{newsItems.length}</span>
        </summary>
        <div>
          {newsItems.length > 0 ? (
            newsItems.map((item) => (
              <article key={item.id}>
                <i />
                <div>
                  {item.url ? (
                    <a href={item.url} target="_blank" rel="noreferrer">
                      {item.title}
                    </a>
                  ) : (
                    <strong>{item.title}</strong>
                  )}
                  <p>
                    {item.source} · {new Date(item.publishedAt).toLocaleString(locale)} ·{' '}
                    {item.tickers.join(', ') || 'market context'}
                  </p>
                </div>
              </article>
            ))
          ) : (
            <article>
              <i data-state="unavailable" />
              <div>
                <strong>{chinese ? '没有可靠新闻命中' : 'No reliable news hits'}</strong>
                <p>
                  {chinese
                    ? '新闻缺失不会被合成内容替代。'
                    : 'Missing news is not replaced with synthetic content.'}
                </p>
              </div>
            </article>
          )}
        </div>
      </details>

      <details className={styles.evidence}>
        <summary>
          <span>{chinese ? '模型与算法源码清单' : 'Model and algorithm source list'}</span>
          <span>{inventory.length}</span>
        </summary>
        <div>
          {inventory.map((item) => (
            <article key={item.id}>
              <i data-state={item.status === 'active' ? 'computed' : 'historical'} />
              <div>
                <a href={item.sourceUrl} target="_blank" rel="noreferrer">
                  {item.name}
                </a>
                <p>
                  {item.layer.replaceAll('_', ' ')} · {item.status.replaceAll('_', ' ')}
                  {' · '}
                  {item.algorithm}
                </p>
                <code>{item.sourcePath}</code>
              </div>
            </article>
          ))}
        </div>
      </details>

      <details className={styles.evidence}>
        <summary>
          <span>{chinese ? '特征、覆盖率和数据血缘' : 'Features, coverage, and lineage'}</span>
          <span>{report.feature_snapshot.length} features</span>
        </summary>
        <div>
          {report.feature_snapshot.map((feature) => (
            <article key={feature.name}>
              <i />
              <div>
                <strong>{feature.name.replaceAll('_', ' ')}</strong>
                <p>
                  {formatNumber(feature.value, 4)} · {feature.unit}
                </p>
              </div>
            </article>
          ))}
          {report.source.files.map((file) => (
            <article key={file.sha256}>
              <i data-state="historical" />
              <div>
                <strong>{file.request_name}</strong>
                <p>
                  Databento {report.source.dataset} · {formatNumber(file.bytes, 0)} bytes ·{' '}
                  {new Date(file.acquired_at).toLocaleString(locale)}
                </p>
                <code>{file.sha256}</code>
              </div>
            </article>
          ))}
        </div>
      </details>

      <p className={styles.reportDisclaimer}>
        {forecast.disclaimer} {report.macro_news_policy.detail}
      </p>
    </div>
  );
}

function SessionSummaryDetails({
  summary,
  disclaimer,
  locale,
}: {
  summary: QuantSessionSummary;
  disclaimer: string;
  locale: ConversationReceipt['locale'];
}) {
  const chinese = locale === 'zh-CN';
  const latest = summary.latest_completed_bar;
  const complete = summary.status === 'COMPLETE_78_BAR_SESSION';
  const trendLabel = chinese
    ? summary.trend_state === 'UP_SESSION'
      ? '上涨时段'
      : summary.trend_state === 'DOWN_SESSION'
        ? '下跌时段'
        : '平盘时段'
    : summary.trend_state.replaceAll('_', ' ').toLowerCase();

  return (
    <div className={styles.predictionDetails}>
      <div className={styles.reportMeta}>
        <span className={`${styles.compliancePill} ${styles.allowed}`}>
          <ShieldCheck size={13} />
          {chinese ? 'Databento 结果可用' : 'Databento result available'}
        </span>
        <span>
          {complete
            ? chinese
              ? '完整常规交易时段'
              : 'Complete regular session'
            : chinese
              ? '当前时段截至目前'
              : 'Current session to date'}
        </span>
        <span>
          {summary.five_minute_bar_count}
          {complete ? '/78' : ''} {chinese ? '根 5 分钟数据' : 'five-minute bars'}
        </span>
      </div>

      <div className={styles.signalGrid}>
        <div className={styles.signalCard}>
          <div className={styles.signalTopline}>
            <strong>
              {summary.public_symbol} → {summary.data_symbol}
            </strong>
            <span>{trendLabel}</span>
          </div>
          <p>
            {chinese ? '开盘' : 'Open'} {formatNumber(summary.session_open)} ·{' '}
            {chinese ? '最高' : 'High'} {formatNumber(summary.session_high)} ·{' '}
            {chinese ? '最低' : 'Low'} {formatNumber(summary.session_low)} ·{' '}
            {chinese ? '收盘' : 'Close'} {formatNumber(summary.session_close)}
          </p>
          <p>
            {summary.session_date_et} · {formatPercent(summary.session_return_pct)} ·{' '}
            {chinese ? '区间' : 'range'} {formatPercent(summary.session_range_pct)}
          </p>
          <div className={styles.signalLineage}>
            <p>{summary.proxy_disclosure}</p>
            <p>
              {chinese ? '区间收盘位置' : 'Close location'}{' '}
              {formatPercent(summary.close_location_pct)} ·{' '}
              {chinese ? '成交量' : 'volume'} {formatNumber(summary.total_volume, 0)}
            </p>
          </div>
        </div>

        <div className={styles.signalCard}>
          <div className={styles.signalTopline}>
            <strong>{chinese ? '最新完整窗口' : 'Latest completed window'}</strong>
            <span>{latest ? `#${latest.bar_number}` : 'unavailable'}</span>
          </div>
          <p>
            {latest
              ? `${new Date(latest.window_end).toLocaleTimeString(locale, {
                  hour: 'numeric',
                  minute: '2-digit',
                  timeZone: 'America/New_York',
                })} ET · ${formatNumber(latest.close)} · ${formatPercent(
                  latest.return_pct
                )}`
              : chinese
                ? '尚无完整 5 分钟窗口'
                : 'No completed five-minute window yet'}
          </p>
          <p>
            {chinese ? '收盘-成交量代理' : 'Close-volume proxy'}{' '}
            {formatNumber(summary.close_volume_proxy)} ·{' '}
            {formatNumber(summary.close_vs_close_volume_proxy_bps, 1)} bps
          </p>
          <div className={styles.signalLineage}>
            <p>
              {summary.source.provider} {summary.source.dataset} ·{' '}
              {summary.source.schema} · {summary.minute_rows}{' '}
              {chinese ? '根 1 分钟数据' : 'one-minute rows'}
            </p>
            <p>
              {chinese ? '最后可用时间' : 'Available at'}{' '}
              {new Date(summary.source.last_available_at).toLocaleString(locale)}
            </p>
          </div>
        </div>
      </div>

      <details className={styles.evidence}>
        <summary>
          <span>{chinese ? '峰值窗口' : 'Peak five-minute windows'}</span>
          <span>{summary.peak_windows.length}</span>
        </summary>
        <div>
          {summary.peak_windows.map((bar) => (
            <article key={bar.bar_number}>
              <i />
              <div>
                <strong>
                  #{bar.bar_number} · {formatPercent(bar.return_pct)}
                </strong>
                <p>
                  {formatNumber(bar.open)} → {formatNumber(bar.close)} ·{' '}
                  {new Date(bar.window_end).toLocaleTimeString(locale, {
                    hour: 'numeric',
                    minute: '2-digit',
                    timeZone: 'America/New_York',
                  })}{' '}
                  ET
                </p>
              </div>
            </article>
          ))}
        </div>
      </details>

      <details className={styles.evidence}>
        <summary>
          <span>{chinese ? '完整 5 分钟时段图' : 'Full five-minute session map'}</span>
          <span>{summary.five_minute_bars.length}</span>
        </summary>
        <div>
          {summary.five_minute_bars.map((bar) => (
            <article key={bar.bar_number}>
              <i />
              <div>
                <strong>
                  #{bar.bar_number} · {formatPercent(bar.return_pct)}
                </strong>
                <p>
                  O {formatNumber(bar.open)} · H {formatNumber(bar.high)} · L{' '}
                  {formatNumber(bar.low)} · C {formatNumber(bar.close)} · V{' '}
                  {formatNumber(bar.volume, 0)}
                </p>
              </div>
            </article>
          ))}
        </div>
      </details>

      <p className={styles.reportDisclaimer}>
        {chinese
          ? '这是由 Rust 引擎根据 Databento 数据生成的 SPY→SPX 历史/时段内观测结果，不是实时模型概率、个性化建议或订单。'
          : `${disclaimer} This observed SPY→SPX result is not a live model probability or an order.`}
      </p>
    </div>
  );
}

function RecoveryActions({
  envelope,
  locale,
  onRetry,
  onPreparePrompt,
}: {
  envelope: QuantEvidenceEnvelope;
  locale: ConversationReceipt['locale'];
  onRetry: () => void;
  onPreparePrompt: (prompt: string) => void;
}) {
  const chinese = locale === 'zh-CN';
  const readinessId = `readiness-${envelope.request_id}`;
  return (
    <nav
      className={styles.recoveryActions}
      aria-label={chinese ? '恢复操作' : 'Recovery actions'}
    >
      <button type="button" onClick={onRetry}>
        <RefreshCw size={14} aria-hidden="true" />
        {chinese ? '重试实时预测' : 'Retry live'}
      </button>
      <button
        type="button"
        onClick={() =>
          document.getElementById(readinessId)?.scrollIntoView({
            behavior: 'smooth',
            block: 'center',
          })
        }
      >
        <ShieldCheck size={14} aria-hidden="true" />
        {chinese ? '查看就绪状态' : 'View readiness'}
      </button>
      <button
        type="button"
        onClick={() => onPreparePrompt(historicalPrompt(envelope.query, locale))}
      >
        <History size={14} aria-hidden="true" />
        {chinese ? '设置历史回放' : 'Set up historical replay'}
      </button>
      <button
        type="button"
        onClick={() => onPreparePrompt(assumptionsPrompt(envelope.query, locale))}
      >
        <Settings2 size={14} aria-hidden="true" />
        {chinese ? '修改条件' : 'Change assumptions'}
      </button>
    </nav>
  );
}

function ResearchDetails({
  envelope,
  disclaimer,
  locale,
  onRetry,
  onPreparePrompt,
}: {
  envelope: QuantEvidenceEnvelope;
  disclaimer: string;
  locale: ConversationReceipt['locale'];
  onRetry: () => void;
  onPreparePrompt: (prompt: string) => void;
}) {
  const chinese = locale === 'zh-CN';
  const targetArtifacts = Array.isArray(envelope.model_contract.target_artifacts)
    ? envelope.model_contract.target_artifacts
    : [];
  const explicitReadiness = envelope.readiness ?? {};
  const modelReadinessState = normalizedReadinessState(
    explicitReadiness.model?.state
  );
  const rustModelLoaded = modelReadinessState === 'ready';
  const candidates = orderedResearchCandidates(envelope.candidates);
  const liveForecastAvailable = candidates.length > 0;
  const historicalRequested =
    envelope.query.filters.include_historical === true;
  const candidateStatus =
    typeof envelope.model_contract.candidate_status === 'string'
      ? envelope.model_contract.candidate_status
      : 'status unavailable';
  const universeStatus =
    typeof envelope.model_contract.universe_registry_status === 'string'
      ? envelope.model_contract.universe_registry_status
      : 'registry unavailable';
  const evidenceCount = envelope.candidates.reduce(
    (total, candidate) =>
      total +
      candidate.supporting_evidence.length +
      candidate.contrary_evidence.length,
    0
  );
  const detailCount =
    evidenceCount + envelope.data_blockers.length;
  const readinessStages: Array<{
    label: string;
    state: DisplayReadinessState;
  }> = [
    {
      label: chinese ? '模型工件' : 'Model artifacts',
      state: modelReadinessState,
    },
    {
      label: chinese ? '实时数据' : 'Live feed',
      state: normalizedReadinessState(explicitReadiness.feed?.state),
    },
    {
      label: chinese ? '时点上下文' : 'Point-in-time context',
      state: normalizedReadinessState(explicitReadiness.context?.state),
    },
    {
      label: chinese ? '模型推理' : 'Model inference',
      state: normalizedReadinessState(explicitReadiness.inference?.state),
    },
    {
      label: chinese ? '预测发布' : 'Forecast publication',
      state: normalizedReadinessState(explicitReadiness.publication?.state),
    },
  ];
  const relevantCaveats = envelope.caveats.filter((caveat) => {
    if (
      envelope.query.setup_type !== 'gamma_squeeze' &&
      /gamma|dealer|open interest|\bOI\b|OPRA|option chain/i.test(caveat)
    ) {
      return false;
    }
    return (
      historicalRequested ||
      !/historical condition|historical replay|backtest/i.test(caveat)
    );
  });

  return (
    <div className={styles.predictionDetails}>
      <InterpretedQuery envelope={envelope} locale={locale} />
      <div
        className={styles.readinessStrip}
        id={`readiness-${envelope.request_id}`}
        aria-label={chinese ? '实时预测就绪状态' : 'Live forecast readiness'}
      >
        {readinessStages.map((stage) => (
          <span data-state={stage.state} key={stage.label}>
            <i />
            <b>{stage.label}</b>
            <small>{readinessStateLabel(stage.state, locale)}</small>
          </span>
        ))}
      </div>
      <RecoveryActions
        envelope={envelope}
        locale={locale}
        onRetry={onRetry}
        onPreparePrompt={onPreparePrompt}
      />
      <div className={styles.reportMeta}>
        <span
          className={`${styles.compliancePill} ${
            rustModelLoaded
              ? styles.allowed
              : modelReadinessState === 'blocked'
                ? styles.blocked
                : ''
          }`}
        >
          <ShieldCheck size={13} />
          {rustModelLoaded
            ? chinese
              ? '模型工件已加载'
              : 'Model artifacts loaded'
            : modelReadinessState === 'blocked'
              ? chinese
                ? '模型运行时不可用'
                : 'Model runtime unavailable'
              : modelReadinessState === 'waiting'
                ? chinese
                  ? '模型工件加载中'
                  : 'Model artifacts loading'
                : chinese
                  ? '模型就绪状态未检查'
                  : 'Model readiness not checked'}
        </span>
        {!liveForecastAvailable ? (
          <span className={`${styles.compliancePill} ${styles.blocked}`}>
            {chinese ? '未生成实时预测' : 'No live forecast generated'}
          </span>
        ) : null}
        {envelope.status === 'UNCALIBRATED_RESEARCH_OUTPUT' ? (
          <span className={`${styles.compliancePill} ${styles.allowed}`}>
            {chinese
              ? '模型已运行 · 概率暂缓发布'
              : 'Model ran · probability withheld'}
          </span>
        ) : null}
        <span>
          {envelope.query.setup_type === 'model_forecast'
            ? chinese
              ? '核心模型预测'
              : 'Core model forecast'
            : envelope.query.setup_type.replaceAll('_', ' ')}
        </span>
        <span>
          {envelope.query.horizon_minutes === undefined
            ? chinese
              ? '全部已配置周期'
              : 'All configured horizons'
            : chinese
              ? `${envelope.query.horizon_minutes} 分钟周期`
              : `${envelope.query.horizon_minutes} minute horizon`}
        </span>
        <span title={envelope.status}>
          {researchStatusLabel(envelope.status, locale)}
        </span>
      </div>

      {candidates.length > 0 ? (
        <div className={styles.signalGrid}>
          {candidates.map((candidate) => {
            const score = candidate.heuristic_structure_score;
            const barNumber = candidate.metrics.bar_number;
            const horizonMinutes = candidateHorizonMinutes(candidate);
            const modelForecast =
              candidate.setup_type === 'model_forecast';
            const uncalibrated =
              candidate.status === 'UNCALIBRATED_RESEARCH_OUTPUT';
            const probabilityUp = publishedProbabilityUp(candidate);
            const validatedModel =
              candidate.status === 'VALIDATED_STATISTICAL_CANDIDATE';
            const rawOrientation =
              typeof candidate.metrics.statistical_orientation === 'string'
                ? candidate.metrics.statistical_orientation
                : null;
            const orientation = rawOrientation
              ? chinese
                ? rawOrientation === 'up'
                  ? '上涨'
                  : rawOrientation === 'down'
                    ? '下跌'
                    : rawOrientation === 'flat'
                      ? '横盘'
                      : rawOrientation.replaceAll('_', ' ')
                : rawOrientation.replaceAll('_', ' ')
              : chinese
                ? '方向不可用'
                : 'direction unavailable';
            const freshness = candidate.freshness[0];
            const validation = asRecord(candidate.metrics.validation);
            const source =
              freshness?.source ??
              metricString(candidate.metrics.data_source) ??
              'source unavailable';
            const observedAt =
              freshness?.observed_at ??
              metricString(candidate.metrics.observation_cutoff);
            const availableAt =
              freshness?.available_at ??
              metricString(candidate.metrics.latest_input_available_at);
            const modelVersion =
              metricString(validation.model_version) ??
              (chinese ? '模型版本不可用' : 'model version unavailable');
            const featureVersion =
              metricString(validation.feature_version) ??
              (chinese ? '特征版本不可用' : 'feature version unavailable');
            const modelHash = metricString(validation.model_hash);
            const featureHash = metricString(validation.feature_hash);
            const dataManifestHash = metricString(validation.data_manifest_hash);
            const scoreWidth =
              modelForecast
                ? probabilityUp ?? 0
                : typeof score === 'number'
                ? Math.max(0, Math.min(100, score))
                : /^(?:TRIGGERED)(?:_|$)/.test(candidate.status)
                  ? 100
                  : 0;
            return (
              <div
                className={styles.signalCard}
                key={`${candidate.symbol}-${candidate.setup_type}-${
                  horizonMinutes ?? 'unspecified'
                }-${candidate.status}`}
              >
                <div className={styles.signalTopline}>
                  <strong>{candidate.symbol}</strong>
                  <span>
                    {modelForecast
                      ? `${
                          horizonMinutes === null
                            ? chinese
                              ? '周期不可用'
                              : 'horizon unavailable'
                            : chinese
                              ? `${horizonMinutes} 分钟周期`
                              : `${horizonMinutes} minute horizon`
                        } · `
                      : ''}
                    {researchStatusLabel(candidate.status, locale)}
                  </span>
                </div>
                <p>
                  {modelForecast
                    ? probabilityUp !== null
                      ? chinese
                        ? `${orientation} · 已晋升的二元上涨概率 ${probabilityUp.toFixed(
                            1
                          )}% · 下跌/横盘尚未联合校准`
                        : `${orientation} · promoted calibrated binary P(up) ${probabilityUp.toFixed(
                            1
                          )}% · Down/Flat not jointly calibrated`
                      : `${orientation} · ${
                          validatedModel
                            ? chinese
                              ? '概率发布凭据不完整'
                              : 'probability publication receipt incomplete'
                            : chinese
                              ? '未校准模型状态'
                              : 'uncalibrated model condition'
                        } · ${
                          chinese
                            ? '校准概率暂缓发布'
                            : 'calibrated probability withheld'
                        }`
                    : uncalibrated
                    ? chinese
                      ? `${orientation} · 新鲜模型状态 · 不是概率`
                      : `${orientation} · fresh model condition · not a probability`
                    : typeof score === 'number'
                      ? chinese
                        ? `结构分数 ${score.toFixed(1)}/100 · 不是概率`
                        : `Structure ${score.toFixed(1)}/100 · not a probability`
                      : chinese
                        ? `5 分钟第 ${metricNumber(barNumber, 0)} 根 · VWAP ${metricNumber(
                            candidate.metrics.session_vwap
                          )} · 距离 ${metricPercent(
                            candidate.metrics.distance_from_vwap,
                            2
                          )}`
                        : `5m bar ${metricNumber(barNumber, 0)} · VWAP ${metricNumber(
                            candidate.metrics.session_vwap
                          )} · distance ${metricPercent(
                            candidate.metrics.distance_from_vwap,
                            2
                          )}`}
                </p>
                <div className={styles.confidence}>
                  <span>
                    {modelForecast
                      ? probabilityUp !== null
                        ? chinese
                          ? '校准上涨概率'
                          : 'Calibrated P(up)'
                        : chinese
                          ? '模型状态'
                          : 'Model condition'
                      : uncalibrated
                      ? chinese
                        ? '模型状态'
                        : 'Model condition'
                      : typeof score === 'number'
                        ? chinese
                          ? '结构'
                          : 'Structure'
                        : chinese
                          ? '规则状态'
                          : 'Rule state'}
                  </span>
                  <i>
                    <b style={{ width: `${scoreWidth}%` }} />
                  </i>
                  <strong>
                    {modelForecast ? (
                      probabilityUp !== null ? (
                        chinese
                          ? `${probabilityUp.toFixed(1)}% 上涨概率 · 无交易动作`
                          : `${probabilityUp.toFixed(1)}% P(up) · no trade action`
                      ) : validatedModel ? (
                        chinese
                          ? '概率凭据不完整 · 无交易动作'
                          : 'Probability receipt incomplete · no trade action'
                      ) : (
                        chinese
                          ? '无概率 · 无交易动作'
                          : 'No probability · no trade action'
                      )
                    ) : uncalibrated ? (
                      chinese
                        ? '无概率 · 无交易动作'
                        : 'No probability · no trade action'
                    ) : (
                      <>
                        {candidate.supporting_evidence.length}{' '}
                        {chinese ? '项支持' : 'for'} ·{' '}
                        {candidate.contrary_evidence.length}{' '}
                        {chinese ? '项反对' : 'against'}
                      </>
                    )}
                  </strong>
                </div>
                <div className={styles.signalLineage}>
                  <p>
                    {chinese ? '来源' : 'source'} {source} |{' '}
                    {chinese ? '观测' : 'observed'} {formatResearchTime(observedAt, locale)} |{' '}
                    {chinese ? '可用' : 'available'} {formatResearchTime(availableAt, locale)} |{' '}
                    {chinese ? '年龄' : 'age'}{' '}
                    {typeof freshness?.age_seconds === 'number'
                      ? `${freshness.age_seconds}s`
                      : chinese
                        ? '不可用'
                        : 'unavailable'}{' '}
                    | {chinese ? '覆盖率' : 'coverage'}{' '}
                    {metricPercent(freshness?.coverage)} |{' '}
                    {freshness?.realtime
                      ? chinese
                        ? '实时'
                        : 'realtime'
                      : chinese
                        ? '非实时'
                        : 'not realtime'}{' '}
                    |{' '}
                    {freshness?.entitlement ??
                      (chinese ? '授权信息不可用' : 'entitlement unavailable')}
                  </p>
                  <p>
                    {chinese ? '模型' : 'model'} {modelVersion} |{' '}
                    {chinese ? '特征' : 'feature'} {featureVersion} |{' '}
                    {chinese ? '模型哈希' : 'model hash'}{' '}
                    {modelHash?.slice(0, 12) ?? (chinese ? '不可用' : 'unavailable')} |{' '}
                    {chinese ? '特征哈希' : 'feature hash'}{' '}
                    {featureHash?.slice(0, 12) ??
                      (chinese ? '不可用' : 'unavailable')}{' '}
                    | {chinese ? '数据清单' : 'data manifest'}{' '}
                    {dataManifestHash?.slice(0, 12) ??
                      (chinese ? '不可用' : 'unavailable')}
                  </p>
                </div>
              </div>
            );
          })}
        </div>
      ) : null}

      {historicalRequested && envelope.historical.length > 0 ? (
        <div className={styles.signalGrid}>
          {envelope.historical.map((row) => (
            <div
              className={styles.signalCard}
              key={`${row.symbol}-${row.method_version}`}
            >
              <div className={styles.signalTopline}>
                <strong>
                  {row.symbol}{' '}
                  {chinese ? '历史条件回放' : 'historical condition replay'}
                </strong>
                <span>
                  {researchStatusLabel(row.edge_classification, locale)}
                </span>
              </div>
              <p>
                {row.dataset_start || (chinese ? '起始日期不可用' : 'start unavailable')}{' '}
                – {row.dataset_end || (chinese ? '结束日期不可用' : 'end unavailable')}{' '}
                · {row.completed_backtests}{' '}
                {chinese ? '个完整事件' : 'completed events'} / {row.sessions}{' '}
                {chinese ? '个交易日' : 'sessions'} ·{' '}
                {chinese ? '下一根 5 分钟线开盘入场' : 'next 5m open entry'} ·{' '}
                {metricNumber(row.assumed_round_trip_cost_bps, 1)} bps{' '}
                {chinese ? '往返成本' : 'round trip'}
              </p>
              <div
                className={styles.historicalAssessment}
                data-edge={row.edge_classification}
              >
                <strong>{chinese ? '成本后评估' : 'After-cost assessment'}</strong>
                <p>{historicalAssessmentText(row, locale)}</p>
              </div>
              <div className={styles.signalLineage}>
                <p>
                  {chinese ? '成本后均值' : 'after-cost mean'}{' '}
                  {metricPercent(row.mean_net_return, 2)} |{' '}
                  {chinese ? '中位数' : 'median'}{' '}
                  {metricPercent(row.median_net_return, 2)} |{' '}
                  {chinese ? '累计' : 'cumulative'}{' '}
                  {metricPercent(row.cumulative_net_return, 2)} |{' '}
                  {chinese ? '正收益事件占比' : 'positive-event share'}{' '}
                  {metricPercent(row.net_win_rate)} |{' '}
                  {chinese ? '最大回撤' : 'max drawdown'}{' '}
                  {metricPercent(row.max_drawdown, 2)}
                </p>
                <p>
                  {chinese ? '原始收益背景：方向延续' : 'raw return context: directional continuation'}{' '}
                  {metricPercent(row.raw_forward_direction_frequency)} |{' '}
                  {chinese ? '标的中位收益' : 'median underlying return'}{' '}
                  {metricPercent(row.median_forward_return, 2)} | q05/q95{' '}
                  {metricPercent(row.forward_return_q05, 2)} /{' '}
                  {metricPercent(row.forward_return_q95, 2)} |{' '}
                  {chinese
                    ? '仅为描述性结果，不是无条件基准或校准概率'
                    : 'descriptive, not an unconditional benchmark or calibrated probability'}
                </p>
                <p>
                  {chinese ? '来源' : 'source'} {row.source} |{' '}
                  {chinese ? '方法' : 'method'} {row.method_version} |{' '}
                  {chinese ? '清单' : 'manifest'}{' '}
                  {row.data_manifest_hash?.slice(0, 12) ??
                    (chinese ? '不可用' : 'unavailable')}
                </p>
                <p>
                  {row.evidence_grade.replaceAll('_', ' ')} ·{' '}
                  {chinese
                    ? '不是冻结模型的样本外表现 · 永不作为实时预测'
                    : 'not frozen-model out-of-sample performance · never used as a live forecast'}
                </p>
              </div>
            </div>
          ))}
        </div>
      ) : null}

      {detailCount > 0 ? (
        <details className={styles.evidence}>
          <summary>
            <span>{chinese ? '证据与数据检查' : 'Evidence and data checks'}</span>
            <span>
              {detailCount} {chinese ? '项' : 'items'}
            </span>
          </summary>
          <div>
            {envelope.candidates.flatMap((candidate) => [
              ...candidate.supporting_evidence.map((item) => ({
                ...item,
                symbol: candidate.symbol,
                kind: 'supporting',
              })),
              ...candidate.contrary_evidence.map((item) => ({
                ...item,
                symbol: candidate.symbol,
                kind: 'contrary',
              })),
            ]).map((item, index) => (
              <article key={`${item.symbol}-${item.code}-${index}`}>
                <i />
                <div>
                  <strong>
                    {item.symbol} · {item.code.replaceAll('_', ' ')}
                  </strong>
                  <p>
                    {chinese
                      ? item.kind === 'supporting'
                        ? '支持证据'
                        : '反向证据'
                      : item.kind}{' '}
                    · {item.statement}
                  </p>
                </div>
              </article>
            ))}
            {envelope.data_blockers.map((blocker) => (
                  <article key={blocker}>
                    <i />
                    <div>
                      <strong>
                        {chinese ? '实时就绪阻止原因' : 'Live readiness blocker'}
                      </strong>
                      <p title={blocker}>
                        {humanizeDataBlocker(blocker, locale)}
                      </p>
                    </div>
                  </article>
                ))}
          </div>
        </details>
      ) : null}

      <details className={styles.evidence}>
        <summary>
          <span>{chinese ? '模型运行时合同' : 'Model runtime contract'}</span>
          <span>
            {targetArtifacts.length} {chinese ? '个工件' : 'artifacts'}
          </span>
        </summary>
        <div>
          <article>
            <i />
            <div>
              <strong>{chinese ? 'Rust 推理后端' : 'Rust inference backend'}</strong>
              <p>
                {rustModelLoaded
                  ? chinese
                    ? '已加载'
                    : 'loaded'
                  : chinese
                    ? '不可用'
                    : 'unavailable'}{' '}
                · {targetArtifacts.length}{' '}
                {chinese
                  ? '个精确标的工件已登记 · 实时就绪状态单独检查 · 自动执行已关闭'
                  : 'exact symbol artifacts registered · live readiness checked separately · automatic execution disabled'}
              </p>
            </div>
          </article>
          <article>
            <i />
            <div>
              <strong>
                {chinese ? '逐候选精确血缘' : 'Exact per-candidate lineage'}
              </strong>
              <p>
                {chinese
                  ? '每个候选都显示精确的模型与特征版本/哈希。'
                  : 'Exact model and feature version/hash are shown on each candidate.'}
              </p>
            </div>
          </article>
          <article>
            <i />
            <div>
              <strong>
                {chinese ? '质量与发布闸门' : 'Quality and publication gate'}
              </strong>
              <p>
                {candidateStatus.replaceAll('_', ' ')} ·{' '}
                {universeStatus.replaceAll('_', ' ')}
              </p>
            </div>
          </article>
        </div>
      </details>

      <details className={styles.evidence}>
        <summary>
          <span>{chinese ? '可复现性合同' : 'Reproducibility contract'}</span>
          <span>{envelope.request_id.slice(0, 8)}</span>
        </summary>
        <div>
          <article>
            <i />
            <div>
              <strong>{chinese ? '查询 DSL' : 'Query DSL'}</strong>
              <p>{JSON.stringify(envelope.query)}</p>
            </div>
          </article>
          <article>
            <i />
            <div>
              <strong>{chinese ? '血缘' : 'Lineage'}</strong>
              <p>
                {chinese ? '查询' : 'query'} {envelope.query_sha256.slice(0, 12)} ·{' '}
                {chinese ? '响应' : 'response'}{' '}
                {envelope.response_sha256?.slice(0, 12) ||
                  (chinese ? '不可用' : 'unavailable')}{' '}
                · {chinese ? '查询截止' : 'query cutoff'}{' '}
                {formatResearchTime(envelope.observation_cutoff, locale)} ·{' '}
                {chinese ? '响应生成' : 'response generated'}{' '}
                {formatResearchTime(envelope.generated_at, locale)}
              </p>
            </div>
          </article>
        </div>
      </details>

      {relevantCaveats.length > 0 ? (
        <details className={styles.evidence}>
          <summary>
            <span>{chinese ? '重要限制' : 'Material caveats'}</span>
            <span>{Math.min(relevantCaveats.length, 10)}</span>
          </summary>
          <div>
            {relevantCaveats.slice(0, 10).map((caveat, index) => (
              <article key={`${index}-${caveat}`}>
                <i />
                <div>
                  <strong>
                    {chinese ? `限制 ${index + 1}` : `Caveat ${index + 1}`}
                  </strong>
                  <p>{localizedCaveat(caveat, locale)}</p>
                </div>
              </article>
            ))}
          </div>
        </details>
      ) : null}

      <p className={styles.reportDisclaimer}>
        {chinese
          ? '仅限非个性化全市场统计研究。除非明确标注为已校准，否则分数不是概率；任何输出都不是订单、个性化建议或保证结果。'
          : disclaimer}
      </p>
    </div>
  );
}
