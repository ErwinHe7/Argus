import React, { useRef, useState } from 'react';
import { ArrowUpRight } from 'lucide-react';
import { TradingViewScreener, type ScreenerMarket } from './tradingview';
import './ExploreMarkets.css';

const MARKETS: readonly { id: ScreenerMarket; title: string; description: string }[] = [
  { id: 'stocks', title: 'Stocks', description: 'U.S. listings, initially ordered by market capitalization. Use the table’s filters and column headings to compare them.' },
  { id: 'crypto', title: 'Crypto', description: 'Covered cryptocurrencies, initially ordered by market capitalization in USD. Select a column to change the comparison.' },
  { id: 'forex', title: 'Forex', description: 'Currency pairs, initially ordered by gain. Use the table’s filters and column headings to compare them.' },
];
const FULL_SCREENERS: Record<ScreenerMarket, string> = {
  stocks: 'https://www.tradingview.com/screener/',
  crypto: 'https://www.tradingview.com/crypto-coins-screener/',
  forex: 'https://www.tradingview.com/forex-screener/',
};

/** A broader market browser inside Astra’s established tool surface. */
export function ExploreMarkets() {
  const [market, setMarket] = useState<ScreenerMarket>('stocks');
  const tabs = useRef<(HTMLButtonElement | null)[]>([]);
  const onTabKeyDown = (event: React.KeyboardEvent<HTMLButtonElement>, index: number) => {
    let next: number;
    if (event.key === 'ArrowRight') next = (index + 1) % MARKETS.length;
    else if (event.key === 'ArrowLeft') next = (index + MARKETS.length - 1) % MARKETS.length;
    else if (event.key === 'Home') next = 0;
    else if (event.key === 'End') next = MARKETS.length - 1;
    else return;
    event.preventDefault();
    setMarket(MARKETS[next]!.id);
    tabs.current[next]?.focus();
  };

  return <section className="tool-body explore-markets" aria-label="Explore markets">
    <div className="explore-intro">
      <p>Search and compare more markets. Open a listing for its chart.</p>
      <a className="text-button explore-full" href={FULL_SCREENERS[market]} target="_blank" rel="noopener noreferrer">Open full screener<ArrowUpRight size={14} aria-hidden="true" /></a>
    </div>
    <div className="explore-tabs" role="tablist" aria-label="Market category">
      {MARKETS.map((item, index) => <button key={item.id} ref={element => { tabs.current[index] = element; }} id={`explore-tab-${item.id}`} role="tab" type="button" aria-selected={market === item.id} aria-controls={`explore-panel-${item.id}`} tabIndex={market === item.id ? 0 : -1} onClick={() => setMarket(item.id)} onKeyDown={event => onTabKeyDown(event, index)}>{item.title}</button>)}
    </div>
    <p className="explore-source">TradingView’s ordering and ratings are separate from Astra’s research screen. <a href="https://www.tradingview.com/widget-docs/markets/" target="_blank" rel="noopener noreferrer">Market coverage and delays<ArrowUpRight size={12} aria-hidden="true" /></a></p>
    {MARKETS.map(item => <div key={item.id} id={`explore-panel-${item.id}`} role="tabpanel" aria-labelledby={`explore-tab-${item.id}`} tabIndex={0} hidden={market !== item.id}>
      {market === item.id && <><p className="explore-description">{item.description}</p><TradingViewScreener market={item.id} /></>}
    </div>)}
  </section>;
}
