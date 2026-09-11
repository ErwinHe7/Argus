'use client';

import Link from 'next/link';
import { useEffect, useRef, useState } from 'react';
import { ArrowRight, ChevronLeft, ChevronRight, Search } from 'lucide-react';
import type { DiscoveryEntry, DiscoveryResult } from '@/lib/investing/discovery';
import styles from './InvestingWorkspace.module.css';

export function StockDiscovery({ initial }: { initial: DiscoveryResult }) {
  const [data, setData] = useState(initial);
  const [query, setQuery] = useState('');
  const [exchange, setExchange] = useState('all');
  const [kind, setKind] = useState('all');
  const [coverage, setCoverage] = useState('all');
  const [offset, setOffset] = useState(0);
  const [revision, setRevision] = useState(0);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [selected, setSelected] = useState<DiscoveryEntry | null>(initial.entries.find((entry) => entry.research) ?? null);
  const first = useRef(true);

  useEffect(() => {
    if (first.current) { first.current = false; return; }
    const controller = new AbortController();
    setLoading(true);
    setError('');
    setSelected(null);
    const timer = window.setTimeout(async () => {
      try {
        const params = new URLSearchParams({ q: query, exchange, kind, coverage, offset: String(offset) });
        const response = await fetch(`/api/market-universe?${params}`, { signal: controller.signal, cache: 'no-store' });
        if (!response.ok) throw new Error('unavailable');
        const next = await response.json() as DiscoveryResult;
        if (!next.available || !Array.isArray(next.entries)) throw new Error('unavailable');
        if (!controller.signal.aborted) { setData(next); if (next.entries.length === 1) setSelected(next.entries[0]); }
      } catch {
        if (!controller.signal.aborted) setError('The security directory could not be loaded. Try again in a moment.');
      } finally {
        if (!controller.signal.aborted) setLoading(false);
      }
    }, 250);
    return () => { window.clearTimeout(timer); controller.abort(); };
  }, [query, exchange, kind, coverage, offset, revision]);

  const changeFilter = (setter: (value: string) => void, value: string) => { setter(value); setOffset(0); };
  const count = (value: number) => value.toLocaleString('en-US');
  const catalogDate = data.generated_at ? new Date(data.generated_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric', timeZone: 'America/New_York' }) : null;
  const sourceDates = data.source_dates ?? [];

  return <>
    <section className={styles.titleRow}>
      <div><h1>U.S. stocks<span>.</span></h1><p>Find a security, check its coverage, and open the available research.</p></div>
      <Link className={styles.outlineLink} href="/brokers">Broker connections <ArrowRight size={16} /></Link>
    </section>
    <div className={styles.directorySummary}>
      <span>{data.available ? `${count(data.directory_count)} listed securities` : 'Directory unavailable'}</span>
      <span>{count(data.research_count)} with a current Market Map</span>
      {catalogDate && <span>Directory updated {catalogDate}</span>}
    </div>
    <section className={styles.searchTools} aria-label="Filter securities">
      <label className={styles.searchLabel}><span>Symbol or company</span><div><Search size={18} aria-hidden="true" /><input type="search" value={query} maxLength={80} placeholder="Search AAPL, Nvidia, Berkshire…" onChange={(event) => changeFilter(setQuery, event.target.value)} /></div></label>
      <label><span>Exchange</span><select value={exchange} onChange={(event) => changeFilter(setExchange, event.target.value)}><option value="all">All U.S. listings</option><option value="NASDAQ">Nasdaq listings</option><option value="other">Other U.S. exchanges</option></select></label>
      <label><span>Security type</span><select value={kind} onChange={(event) => changeFilter(setKind, event.target.value)}><option value="all">All securities</option><option value="non_etf">Non-ETF securities</option><option value="etf">ETFs</option></select></label>
      <label><span>Research coverage</span><select value={coverage} onChange={(event) => changeFilter(setCoverage, event.target.value)}><option value="all">All coverage states</option><option value="ready">Market Map available</option></select></label>
    </section>
    {(error || !data.available) && <div className={styles.notice} role="alert"><p>{error || 'The official listing directory is not available yet. Research coverage will appear after the directory has been refreshed.'}</p><button onClick={() => setRevision((value) => value + 1)}>Try again</button></div>}
    <div className={styles.discoveryLayout}>
      <section aria-label="Security search results" className={styles.resultArea} aria-busy={loading}>
        <div className={styles.resultsHeading}><h2>Securities</h2><span role="status" aria-live="polite">{loading ? 'Searching…' : error ? 'Results unavailable' : `${count(data.total)} results`}</span></div>
        {!error && data.available && <>
          <div className={styles.tableScroll}><table className={styles.securitiesTable}>
            <thead><tr><th scope="col">Security</th><th scope="col">Exchange</th><th scope="col">Research</th><th scope="col"><span className={styles.srOnly}>Details</span></th></tr></thead>
            <tbody>{data.entries.map((entry) => <tr key={entry.symbol} data-selected={selected?.symbol === entry.symbol}>
              <th scope="row"><button disabled={loading} onClick={() => setSelected(entry)}><strong>{entry.symbol}</strong><span>{entry.name}</span></button></th>
              <td>{entry.exchange}<small>{entry.security_kind === 'etf' ? 'ETF' : 'Non-ETF'}</small></td>
              <td><span className={entry.research ? styles.available : styles.quiet}>{entry.research ? 'Available' : 'Data needed'}</span></td>
              <td><button disabled={loading} className={styles.rowAction} onClick={() => setSelected(entry)} aria-label={`View ${entry.symbol} coverage`}><ArrowRight size={17} /></button></td>
            </tr>)}</tbody>
          </table></div>
          {!loading && data.entries.length === 0 && <div className={styles.empty}><h3>No matching securities</h3><p>Try another name or symbol, or broaden the filters.</p></div>}
          <div className={styles.pagination}><span>{data.total ? `${count(data.offset + 1)}–${count(Math.min(data.offset + data.limit, data.total))} of ${count(data.total)}` : '0 results'}</span><div><button disabled={loading || offset === 0} onClick={() => setOffset(Math.max(0, offset - data.limit))} aria-label="Previous securities"><ChevronLeft size={18} /></button><button disabled={loading || data.offset + data.limit >= data.total} onClick={() => setOffset(offset + data.limit)} aria-label="Next securities"><ChevronRight size={18} /></button></div></div>
        </>}
      </section>
      <aside className={styles.securityDetail} aria-label="Selected security coverage" aria-live="polite">
        {selected && !loading && !error ? <>
          <div className={styles.detailSymbol}><h2>{selected.symbol}</h2><span>{selected.exchange}</span></div>
          <p className={styles.securityName}>{selected.name}</p>
          <dl className={styles.coverageList}>
            <div><dt>Listing</dt><dd>Verified directory entry</dd></div>
            <div><dt>Market Map</dt><dd className={selected.research ? styles.available : styles.quiet}>{selected.research ? 'Available' : 'Market data needed'}</dd></div>
            <div><dt>Predictive ranking</dt><dd>Not available</dd></div>
            <div><dt>Broker trading</dt><dd>Connection setup required</dd></div>
          </dl>
          {selected.research ? <><p className={styles.detailCopy}>Inspect observed prices, technical indicators and conditional scenarios from the same data snapshot.</p><Link className={styles.primaryLink} href={selected.research.href}>Open Market Map <ArrowRight size={17} /></Link><p className={styles.sourceNote}>Observed through {new Date(selected.research.observation_cutoff).toLocaleDateString('en-US', { timeZone: 'America/New_York' })}<br />{selected.research.source}</p></> : <p className={styles.detailCopy}>This security is listed in the directory. Leo does not yet have a current, authorized research snapshot for it. No model result is being substituted.</p>}
          <Link className={styles.textLink} href={`/brokers?symbol=${encodeURIComponent(selected.symbol)}`}>View broker setup <ArrowRight size={15} /></Link>
        </> : <div className={styles.emptyDetail}><Search size={26} /><h2>Inspect a security</h2><p>Select a result to see which research and broker features are available.</p></div>}
      </aside>
    </div>
    <section className={styles.directoryNote}><h2>Know what’s covered</h2><p>The directory covers Nasdaq and other U.S. exchange-listed securities, including ETFs. Non-ETF entries can include preferred shares, warrants and other instruments. Nasdaq listings are not the Nasdaq-100; S&P 500 constituent membership is not supplied by this directory.</p><p>A listing is not a buy recommendation. Broader screening needs licensed market data and validated, security-specific analysis. The current Market Map shows conditional simulations, not a predictive ranking.</p>{sourceDates.length > 0 && <p>Official listing files dated {sourceDates.join(' / ')}; imported {catalogDate}.</p>}<div>{data.source_urls.map((url, index) => <a key={url} href={url} target="_blank" rel="noreferrer">{index === 0 ? 'Nasdaq-listed directory' : 'Other-listed directory'} <ArrowRight size={13} /></a>)}</div></section>
  </>;
}
