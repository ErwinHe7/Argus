'use client';

import { useState } from 'react';
import Link from 'next/link';
import { ArrowRight, ArrowUpRight, ChevronDown, LockKeyhole } from 'lucide-react';
import type { BrokerageProviderCatalog } from '../../../ritual-investing-api/src/domains/brokerage-providers/catalog';
import styles from './InvestingWorkspace.module.css';

const brokerSites = { ibkr: 'https://www.interactivebrokers.com/', moomoo: 'https://www.moomoo.com/us', webull: 'https://www.webull.com/' };
const descriptions = {
  ibkr: 'Connect an existing Interactive Brokers account through its approved third-party service.',
  moomoo: 'Authorize an existing moomoo account on the broker’s own secure sign-in page.',
  webull: 'Connect an existing Webull account through Webull Connect.',
};

export function BrokerConnections({ catalog, symbol }: { catalog: BrokerageProviderCatalog; symbol: string | null }) {
  const [selected, setSelected] = useState(catalog.providers[0].id);
  const provider = catalog.providers.find((item) => item.id === selected)!;
  return <>
    <section className={styles.titleRow}><div><h1>Your brokerage<span>.</span></h1><p>Your account stays with your broker. You choose and confirm every order.</p></div><Link href="/discover/stocks" className={styles.outlineLink}>Explore stocks <ArrowRight size={16} /></Link></section>
    {symbol && <div className={styles.contextStrip}><span>Researching <strong>{symbol}</strong></span><span>No order has been created.</span></div>}
    <div className={styles.brokerLayout}>
      <section className={styles.brokerList} aria-label="Choose a broker"><h2>Choose your broker</h2><div role="tablist" aria-label="Supported broker setup">
        {catalog.providers.map((item, index) => <button role="tab" id={`broker-tab-${item.id}`} aria-controls="broker-panel" aria-selected={selected === item.id} tabIndex={selected === item.id ? 0 : -1} key={item.id} onClick={() => setSelected(item.id)} onKeyDown={(event) => {
          const direction = ['ArrowRight', 'ArrowDown'].includes(event.key) ? 1 : ['ArrowLeft', 'ArrowUp'].includes(event.key) ? -1 : 0;
          const nextIndex = event.key === 'Home' ? 0 : event.key === 'End' ? catalog.providers.length - 1 : direction ? (index + direction + catalog.providers.length) % catalog.providers.length : null;
          if (nextIndex === null) return;
          event.preventDefault();
          const next = catalog.providers[nextIndex];
          setSelected(next.id);
          document.getElementById(`broker-tab-${next.id}`)?.focus();
        }}><span><strong>{item.name}</strong><small>Setup required</small></span><ArrowRight size={19} /></button>)}
      </div><p>U.S. launch · Existing brokerage accounts</p></section>
      <section className={styles.brokerDetail} role="tabpanel" id="broker-panel" aria-labelledby={`broker-tab-${provider.id}`} tabIndex={0}>
        <div className={styles.brokerHeading}><h2>{provider.name}</h2><span className={styles.setupState}>Not connected</span></div>
        <p className={styles.brokerDescription}>{descriptions[provider.id]}</p>
        <div className={styles.connectionNotice}><LockKeyhole size={20} /><div><h3>Connections are not available yet</h3><p>Leo’s broker integration must complete setup and verification before you can link an account or submit an order here.</p></div></div>
        <button className={styles.primaryLink} disabled>Connection setup in progress</button>
        <a className={styles.textLink} href={brokerSites[provider.id]} target="_blank" rel="noreferrer">Open {provider.name} website <ArrowUpRight size={15} /></a>
        <details className={styles.setupDetails}><summary>Integration setup details <ChevronDown size={16} /></summary><div><p>{provider.next_step}</p><ul>{provider.requirements.map((requirement) => <li key={requirement.id}>{requirement.label}</li>)}</ul><a href={provider.documentation_url} target="_blank" rel="noreferrer">Official integration documentation <ArrowUpRight size={14} /></a></div></details>
      </section>
    </div>
    <section className={styles.orderJourney}><h2>Review before you trade</h2><p>Once broker connections are available, the intended order flow is:</p><ol><li><strong>Choose your account</strong><span>Use the account and permissions returned by your broker.</span></li><li><strong>Enter your order</strong><span>You choose the security, side, quantity and price.</span></li><li><strong>Review and confirm</strong><span>Review the broker preview and confirm the exact order yourself.</span></li></ol></section>
    <p className={styles.boundaryCopy}>No connected accounts or live orders are available in this preview. Market research does not create orders, and automatic execution is disabled. A broker connection does not by itself grant market-data redistribution rights.</p>
  </>;
}
