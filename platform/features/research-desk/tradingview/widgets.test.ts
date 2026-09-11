import { test } from 'node:test';
import assert from 'node:assert/strict';
import { boardConfig, chartConfig, presentationStatus, screenerConfig, tapeConfig, widgetDataUrl, widgetDocument, WIDGET_MESSAGE, WIDGET_SANDBOX } from './embed';
import { resolveTradingViewSymbol, selectTradingViewMarkets, tradingViewLink, TRADINGVIEW_MARKETS } from './symbols';

test('listed instruments use explicit provider listings and spot aliases preserve venue', () => {
  assert.equal(TRADINGVIEW_MARKETS.length, 10);
  assert.equal(resolveTradingViewSymbol('SPY')?.providerSymbol, 'AMEX:SPY');
  assert.equal(resolveTradingViewSymbol('DXYZ')?.providerSymbol, 'NYSE:DXYZ');
  assert.equal(resolveTradingViewSymbol(' nvda ')?.providerSymbol, 'NASDAQ:NVDA');
  for (const alias of ['BTC', 'BTCUSD', 'BTC-USD', 'COINBASE:BTCUSD']) assert.equal(resolveTradingViewSymbol(alias)?.providerSymbol, 'COINBASE:BTCUSD');
  assert.equal(resolveTradingViewSymbol('ETH-USD')?.providerSymbol, 'COINBASE:ETHUSD');
  assert.equal(resolveTradingViewSymbol('NASDAQ:DXYZ'), undefined);
  assert.equal(resolveTradingViewSymbol('MSFT')?.providerSymbol, 'NASDAQ:MSFT');
  assert.equal(resolveTradingViewSymbol('MU')?.providerSymbol, 'NASDAQ:MU');
  assert.equal(resolveTradingViewSymbol('ADBE')?.providerSymbol, 'NASDAQ:ADBE');
  assert.equal(resolveTradingViewSymbol('AAPL')?.providerSymbol, 'NASDAQ:AAPL');
  assert.equal(resolveTradingViewSymbol('WMT')?.providerSymbol, 'NASDAQ:WMT');
  assert.equal(resolveTradingViewSymbol('NYSE:WMT'), undefined);
  assert.equal(resolveTradingViewSymbol('IBM'), undefined);
  assert.match(tradingViewLink('IBM'), /symbols\/\?query=IBM$/);
  assert.equal(selectTradingViewMarkets(['BTC', 'BTC-USD', 'NVDA', 'UNKNOWN']).length, 2);
});

test('chart config requests candles, volume, explicit venue and timezone without symbol overrides', () => {
  const stock = chartConfig(resolveTradingViewSymbol('NVDA')!, true);
  assert.equal(stock.symbol, 'NASDAQ:NVDA');
  assert.equal(stock.style, '1');
  assert.equal(stock.hide_volume, false);
  assert.equal(stock.allow_symbol_change, false);
  assert.equal(stock.timezone, 'America/New_York');
  assert.equal(chartConfig(resolveTradingViewSymbol('ETH')!).timezone, 'Etc/UTC');
  const tape = tapeConfig(TRADINGVIEW_MARKETS);
  assert.equal('isStatic' in tape, false);
  assert.equal(tape.symbols.length, 10);
  assert.equal(boardConfig(TRADINGVIEW_MARKETS).symbolsGroups[0]!.symbols.length, 10);
});

test('official bootstrap lives in an opaque data origin with escaped markup and attribution', () => {
  const document = widgetDocument('chart', { symbol: '</script><script>unsafe()</script>' }, '<test>', 'https://www.tradingview.com/chart/?symbol=NASDAQ%3ANVDA', 'test-attempt');
  assert.match(document, /s3\.tradingview\.com\/external-embedding\/embed-widget-advanced-chart\.js/);
  assert.match(document, /Chart by TradingView/);
  assert.match(document, /&lt;test&gt;/);
  assert.doesNotMatch(document, /<script>unsafe/);
  assert.match(widgetDataUrl('chart', {}, 'test', 'https://www.tradingview.com/', 'a'), /^data:text\/html;charset=utf-8,/);
  assert.equal(WIDGET_SANDBOX, 'allow-scripts allow-same-origin allow-popups allow-popups-to-escape-sandbox');
  assert.doesNotMatch(document, /localStorage|sessionStorage|fetch\(/);
});

test('only the current opaque frame can report presentation state; quote messages are ignored', () => {
  const source = {} as Window;
  const event = (data: unknown, override: object = {}) => ({ source, origin: 'null', data, ...override }) as MessageEvent;
  const payload = { type: WIDGET_MESSAGE, attempt: 'current', state: 'embedded' };
  assert.equal(presentationStatus(event(payload), source, 'current'), 'embedded');
  assert.equal(presentationStatus(event(payload), source, 'old'), null);
  assert.equal(presentationStatus(event(payload, { source: {} }), source, 'current'), null);
  assert.equal(presentationStatus(event(payload, { origin: 'https://www.tradingview.com' }), source, 'current'), null);
  assert.equal(presentationStatus(event({ ...payload, state: 'realtime', price: 100 }), source, 'current'), null);
  assert.equal(presentationStatus(event({ ...payload, state: 'unavailable' }), source, 'current'), 'unavailable');
});

test('broad screeners use official market presets without a local symbol universe or data callbacks', () => {
  const stocks = screenerConfig('stocks');
  assert('market' in stocks);
  assert.equal(stocks.market, 'us');
  assert.equal(stocks.defaultScreen, 'most_capitalized');
  assert.equal(stocks.showToolbar, true);
  const forex = screenerConfig('forex');
  assert('market' in forex);
  assert.equal(forex.market, 'forex');
  assert.equal(forex.defaultScreen, 'top_gainers');
  const crypto = screenerConfig('crypto');
  assert('screener_type' in crypto);
  assert.equal(crypto.screener_type, 'crypto_mkt');
  assert.equal(crypto.displayCurrency, 'USD');
  for (const config of [stocks, forex, crypto]) {
    assert.equal(config.colorTheme, 'dark');
    assert.equal('symbols' in config, false);
    assert.equal('onSymbolChange' in config, false);
    const document = widgetDocument('screener', config, 'Market screener', 'https://www.tradingview.com/screener/', 'screener-attempt');
    assert.match(document, /embed-widget-screener\.js/);
    assert.match(document, /Markets by TradingView/);
    assert.doesNotMatch(document, /localStorage|sessionStorage|fetch\(/);
    assert.match(widgetDataUrl('screener', config, 'Market screener', 'https://www.tradingview.com/screener/', 's'), /^data:text\/html;charset=utf-8,/);
  }
});
