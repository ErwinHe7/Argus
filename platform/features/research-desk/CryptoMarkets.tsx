import React, { useState } from 'react';
import { ArrowRight } from 'lucide-react';
import { TradingViewChart } from './tradingview';

export function CryptoMarkets() {
  const [symbol, setSymbol] = useState<'BTC'|'ETH'>('BTC');
  return <section className="tool-body crypto-markets">
    <div className="crypto-toolbar"><div className="symbol-buttons" role="group" aria-label="Crypto market"><button className={symbol==='BTC'?'selected':''} aria-pressed={symbol==='BTC'} onClick={()=>setSymbol('BTC')}>Bitcoin · BTC</button><button className={symbol==='ETH'?'selected':''} aria-pressed={symbol==='ETH'} onClick={()=>setSymbol('ETH')}>Ethereum · ETH</button></div><a className="gold-button" href={`#/positions?symbol=${symbol}-USD`}>Create a {symbol} plan<ArrowRight size={14}/></a></div>
    <TradingViewChart symbol={`${symbol}-USD`}/>
    <div className="crypto-guide"><div><h2>Start with price structure</h2><p>Use the chart to inspect the trend, mark a level and define what would change your view.</p></div><div><h2>Carry it into a plan</h2><p>Record the setup and invalidation conditions in Trade plans. Crypto charts do not supply the stock options model.</p></div></div>
  </section>;
}
