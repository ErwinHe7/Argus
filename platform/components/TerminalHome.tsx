'use client';

import { CSSProperties, FormEvent, KeyboardEvent, ReactNode, useEffect, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import {
  Activity,
  ArrowUpRight,
  Bot,
  BrainCircuit,
  Check,
  CreditCard,
  Cpu,
  LockKeyhole,
  Newspaper,
  Play,
  Search,
  ShieldCheck,
  Sparkles,
  Terminal,
  Zap,
} from 'lucide-react';

type Tone = 'up' | 'down' | 'flat';
type ConsoleLine = {
  id: number;
  kind: 'input' | 'output' | 'error' | 'system';
  text: string;
};

type TerminalPlan = {
  key: 'starter' | 'pro' | 'premium' | 'enterprise';
  name: string;
  description: string;
  price: string;
  interval: string;
};

const terminalPlanFeatures: Record<TerminalPlan['key'], string[]> = {
  starter: ['Market terminal', 'Watchlists and intelligence', 'Individual access'],
  pro: ['Everything in Starter', 'Research-agent workspaces', 'Quant and backtest tools'],
  premium: ['Everything in Pro', 'Complete research terminal', 'Advanced model diagnostics'],
  enterprise: ['Everything in Premium', 'Team-scale access', 'Priority onboarding'],
};

const marketTape = [
  ['AAPL', '308.63', '+4.84%', 'up'],
  ['GOLD', '4,187.30', '+1.49%', 'up'],
  ['WTI', '68.78', '+0.13%', 'up'],
  ['EURUSD', '1.1440', '+0.03%', 'up'],
  ['S&P500', '7,483.24', '+0.00%', 'flat'],
  ['NASDAQ', '25,832.67', '-0.80%', 'down'],
  ['DOW', '52,900.07', '+1.14%', 'up'],
  ['VIX', '15.81', '-2.11%', 'down'],
] as const;

const watchlist = [
  ['AAPL', '308.63', '+14.25', '+4.84%', 'up'],
  ['MSFT', '390.49', '+6.21', '+1.62%', 'up'],
  ['NVDA', '194.83', '-2.75', '-1.39%', 'down'],
  ['TSLA', '393.45', '-31.85', '-7.49%', 'down'],
  ['AMZN', '242.67', '+0.97', '+0.40%', 'up'],
  ['SPY', '744.78', '-0.98', '-0.13%', 'down'],
  ['BTC-USD', '62,967.68', '-120.06', '-0.19%', 'down'],
  ['GC=F', '4,187.30', '+61.60', '+1.49%', 'up'],
] as const;

const cryptoRows = [
  ['BTC', '62,984.00', '+0.43%', '1.26T', 'up'],
  ['ETH', '1,773.35', '+0.87%', '214.0B', 'up'],
  ['USDT', '0.9991', '+0.00%', '184.1B', 'flat'],
  ['BNB', '573.36', '-0.05%', '77.3B', 'down'],
  ['XRP', '1.1500', '+1.20%', '71.6B', 'up'],
  ['SOL', '81.31', '-1.38%', '47.3B', 'down'],
  ['HYPE', '69.44', '-2.27%', '15.4B', 'down'],
  ['DOGE', '0.0772', '-0.31%', '12.0B', 'down'],
] as const;

const news = [
  ['Apple reportedly planning 5 new iPhones, including a foldable model', '05 JUL, 02:12'],
  ['Berkshire owns $41B of Alphabet stock: three possible reasons', '05 JUL, 01:48'],
  ['AAPL options volume leans bullish into the next hardware cycle', '04 JUL, 22:50'],
  ['AI infrastructure spend keeps megacap semis in focus', '04 JUL, 21:37'],
  ['Dividend-growth ETFs DGRO and VIG compare on income compounding', '04 JUL, 20:22'],
  ['Apple hardware refresh sends Wall Street a valuation warning', '04 JUL, 19:07'],
  ['Evercore maintains outperform rating on Apple stock', '04 JUL, 16:10'],
  ['Market week ahead: oil hints at a rotation in risk appetite', '04 JUL, 15:44'],
] as const;

const sideModules = [
  { href: '/market', icon: <Zap className="h-4 w-4" />, label: 'Strategy', meta: 'open market console', command: 'open market' },
  { href: '/quant', icon: <BrainCircuit className="h-4 w-4" />, label: 'Quant', meta: 'open factor stack', command: 'open quant' },
  { href: '/quant/backtest', icon: <Activity className="h-4 w-4" />, label: 'Backtest', meta: 'open walk-forward lab', command: 'open backtest' },
  { href: '/feed', icon: <Newspaper className="h-4 w-4" />, label: 'Feed', meta: 'open community feed', command: 'open feed' },
] as const;

const helpLines = [
  'COMMANDS',
  '  quote AAPL        show price, change, and range data',
  '  AAPL              shortcut for quote AAPL',
  '  sum AAPL          run local-style AI digest for a symbol',
  '  news AAPL         print latest headlines for the selected symbol',
  '  chart TSLA        load ticker into the chart panel',
  '  open market       navigate to the market console',
  '  open quant        navigate to quant workspace',
  '  clear             clear the terminal buffer',
  'KEYS',
  '  Enter executes, ArrowUp/ArrowDown walks command history.',
];

const initialConsole: ConsoleLine[] = [
  { id: 1, kind: 'system', text: 'AXIO7 TERMINAL ONLINE' },
  { id: 2, kind: 'output', text: 'Type help, quote AAPL, sum AAPL, news AAPL, open quant, or clear.' },
];

const symbolAliases: Record<string, string> = {
  BTC: 'BTC-USD',
  ETH: 'ETH',
  GOLD: 'GC=F',
};

export function TerminalHome({
  plans,
  checkoutPath,
}: {
  plans: TerminalPlan[];
  checkoutPath: string;
}) {
  const [selectedSymbol, setSelectedSymbol] = useState('AAPL');
  const [range, setRange] = useState('1D');
  const [command, setCommand] = useState('');
  const [history, setHistory] = useState<string[]>([]);
  const [historyIndex, setHistoryIndex] = useState<number | null>(null);
  const [lines, setLines] = useState<ConsoleLine[]>(initialConsole);
  const inputRef = useRef<HTMLInputElement>(null);
  const consoleRef = useRef<HTMLDivElement>(null);
  const nextId = useRef(initialConsole.length + 1);

  const symbols = useMemo<Set<string>>(() => {
    return new Set([...watchlist.map(([symbol]) => symbol), ...cryptoRows.map(([symbol]) => symbol)]);
  }, []);

  const selectedQuote = watchlist.find(([symbol]) => symbol === selectedSymbol)
    ?? cryptoRows.find(([symbol]) => symbol === selectedSymbol)
    ?? watchlist[0];
  const featuredPlan = plans.find((plan) => plan.key === 'pro') ?? plans[0];

  const appendLine = (kind: ConsoleLine['kind'], text: string) => {
    setLines((current) => [...current.slice(-80), { id: nextId.current++, kind, text }]);
  };

  const appendBlock = (kind: ConsoleLine['kind'], block: string[]) => {
    setLines((current) => [
      ...current.slice(-80),
      ...block.map((text) => ({ id: nextId.current++, kind, text })),
    ]);
  };

  const focusInput = () => inputRef.current?.focus();

  useEffect(() => {
    focusInput();
  }, []);

  useEffect(() => {
    consoleRef.current?.scrollTo({ top: consoleRef.current.scrollHeight });
  }, [lines]);

  const runCommand = (rawCommand: string) => {
    const value = rawCommand.trim();
    if (!value) return;

    appendLine('input', `> ${value}`);
    setHistory((current) => [value, ...current.filter((item) => item !== value)].slice(0, 30));
    setHistoryIndex(null);
    setCommand('');

    const parts = value.split(/\s+/);
    const op = parts[0]?.toUpperCase();
    const requested = normalizeSymbol(parts[1] ?? op);

    if (op === 'CLEAR' || op === 'CLS') {
      setLines([{ id: nextId.current++, kind: 'system', text: 'BUFFER CLEARED' }]);
      return;
    }

    if (op === 'HELP' || op === '?') {
      appendBlock('output', helpLines);
      return;
    }

    if (op === 'OPEN') {
      openModule(parts[1]);
      return;
    }

    if (op === 'GO') {
      runCommand(parts.slice(1).join(' ') || `sum ${selectedSymbol}`);
      return;
    }

    if (op === 'SUM' || op === 'DIGEST') {
      loadSymbol(requested || selectedSymbol, 'sum');
      return;
    }

    if (op === 'NEWS') {
      loadSymbol(requested || selectedSymbol, 'news');
      return;
    }

    if (op === 'QUOTE' || op === 'Q' || op === 'LOAD' || op === 'CHART') {
      loadSymbol(requested || selectedSymbol, op === 'CHART' ? 'chart' : 'quote');
      return;
    }

    if (value.endsWith('?')) {
      appendBlock('output', [
        `AI QUESTION RECEIVED: ${value}`,
        `LOCAL ANSWER: ${selectedSymbol} is the active context. Run "sum ${selectedSymbol}" for levels, tape read, and invalidation.`,
      ]);
      return;
    }

    if (symbols.has(normalizeSymbol(op))) {
      loadSymbol(normalizeSymbol(op), 'quote');
      return;
    }

    appendBlock('error', [
      `UNKNOWN COMMAND: ${value}`,
      'Type help for available commands.',
    ]);
  };

  const normalizeSymbol = (symbol?: string) => {
    if (!symbol) return '';
    const upper = symbol.toUpperCase();
    return symbolAliases[upper] ?? upper;
  };

  const loadSymbol = (symbol: string, mode: 'quote' | 'sum' | 'news' | 'chart') => {
    const normalized = normalizeSymbol(symbol);
    const row = watchlist.find(([item]) => item === normalized) ?? cryptoRows.find(([item]) => item === normalized);

    if (!row) {
      appendLine('error', `SYMBOL NOT FOUND: ${normalized}. Try AAPL, MSFT, NVDA, TSLA, BTC, ETH, SPY, GC=F.`);
      return;
    }

    setSelectedSymbol(row[0]);

    if (mode === 'chart') {
      appendLine('output', `CHART LOADED: ${row[0]} ${range}.`);
      return;
    }

    if (mode === 'news') {
      appendBlock('output', [
        `NEWS ${row[0]}`,
        ...news.slice(0, 5).map(([headline, time]) => `  ${time}  ${headline}`),
      ]);
      return;
    }

    if (mode === 'sum') {
      appendBlock('output', [
        `AI DIGEST ${row[0]}`,
        `  PRICE ${row[1]}  CHANGE ${row[2]}  ${row[3]}`,
        `  SIGNAL: momentum remains ${row[4] === 'down' ? 'fragile' : 'constructive'} while tape confirmation is required.`,
        `  LEVELS: watch ${row[1]} as live reference; invalidate on failed reclaim after volume expansion.`,
        '  SOURCE: public tape, news, options context, and audited local rules only.',
      ]);
      return;
    }

    appendBlock('output', [
      `QUOTE ${row[0]}`,
      `  LAST ${row[1]}`,
      `  CHANGE ${row[2]}`,
      `  %CHG ${row[3]}`,
      `  RUN: sum ${row[0]} | news ${row[0]} | chart ${row[0]}`,
    ]);
  };

  const openModule = (target?: string) => {
    const normalized = target?.toLowerCase();
    const routes: Record<string, string> = {
      market: '/market',
      strategy: '/market',
      quant: '/quant',
      backtest: '/quant/backtest',
      feed: '/feed',
      news: '/market',
    };
    const route = normalized ? routes[normalized] : undefined;
    if (!route) {
      appendLine('error', 'OPEN TARGET REQUIRED: market, quant, backtest, or feed.');
      return;
    }
    appendLine('system', `OPENING ${route}`);
    window.location.href = route;
  };

  const handleSubmit = (event: FormEvent) => {
    event.preventDefault();
    runCommand(command);
  };

  const handleKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    if (event.key === 'ArrowUp') {
      event.preventDefault();
      const nextIndex = historyIndex === null ? 0 : Math.min(historyIndex + 1, history.length - 1);
      setHistoryIndex(nextIndex);
      setCommand(history[nextIndex] ?? '');
    }

    if (event.key === 'ArrowDown') {
      event.preventDefault();
      if (historyIndex === null) return;
      const nextIndex = historyIndex - 1;
      setHistoryIndex(nextIndex < 0 ? null : nextIndex);
      setCommand(nextIndex < 0 ? '' : history[nextIndex] ?? '');
    }
  };

  return (
    <main className="terminal-home" onClick={focusInput}>
      <div className="terminal-shell">
        <header className="terminal-topline">
          <div className="terminal-brand">
            <span className="terminal-logo">AXIO7</span>
            <span className="terminal-pro">REAL TERMINAL</span>
            <span className="terminal-live">LIVE</span>
          </div>
          <div className="terminal-clock">
            <span>SUN 05 JUL, 02:32:20</span>
            <span className="terminal-ai-cold">INPUT: ACTIVE</span>
          </div>
        </header>

        <section className="terminal-subscribe-bar" aria-label="AXIO7 Pro subscription">
          <div className="terminal-subscribe-copy">
            <span className="terminal-subscribe-kicker">AXIO7 PRO / SUBSCRIBE</span>
            <strong>UNLOCK THE FULL TERMINAL</strong>
            <small>Research agents / quant workspaces / historical backtests</small>
          </div>
          <div className="terminal-subscribe-price">
            <span>{featuredPlan?.price ?? '$159.90'}</span>
            <small>/{(featuredPlan?.interval ?? 'month').toUpperCase()}</small>
          </div>
          <div className="terminal-subscribe-actions" onClick={(event) => event.stopPropagation()}>
            <form action={checkoutPath} method="post">
              <input type="hidden" name="plan" value={featuredPlan?.key ?? 'pro'} />
              <button type="submit" className="terminal-subscribe-button">
                <CreditCard className="h-4 w-4" />
                SUBSCRIBE / SECURE CHECKOUT
              </button>
            </form>
            <Link href="/pricing" className="terminal-subscribe-secondary">
              <LockKeyhole className="h-3.5 w-3.5" /> VIEW ALL PLANS
            </Link>
          </div>
        </section>

        <section className="terminal-command" aria-label="Terminal status bar">
          <Terminal className="h-4 w-4" />
          <span>AXIO7 SHELL</span>
          <span className="terminal-command-examples">type: help, AAPL, sum AAPL, news NVDA, open quant</span>
          <button type="button" className="terminal-go" title="Focus terminal prompt" onClick={focusInput}>
            <Play className="h-4 w-4" />
            FOCUS
          </button>
        </section>

        <section className="terminal-tape" aria-label="Market tape">
          {marketTape.map(([symbol, price, change, tone]) => (
            <button key={symbol} className="terminal-tape-item" type="button" onClick={() => runCommand(`quote ${symbol}`)}>
              <strong>{symbol}</strong>
              <span>{price}</span>
              <em className={`terminal-${tone}`}>{change}</em>
            </button>
          ))}
        </section>

        <div className="terminal-layout">
          <aside className="terminal-left">
            <Panel title="1) WATCHLIST" hotkey="F1">
              <MarketTable
                columns={['SYM', 'LAST', 'CHG', '%CHG']}
                rows={watchlist.map(([sym, last, chg, pct, tone]) => ({
                  key: sym,
                  cells: [sym, last, chg, pct],
                  tone,
                  selected: sym === selectedSymbol,
                }))}
                onRow={(symbol) => runCommand(`quote ${symbol}`)}
              />
            </Panel>

            <Panel title="2) CRYPTO" subtitle="TOP MCAP - 24H">
              <MarketTable
                columns={['SYM', 'PRICE', '24H%', 'MCAP']}
                rows={cryptoRows.map(([sym, price, pct, cap, tone]) => ({
                  key: sym,
                  cells: [sym, price, pct, cap],
                  tone,
                  selected: sym === selectedSymbol,
                }))}
                onRow={(symbol) => runCommand(`quote ${symbol}`)}
                compact
              />
            </Panel>
          </aside>

          <section className="terminal-center">
            <Panel title="3) TERMINAL" subtitle="REAL STDIN - COMMAND HISTORY - LOCAL BUFFER" className="terminal-main-panel">
              <div className="terminal-console" ref={consoleRef} aria-live="polite">
                {lines.map((line) => (
                  <pre key={line.id} className={`terminal-console-line ${line.kind}`}>
                    {line.text}
                  </pre>
                ))}
                <form className="terminal-console-prompt" onSubmit={handleSubmit}>
                  <Bot className="h-4 w-4" />
                  <label htmlFor="terminal-command-input">&gt;</label>
                  <input
                    ref={inputRef}
                    id="terminal-command-input"
                    className="terminal-console-input"
                    value={command}
                    onChange={(event) => setCommand(event.target.value)}
                    onKeyDown={handleKeyDown}
                    placeholder="help"
                    autoComplete="off"
                    spellCheck={false}
                  />
                </form>
              </div>
            </Panel>

            <Panel title={`4) ${selectedQuote[0]} ${selectedQuote[1]} USD`} className="terminal-chart-panel">
              <div className="terminal-chart-meta">
                <span>OPEN <b>298.20</b></span>
                <span>HI <b>309.42</b></span>
                <span>LO <b>293.68</b></span>
                <span>VOL <b>71.9M</b></span>
                <span>52W H <b>317.40</b></span>
                <span>52W L <b>201.50</b></span>
              </div>
              <div className="terminal-chart-tabs" aria-label="Chart range">
                {['1D', '5D', '1M', '6M', '1Y'].map((item) => (
                  <button
                    key={item}
                    className={item === range ? 'active' : ''}
                    type="button"
                    onClick={() => {
                      setRange(item);
                      appendLine('output', `RANGE SET ${selectedSymbol} ${item}`);
                    }}
                  >
                    {item}
                  </button>
                ))}
              </div>
              <div className="terminal-chart" aria-label={`${selectedSymbol} intraday chart`}>
                <div className="chart-grid-line l1" />
                <div className="chart-grid-line l2" />
                <div className="chart-grid-line l3" />
                <svg viewBox="0 0 900 390" role="img" aria-label="Green intraday line chart">
                  <defs>
                    <linearGradient id="chartFill" x1="0" x2="0" y1="0" y2="1">
                      <stop offset="0%" stopColor="#18d67a" stopOpacity="0.36" />
                      <stop offset="100%" stopColor="#18d67a" stopOpacity="0" />
                    </linearGradient>
                  </defs>
                  <path
                    className="chart-fill"
                    d="M0 365 L0 310 L14 225 L30 212 L43 140 L57 160 L72 118 L90 94 L108 70 L123 43 L140 25 L158 58 L174 33 L190 72 L208 26 L225 8 L242 22 L260 18 L278 40 L296 38 L314 74 L332 55 L350 46 L368 88 L386 41 L404 47 L422 31 L440 15 L458 42 L476 35 L494 24 L512 20 L530 49 L548 23 L566 29 L584 44 L602 36 L620 42 L638 63 L656 51 L674 47 L692 55 L710 43 L728 51 L746 38 L764 44 L782 29 L800 54 L818 36 L836 48 L854 31 L872 18 L890 10 L900 5 L900 365 Z"
                  />
                  <path
                    className="chart-line"
                    d="M0 310 L14 225 L30 212 L43 140 L57 160 L72 118 L90 94 L108 70 L123 43 L140 25 L158 58 L174 33 L190 72 L208 26 L225 8 L242 22 L260 18 L278 40 L296 38 L314 74 L332 55 L350 46 L368 88 L386 41 L404 47 L422 31 L440 15 L458 42 L476 35 L494 24 L512 20 L530 49 L548 23 L566 29 L584 44 L602 36 L620 42 L638 63 L656 51 L674 47 L692 55 L710 43 L728 51 L746 38 L764 44 L782 29 L800 54 L818 36 L836 48 L854 31 L872 18 L890 10 L900 5"
                  />
                </svg>
                <div className="chart-axis y top">{selectedQuote[1]}</div>
                <div className="chart-axis y mid">306.02</div>
                <div className="chart-axis y bot">298.20</div>
                <div className="chart-axis x left">15:30</div>
                <div className="chart-axis x right">22:00</div>
              </div>
            </Panel>

          </section>

          <aside className="terminal-right">
            <Panel title="5) NEWS" subtitle={selectedSymbol}>
              <div className="terminal-news">
                {news.map(([headline, time]) => (
                  <button key={headline} type="button" onClick={() => runCommand(`news ${selectedSymbol}`)}>
                    <h3>{headline}</h3>
                    <time>{time}</time>
                  </button>
                ))}
              </div>
            </Panel>

            <Panel title="OTHER MODULES" subtitle="commands">
              <div className="terminal-module-list">
                {sideModules.map((module) => (
                  <button key={module.href} type="button" onClick={() => runCommand(module.command)}>
                    {module.icon}
                    <span>
                      <strong>{module.label}</strong>
                      <em>{module.command}</em>
                    </span>
                    <ArrowUpRight className="h-4 w-4" />
                  </button>
                ))}
              </div>
            </Panel>
          </aside>
        </div>

        <footer className="terminal-footer">
          <div>
            <button type="button" className="active" onClick={() => runCommand('help')}>HELP</button>
            <button type="button" onClick={() => runCommand(`quote ${selectedSymbol}`)}>QUOTE</button>
            <button type="button" onClick={() => runCommand(`sum ${selectedSymbol}`)}>SUM</button>
            <button type="button" onClick={() => runCommand('clear')}>CLEAR</button>
          </div>
          <Link href="/market" onClick={(event) => event.stopPropagation()}>
            <Search className="h-4 w-4" />
            OPEN FULL MARKET CONSOLE
          </Link>
        </footer>
      </div>

      <section className="terminal-feature-strip" aria-label="AXIO7 terminal capabilities">
        <div>
          <Cpu className="h-5 w-5" />
          <span>Command input</span>
        </div>
        <div>
          <ShieldCheck className="h-5 w-5" />
          <span>Terminal buffer</span>
        </div>
        <div>
          <Sparkles className="h-5 w-5" />
          <span>Keyboard history</span>
        </div>
      </section>

      <section
        className="terminal-pricing-section"
        aria-labelledby="homepage-pricing-title"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="terminal-pricing-heading">
          <div>
            <span>AXIO7 SUBSCRIPTIONS</span>
            <h2 id="homepage-pricing-title">CHOOSE YOUR TERMINAL ACCESS</h2>
          </div>
          <p>Monthly digital access with automatic renewal. Cancel anytime from your billing portal.</p>
        </div>

        <div className="terminal-pricing-grid">
          {plans.map((plan) => (
            <article
              key={plan.key}
              className={`terminal-pricing-card ${plan.key === 'pro' ? 'featured' : ''}`}
            >
              {plan.key === 'pro' ? <span className="terminal-pricing-popular">MOST POPULAR</span> : null}
              <p>{plan.name}</p>
              <div className="terminal-pricing-amount">
                <strong>{plan.price}</strong>
                <span>/{plan.interval}</span>
              </div>
              <small>{plan.description}</small>
              <ul>
                {terminalPlanFeatures[plan.key].map((feature) => (
                  <li key={feature}>
                    <Check className="h-3.5 w-3.5" /> {feature}
                  </li>
                ))}
              </ul>
              <form action={checkoutPath} method="post">
                <input type="hidden" name="plan" value={plan.key} />
                <button type="submit">
                  <CreditCard className="h-4 w-4" /> SUBSCRIBE
                </button>
              </form>
            </article>
          ))}
        </div>

        <p className="terminal-pricing-secure">
          <LockKeyhole className="h-4 w-4" /> Card details are collected by the secure payment provider shown at checkout. AXIO7 does not store full card numbers.
        </p>
        <nav className="mt-4 flex flex-wrap justify-center gap-x-5 gap-y-2 text-xs text-white/55" aria-label="Subscription policies">
          <Link href="/terms" className="underline underline-offset-4 hover:text-white">Terms of Service</Link>
          <Link href="/privacy" className="underline underline-offset-4 hover:text-white">Privacy Policy</Link>
          <Link href="/refund-policy" className="underline underline-offset-4 hover:text-white">Refund Policy</Link>
          <Link href="/support" className="underline underline-offset-4 hover:text-white">Support</Link>
        </nav>
      </section>
    </main>
  );
}

function Panel({
  title,
  subtitle,
  hotkey,
  className = '',
  children,
}: {
  title: string;
  subtitle?: string;
  hotkey?: string;
  className?: string;
  children: ReactNode;
}) {
  return (
    <section className={`terminal-panel ${className}`}>
      <div className="terminal-panel-head">
        <h2>{title}</h2>
        {subtitle ? <span>{subtitle}</span> : null}
        {hotkey ? <kbd>{hotkey}</kbd> : null}
      </div>
      {children}
    </section>
  );
}

function MarketTable({
  columns,
  rows,
  compact = false,
  onRow,
}: {
  columns: string[];
  rows: Array<{ key: string; cells: readonly string[]; tone: string; selected?: boolean }>;
  compact?: boolean;
  onRow: (symbol: string) => void;
}) {
  return (
    <div className={`terminal-table ${compact ? 'compact' : ''}`} style={{ '--cols': columns.length } as CSSProperties}>
      <div className="terminal-table-head">
        {columns.map((column) => (
          <span key={column}>{column}</span>
        ))}
      </div>
      {rows.map((row) => (
        <button
          key={row.key}
          className={`terminal-table-row ${row.selected ? 'selected' : ''}`}
          type="button"
          onClick={() => onRow(row.key)}
        >
          {row.cells.map((cell, cellIndex) => (
            <span
              key={`${row.key}-${cellIndex}`}
              className={
                cellIndex === 2 || (!compact && cellIndex === 3)
                  ? `terminal-${row.tone}`
                  : compact && cellIndex === 3
                    ? 'terminal-cap'
                    : undefined
              }
            >
              {cell}
            </span>
          ))}
        </button>
      ))}
    </div>
  );
}
