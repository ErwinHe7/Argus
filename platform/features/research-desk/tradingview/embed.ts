import type { TradingViewMarket } from './symbols';

export type WidgetKind = 'chart' | 'tape' | 'board' | 'screener';
export type ScreenerMarket = 'stocks' | 'crypto' | 'forex';
export type WidgetStatus = 'loading' | 'embedded' | 'unavailable';

const SCRIPTS: Record<WidgetKind, string> = {
  chart: 'https://s3.tradingview.com/external-embedding/embed-widget-advanced-chart.js',
  tape: 'https://s3.tradingview.com/external-embedding/embed-widget-ticker-tape.js',
  board: 'https://s3.tradingview.com/external-embedding/embed-widget-market-quotes.js',
  screener: 'https://s3.tradingview.com/external-embedding/embed-widget-screener.js',
};

export const WIDGET_SANDBOX = 'allow-scripts allow-same-origin allow-popups allow-popups-to-escape-sandbox';
export const WIDGET_MESSAGE = 'leo.tradingview.presentation.v1';

export function chartConfig(market: TradingViewMarket, compact = false) {
  return {
    autosize: true,
    symbol: market.providerSymbol,
    interval: 'D',
    timezone: market.kind === 'crypto' ? 'Etc/UTC' : 'America/New_York',
    theme: 'dark',
    style: '1',
    locale: 'en',
    backgroundColor: '#0f0f0f',
    gridColor: 'rgba(215, 215, 215, 0.08)',
    allow_symbol_change: false,
    hide_side_toolbar: compact,
    hide_top_toolbar: false,
    hide_volume: false,
    save_image: false,
    calendar: false,
    support_host: 'https://www.tradingview.com',
  };
}

export function tapeConfig(markets: readonly TradingViewMarket[]) {
  return {
    symbols: markets.map(market => ({ proName: market.providerSymbol, title: market.symbol })),
    showSymbolLogo: true,
    isTransparent: true,
    displayMode: 'adaptive',
    colorTheme: 'dark',
    locale: 'en',
    largeChartUrl: '',
  };
}

export function boardConfig(markets: readonly TradingViewMarket[]) {
  return {
    width: '100%',
    height: '100%',
    showSymbolLogo: true,
    isTransparent: true,
    colorTheme: 'dark',
    locale: 'en',
    symbolsGroups: [{ name: 'Astra’s markets', symbols: markets.map(market => ({ name: market.providerSymbol, displayName: market.symbol })) }],
  };
}

/** Official screener generators own their universe, filters, and ordering. */
export function screenerConfig(market: ScreenerMarket) {
  const common = { width: '100%', height: '100%', defaultColumn: 'overview', colorTheme: 'dark', isTransparent: false, locale: 'en' };
  if (market === 'crypto') return { ...common, screener_type: 'crypto_mkt', displayCurrency: 'USD' };
  return { ...common, market: market === 'stocks' ? 'us' : 'forex', defaultScreen: market === 'stocks' ? 'most_capitalized' : 'top_gainers', showToolbar: true };
}

const escapeHtml = (value: string) => value.replace(/[&<>"']/g, character => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[character]!);
const inlineJson = (value: unknown) => JSON.stringify(value).replace(/</g, '\\u003c').replace(/\u2028/g, '\\u2028').replace(/\u2029/g, '\\u2029');

/**
 * The official bootstrap runs only in an opaque data: origin, never Leo's origin.
 * Unlike srcdoc + allow-same-origin, this frame cannot access Leo's auth storage.
 * The only messages are presentation state; no prices or broker inputs cross out.
 */
export function widgetDocument(kind: WidgetKind, config: object, title: string, href: string, attempt: string): string {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="referrer" content="no-referrer"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${escapeHtml(title)}</title><style>
html,body{margin:0;width:100%;height:100%;background:#0f0f0f;color:#bfafca;font-family:Arial,sans-serif}*{box-sizing:border-box}.tradingview-widget-container{height:100%;width:100%}.tradingview-widget-container__widget{height:calc(100% - 32px);width:100%}.tradingview-widget-copyright{min-height:32px;display:flex;align-items:center;justify-content:center;padding:4px 8px;font-size:12px;line-height:20px;text-align:center}.tradingview-widget-copyright a{color:#a9c4ff;text-decoration:none}.tradingview-widget-copyright a:focus-visible{outline:2px solid #ecb667;outline-offset:2px}iframe{display:block}
</style></head><body><div class="tradingview-widget-container"><div class="tradingview-widget-container__widget"></div><div class="tradingview-widget-copyright"><a href="${escapeHtml(href)}" rel="noopener noreferrer" target="_blank"><span class="blue-text">${kind === 'chart' ? 'Chart' : 'Markets'} by TradingView</span></a></div><script>
(function(){
  var attempt=${inlineJson(attempt)}, title=${inlineJson(title)};
  function report(state){parent.postMessage({type:${inlineJson(WIDGET_MESSAGE)},attempt:attempt,state:state},'*');}
  var seen=new WeakSet();
  var observer=new MutationObserver(function(){document.querySelectorAll('iframe').forEach(function(frame){
    if(seen.has(frame))return;seen.add(frame);frame.title=title;
    frame.addEventListener('load',function(){report('embedded');},{once:true});
    frame.addEventListener('error',function(){report('unavailable');},{once:true});
  });});
  observer.observe(document.body,{childList:true,subtree:true});
  var script=document.createElement('script');script.src=${inlineJson(SCRIPTS[kind])};script.async=true;script.type='text/javascript';
  script.textContent=${inlineJson(JSON.stringify(config))};script.onerror=function(){report('unavailable');};
  document.querySelector('.tradingview-widget-container').appendChild(script);
})();
</script></div></body></html>`;
}

export function widgetDataUrl(kind: WidgetKind, config: object, title: string, href: string, attempt: string): string {
  return `data:text/html;charset=utf-8,${encodeURIComponent(widgetDocument(kind, config, title, href, attempt))}`;
}

export function presentationStatus(event: MessageEvent, source: Window | null, attempt: string): WidgetStatus | null {
  if (!source || event.source !== source || event.origin !== 'null') return null;
  const data = event.data;
  if (!data || typeof data !== 'object' || data.type !== WIDGET_MESSAGE || data.attempt !== attempt) return null;
  return data.state === 'embedded' || data.state === 'unavailable' ? data.state : null;
}
