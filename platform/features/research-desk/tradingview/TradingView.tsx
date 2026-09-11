import React, { useEffect, useRef, useState } from 'react';
import { ArrowUpRight, RotateCcw } from 'lucide-react';
import { boardConfig, chartConfig, presentationStatus, screenerConfig, tapeConfig, widgetDataUrl, WIDGET_SANDBOX, type ScreenerMarket, type WidgetKind, type WidgetStatus } from './embed';
import { resolveTradingViewSymbol, selectTradingViewMarkets, tradingViewLink, TRADINGVIEW_MARKETS } from './symbols';
import './tradingview.css';

function HostedWidget({ kind, config, title, href, compact = false }: { kind: WidgetKind; config: object; title: string; href: string; compact?: boolean }) {
  const host = useRef<HTMLDivElement>(null);
  const [status, setStatus] = useState<WidgetStatus>('loading');
  const [retry, setRetry] = useState(0);
  const serializedConfig = JSON.stringify(config);

  useEffect(() => {
    const element = host.current;
    if (!element) return;
    const attempt = crypto.randomUUID();
    const frame = document.createElement('iframe');
    frame.title = title;
    frame.className = 'leo-tv-frame';
    frame.setAttribute('sandbox', WIDGET_SANDBOX);
    frame.referrerPolicy = 'no-referrer';
    frame.src = widgetDataUrl(kind, JSON.parse(serializedConfig), title, href, attempt);
    let current = true;
    setStatus('loading');
    const timer = window.setTimeout(() => { if (current) setStatus('unavailable'); }, 18000);
    const onMessage = (event: MessageEvent) => {
      const next = presentationStatus(event, frame.contentWindow, attempt);
      if (!current || !next) return;
      window.clearTimeout(timer);
      setStatus(next);
    };
    const onError = () => { if (current) { window.clearTimeout(timer); setStatus('unavailable'); } };
    window.addEventListener('message', onMessage);
    frame.addEventListener('error', onError);
    element.replaceChildren(frame);
    return () => {
      current = false;
      window.clearTimeout(timer);
      window.removeEventListener('message', onMessage);
      frame.removeEventListener('error', onError);
      frame.remove();
    };
  }, [kind, serializedConfig, title, href, retry]);

  return <div className={`leo-tv leo-tv--${kind}${compact ? ' leo-tv--compact' : ''}`} data-widget-state={status}>
    <div className="leo-tv-stage">
      <div ref={host} className="leo-tv-host" />
      {status === 'loading' && <div className="leo-tv-loading" role="status">Loading TradingView…</div>}
      {status === 'unavailable' && <div className="leo-tv-loading" role="status">TradingView is unavailable. Retry below or open TradingView.</div>}
    </div>
    <div className="leo-tv-caption">
      <span>{status === 'unavailable' ? 'TradingView did not finish loading.' : kind === 'chart' ? 'Prices may be delayed or unavailable.' : 'Data availability and delays are shown by TradingView.'}{(status === 'unavailable' || kind === 'chart') && <button type="button" aria-label={kind === 'chart' ? 'Retry chart' : 'Retry'} onClick={() => setRetry(value => value + 1)}><RotateCcw size={13} aria-hidden="true" />Retry</button>}</span>
      <a href={href} target="_blank" rel="noopener noreferrer">Open TradingView<ArrowUpRight size={13} aria-hidden="true" /></a>
    </div>
  </div>;
}

export function TradingViewChart({ symbol, compact = false, label }: { symbol: string; compact?: boolean; label?: string }) {
  const market = resolveTradingViewSymbol(symbol);
  if (!market) return <div className="leo-tv-unmapped" role="note"><p>A TradingView listing has not been confirmed for {symbol || 'this instrument'}.</p><a href={tradingViewLink(symbol)} target="_blank" rel="noopener noreferrer">Find the correct listing on TradingView<ArrowUpRight size={14} aria-hidden="true" /></a></div>;
  return <HostedWidget kind="chart" config={chartConfig(market, compact)} title={label || `${market.symbol} price chart from TradingView · ${market.venue}`} href={tradingViewLink(symbol)} compact={compact} />;
}

export function TradingViewTape() {
  const [reducedMotion, setReducedMotion] = useState(() => typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
  useEffect(() => {
    const media = window.matchMedia('(prefers-reduced-motion: reduce)');
    const onChange = () => setReducedMotion(media.matches);
    media.addEventListener('change', onChange);
    return () => media.removeEventListener('change', onChange);
  }, []);
  if (reducedMotion) return <nav className="leo-tv-static" aria-label="Tracked markets"><div>{TRADINGVIEW_MARKETS.map(market => <a key={market.symbol} href={`#/structure?symbol=${encodeURIComponent(market.symbol)}`}>{market.symbol}</a>)}</div><a href="#/board">View market quotes<ArrowUpRight size={13} aria-hidden="true"/></a></nav>;
  return <HostedWidget kind="tape" config={tapeConfig(TRADINGVIEW_MARKETS)} title="Astra’s market ticker from TradingView" href="https://www.tradingview.com/markets/" />;
}

export function TradingViewBoard({ symbols }: { symbols?: readonly string[] }) {
  const markets = symbols ? selectTradingViewMarkets(symbols) : TRADINGVIEW_MARKETS;
  const unknown = [...new Set(symbols?.filter(symbol => !resolveTradingViewSymbol(symbol)) || [])];
  return <div className="leo-tv-board">
    {markets.length > 0 && <HostedWidget kind="board" config={boardConfig(markets)} title="Astra’s market prices from TradingView" href="https://www.tradingview.com/markets/" />}
    {unknown.length > 0 && <p className="leo-tv-unmapped">Confirm listings on TradingView: {unknown.map(symbol => <a key={symbol} href={tradingViewLink(symbol)} target="_blank" rel="noopener noreferrer">{symbol}<ArrowUpRight size={12} aria-hidden="true" /></a>)}</p>}
    {markets.length === 0 && unknown.length === 0 && <p className="leo-tv-unmapped">Choose a market to display its TradingView quote.</p>}
  </div>;
}

export function TradingViewScreener({ market }: { market: ScreenerMarket }) {
  const presentation = {
    stocks: { title: 'U.S. stock screener from TradingView', href: 'https://www.tradingview.com/screener/' },
    crypto: { title: 'Cryptocurrency market comparison from TradingView', href: 'https://www.tradingview.com/markets/cryptocurrencies/prices-all/' },
    forex: { title: 'Forex screener from TradingView', href: 'https://www.tradingview.com/markets/currencies/' },
  }[market];
  return <HostedWidget kind="screener" config={screenerConfig(market)} title={presentation.title} href={presentation.href} />;
}
