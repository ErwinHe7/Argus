'use client';

import Link from 'next/link';
import { useCallback, useEffect, useRef, useState } from 'react';
import { ArrowRight, Check, ChevronRight, ExternalLink, RefreshCw, ShieldCheck } from 'lucide-react';
import type { OrderCommand, OrderIntent, OrderPreview, PersonalAccount, PersonalSnapshot, PersonalStatus } from '@/lib/personal-broker/types';
import base from './InvestingWorkspace.module.css';
import styles from './PersonalBroker.module.css';

async function broker<T>(path: string, body?: unknown): Promise<T> {
  const response = await fetch(`/api/personal-broker/${path}`, { method: body === undefined ? 'GET' : 'POST', cache: 'no-store', credentials: 'same-origin',
    ...(body === undefined ? {} : { headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }) });
  const data = await response.json();
  if (!response.ok) throw new Error(typeof data.message === 'string' ? data.message : 'The broker request could not be completed.');
  return data as T;
}
const accountLabel = (id: string) => `•••• ${id.slice(-4)}`;
const modeLabel = (mode: string) => mode === 'REAL' ? 'Real account' : 'Paper account';
const PENDING_KEY = 'leo.personal.pending-preview.v1';

export function PersonalBroker({ symbol }: { symbol: string | null }) {
  const [status, setStatus] = useState<PersonalStatus | null>(null);
  const [accounts, setAccounts] = useState<PersonalAccount[]>([]);
  const [accountId, setAccountId] = useState('');
  const [snapshot, setSnapshot] = useState<PersonalSnapshot | null>(null);
  const [busy, setBusy] = useState('');
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [password, setPassword] = useState('');
  const [intent, setIntent] = useState<OrderIntent>({ symbol: symbol && /^[A-Z][A-Z0-9.]{0,13}$/.test(symbol) ? symbol : '', side: 'BUY', quantity: '', limit_price: '' });
  const [preview, setPreview] = useState<OrderPreview | null>(null);
  const [reviewed, setReviewed] = useState(false);
  const [command, setCommand] = useState<OrderCommand | null>(null);
  const [pendingPreview, setPendingPreview] = useState<string | null>(null);
  const [discardAvailable, setDiscardAvailable] = useState(false);
  const [feedbackArea, setFeedbackArea] = useState<'account' | 'order'>('account');
  const errorRef = useRef<HTMLDivElement>(null);
  const noticeRef = useRef<HTMLDivElement>(null);
  const reviewHeadingRef = useRef<HTMLHeadingElement>(null);
  const commandHeadingRef = useRef<HTMLHeadingElement>(null);

  useEffect(() => { if (error) errorRef.current?.focus(); }, [error]);
  useEffect(() => { if (notice) noticeRef.current?.focus(); }, [notice]);
  useEffect(() => { if (preview && !pendingPreview) reviewHeadingRef.current?.focus(); }, [preview, pendingPreview]);
  useEffect(() => { if (pendingPreview) commandHeadingRef.current?.focus(); }, [pendingPreview, command?.status]);

  const refresh = useCallback(async () => {
    const next = await broker<PersonalStatus>('status'); setStatus(next);
    if (next.connected) setSnapshot(await broker<PersonalSnapshot>('snapshot'));
    else setSnapshot(null);
  }, []);
  const run = async (name: string, action: () => Promise<void>) => {
    if (busy) return; setBusy(name); setError(''); setNotice('');
    setFeedbackArea(['preview', 'confirm', 'command', 'discard'].includes(name) ? 'order' : 'account');
    try { await action(); } catch (cause) { setError(cause instanceof Error ? cause.message : 'The request could not be completed.'); }
    finally { setBusy(''); }
  };
  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const saved = localStorage.getItem(PENDING_KEY);
        if (saved && /^[a-z0-9-]{20,64}$/.test(saved) && !cancelled) setPendingPreview(saved);
        await broker('session', {}); const next = await broker<PersonalStatus>('status');
        if (!cancelled) setStatus(next);
        if (saved && /^[a-z0-9-]{20,64}$/.test(saved)) {
          const recovery = await broker<{command:OrderCommand|null}>(`previews/${saved}/command`);
          if (!cancelled) { setCommand(recovery.command); setDiscardAvailable(recovery.command === null); }
        }
      }
      catch (cause) { if (!cancelled) setError(cause instanceof Error ? cause.message : 'The local bridge is unavailable.'); }
    })();
    return () => { cancelled = true; };
  }, []);

  function changeIntent(field: keyof OrderIntent, value: string) {
    setIntent(current => ({ ...current, [field]: value })); setPreview(null); setReviewed(false); setCommand(null);
  }
  const canReview = !!status?.connected && (status.account?.mode !== 'REAL' || status.live_enabled) && !pendingPreview;
  const selectedAccount = accounts.find(account => `${account.id}:${account.mode}` === accountId);
  function clearOrder() { localStorage.removeItem(PENDING_KEY); setPendingPreview(null); setPreview(null); setCommand(null); setReviewed(false); setDiscardAvailable(false); }

  return <>
    <section className={base.titleRow}>
      <div><h1>Your trading desk<span>.</span></h1><p>Connect your own account. Review the market, then choose every trade yourself.</p></div>
      <Link href="/discover/stocks" className={base.outlineLink}>Explore stocks <ArrowRight size={16} /></Link>
    </section>
    <div className={styles.connectionBar}><span className={styles.state}><i data-ready={status?.connected} />{status?.connected ? `Connected · ${modeLabel(status.account!.mode)}` : 'Account not connected'}</span><span>Runs on this computer</span><button disabled={!!busy} onClick={() => void run('refresh', async () => { await broker('session', {}); await refresh(); })}><RefreshCw size={14} />{busy === 'refresh' ? 'Checking…' : 'Refresh'}</button></div>

    <div className={styles.deskLayout}>
      <div className={styles.accountArea}>
        {feedbackArea === 'account' && error && <div ref={errorRef} tabIndex={-1} className={styles.error} role="alert">{error}</div>}
        {feedbackArea === 'account' && notice && <div ref={noticeRef} tabIndex={-1} className={styles.notice} role="status">{notice}</div>}
        {!status?.connected ? <section className={styles.connectSection}>
          <h2>Connect moomoo</h2><p>Use moomoo OpenD to securely connect the account you already own.</p>
          <button className={styles.secondaryButton} disabled={!!busy} onClick={() => void run('accounts', async () => { await broker('session', {}); const data = await broker<{ accounts: PersonalAccount[] }>('accounts'); const eligible = data.accounts.filter(account => account.status === 'ACTIVE' && account.markets.includes('US')); setAccounts(eligible); setAccountId(''); setStatus(await broker<PersonalStatus>('status')); if (!eligible.length) setNotice('No eligible active U.S. account was returned. Check your OpenD login and account permissions.'); })}>{busy === 'accounts' ? 'Finding accounts…' : 'Find my accounts'}<ChevronRight size={16} /></button>
          <ol className={styles.steps}>
            <li><span className={status?.sdk_available ? styles.done : ''}>{status?.sdk_available ? <Check size={15} /> : '1'}</span><div><strong>Local bridge</strong><p>{status?.sdk_available ? 'Official moomoo SDK is ready.' : 'Start Leo with the personal trading launcher.'}</p></div></li>
            <li><span className={status?.opend_reachable ? styles.done : ''}>{status?.opend_reachable ? <Check size={15} /> : '2'}</span><div><strong>Sign in to OpenD</strong><p>{status?.opend_reachable ? 'OpenD is running. Complete login and verification in its window.' : 'Install OpenD, then sign in using your own moomoo account. Keep OpenD running.'}</p><a href="https://www.moomoo.com/download/OpenAPI" target="_blank" rel="noreferrer">Official OpenD download <ExternalLink size={13} /></a></div></li>
            <li><span>3</span><div><strong>Choose your account</strong><p>Leo reads the accounts and U.S. trading permissions returned by moomoo.</p></div></li>
          </ol>
          {accounts.length > 0 && <div className={styles.chooseAccount}><label>Brokerage account<select value={accountId} onChange={event => setAccountId(event.target.value)}><option value="">Choose an account</option>{accounts.map(account => <option key={`${account.id}:${account.mode}`} value={`${account.id}:${account.mode}`}>{modeLabel(account.mode)} · {accountLabel(account.id)}</option>)}</select></label><button className={styles.primaryButton} disabled={!!busy || !selectedAccount} onClick={() => void run('connect', async () => { if (!selectedAccount) return; await broker('connect', { account_id: selectedAccount.id, mode: selectedAccount.mode }); setPreview(null); setReviewed(false); await refresh(); })}>{busy === 'connect' ? 'Connecting…' : 'Connect selected account'}</button></div>}
        </section> : <>
          <section className={styles.accountSection}><div className={styles.sectionHeading}><h2>Account overview</h2><button disabled={!!busy} onClick={() => void run('disconnect', async () => { await broker('disconnect', {}); setSnapshot(null); setPreview(null); setPassword(''); setAccounts([]); await refresh(); })}>Disconnect</button></div>
            <p className={styles.accountIdentity}>{modeLabel(status.account!.mode)} · {accountLabel(status.account!.id)} · USD</p>
            {snapshot ? <><dl className={styles.balances}><div><dt>Cash</dt><dd>{snapshot.account.cash ?? 'Unavailable'}</dd></div><div><dt>Buying power</dt><dd>{snapshot.account.buying_power ?? 'Unavailable'}</dd></div><div><dt>Account equity</dt><dd>{snapshot.account.equity ?? 'Unavailable'}</dd></div></dl><p className={styles.timestamp}>Broker snapshot · {new Date(snapshot.as_of).toLocaleString()}</p></> : <p className={styles.supporting}>Use Refresh to load the latest account snapshot.</p>}
            {status.account?.mode === 'REAL' && !status.live_enabled && <p className={styles.readOnly}>Real account reads are available. To enable manual real orders, restart the local launcher with <code>-AllowLiveTrading</code>.</p>}
            {status.account?.mode === 'REAL' && status.live_enabled && <details className={styles.unlock}><summary>Unlock trading if moomoo requests it</summary><p>You can unlock in OpenD. Alternatively, send your trading password directly through the local bridge to moomoo. Leo does not save it.</p><form onSubmit={event => { event.preventDefault(); const currentPassword = password; setPassword(''); void run('unlock', async () => { await broker('unlock', { password: currentPassword }); setNotice('Trading unlocked for the current broker session.'); }); }}><label>Trading password<input type="password" autoComplete="off" value={password} onChange={event => setPassword(event.target.value)} maxLength={128} /></label><button className={styles.secondaryButton} disabled={!!busy || !password}>Unlock session</button></form></details>}
          </section>
          <section className={styles.holdings}><div className={styles.sectionHeading}><h2>Positions</h2><span>{snapshot?.positions.length ?? '—'}</span></div><div className={styles.tableWrap}><table><thead><tr><th>Security</th><th>Shares</th><th>Available to sell</th><th>Market value</th></tr></thead><tbody>{snapshot?.positions.map(position => <tr key={position.symbol}><th>{position.symbol}</th><td>{position.quantity}</td><td>{position.available_quantity ?? 'Unavailable'}</td><td>{position.market_value ?? 'Unavailable'}</td></tr>)}</tbody></table></div>{snapshot?.positions.length === 0 && <p className={styles.empty}>No positions returned for this account.</p>}</section>
          <section className={styles.holdings}><div className={styles.sectionHeading}><h2>Broker orders</h2><button disabled={!!busy} onClick={() => void run('refresh', refresh)}>Refresh orders</button></div><div className={styles.tableWrap}><table><thead><tr><th>Security</th><th>Side</th><th>Shares / filled</th><th>Status</th></tr></thead><tbody>{snapshot?.orders.map(order => <tr key={order.id}><th>{order.symbol}</th><td>{order.side}</td><td>{order.quantity} / {order.filled_quantity}</td><td>{order.status}</td></tr>)}</tbody></table></div>{snapshot?.orders.length === 0 && <p className={styles.empty}>No current orders returned by moomoo.</p>}</section>
        </>}
        <div className={styles.researchLink}><ShieldCheck size={21} /><div><h3>Your research, your decision</h3><p>Market Map shows price history, indicators and conditional scenarios. Opening research does not create an order.</p><Link href={`/discover/market-map${intent.symbol ? `?symbol=${encodeURIComponent(intent.symbol)}` : ''}`}>Open Market Map <ArrowRight size={14} /></Link></div></div>
      </div>

      <aside className={styles.ticket} aria-label="Manual order ticket"><div className={styles.sectionHeading}><h2>Order ticket</h2><span>{status?.account ? modeLabel(status.account.mode) : 'Connect first'}</span></div>
        <p className={styles.ticketIntro}>U.S. equities · Limit order · Day · Regular hours</p>
        {feedbackArea === 'order' && error && <div ref={errorRef} tabIndex={-1} className={styles.error} role="alert">{error}</div>}
        {feedbackArea === 'order' && notice && <div ref={noticeRef} tabIndex={-1} className={styles.notice} role="status">{notice}</div>}
        <form onSubmit={event => { event.preventDefault(); void run('preview', async () => { setPreview(null); setReviewed(false); setCommand(null); const next = await broker<OrderPreview>('previews', intent); setPreview(next); }); }}>
          <fieldset disabled={!!busy || !!pendingPreview}><label>Symbol<input aria-label="Order symbol" placeholder="AAPL" value={intent.symbol} onChange={event => changeIntent('symbol', event.target.value.toUpperCase())} maxLength={14} required pattern="[A-Z][A-Z0-9.]*" /></label><label>Action<select value={intent.side} onChange={event => changeIntent('side', event.target.value)}><option value="BUY">Buy</option><option value="SELL">Sell shares you own</option></select></label><div className={styles.fieldPair}><label>Whole shares<input inputMode="numeric" placeholder="Quantity" value={intent.quantity} onChange={event => changeIntent('quantity', event.target.value)} required pattern="[1-9][0-9]*" /></label><label>Limit price (USD)<input inputMode="decimal" placeholder="Your price" value={intent.limit_price} onChange={event => changeIntent('limit_price', event.target.value)} required pattern="[0-9]+([.][0-9]{1,2})?" /></label></div></fieldset>
          <button className={styles.primaryButton} disabled={!!busy || !canReview}>{busy === 'preview' ? 'Preparing review…' : 'Review order'}<ArrowRight size={16} /></button>
          {!status?.connected && <p className={styles.supporting}>Connect an account to review an order.</p>}
          {status?.connected && status.account?.mode === 'REAL' && !status.live_enabled && <p className={styles.readOnly}>Real orders are disabled in this session. Restart the personal launcher with <code>-AllowLiveTrading</code> to enable manual real orders.</p>}
        </form>
        {preview && !pendingPreview && <section className={styles.review} aria-label="Order review"><h3 ref={reviewHeadingRef} tabIndex={-1}>Review your {preview.mode === 'REAL' ? 'real' : 'paper'} order</h3><dl><div><dt>Account</dt><dd>{accountLabel(preview.account_id)}</dd></div><div><dt>Order</dt><dd>{preview.intent.side} {preview.intent.quantity} {preview.intent.symbol}</dd></div><div><dt>Limit price</dt><dd>${preview.intent.limit_price}</dd></div><div><dt>Limit notional</dt><dd>${preview.estimated_notional}</dd></div><div><dt>Local order cap</dt><dd>${preview.max_notional}</dd></div></dl><p>Fees are excluded. A limit order may remain unfilled. This review expires at {new Date(preview.expires_at).toLocaleTimeString()}.</p>{preview.warnings.length > 0 && <ul>{preview.warnings.map(warning => <li key={warning}>{warning}</li>)}</ul>}<label className={styles.confirmCheck}><input type="checkbox" checked={reviewed} onChange={event => setReviewed(event.target.checked)} />I reviewed this exact {preview.mode === 'REAL' ? 'real-money' : 'paper'} order.</label><button className={styles.primaryButton} disabled={!reviewed || !!busy} onClick={() => void run('confirm', async () => { localStorage.setItem(PENDING_KEY, preview.id); setDiscardAvailable(false); setPendingPreview(preview.id); const result = await broker<OrderCommand>('confirm', { preview_id: preview.id, confirmed: true }); setCommand(result); setReviewed(false); })}>{busy === 'confirm' ? 'Submitting once…' : preview.mode === 'REAL' ? 'Confirm real order' : 'Confirm paper order'}</button></section>}
        {pendingPreview && <section className={styles.command} aria-live="polite"><h3 ref={commandHeadingRef} tabIndex={-1}>{command?.status === 'submitted' ? 'Submitted to moomoo' : command?.status === 'rejected' ? 'Order rejected' : 'Submission needs verification'}</h3><p>{command?.message ?? 'The submission result has not been confirmed. Check its status before creating another order.'}</p>{command?.broker_order_id && <p>Broker order: {command.broker_order_id}</p>}<p>Submission is not a fill. Check broker orders for execution status.</p><button className={styles.secondaryButton} disabled={!!busy} onClick={() => void run('command', async () => { const result = await broker<{ command: OrderCommand | null }>(`previews/${pendingPreview}/command`); setDiscardAvailable(result.command === null); if (result.command) setCommand(result.command); else setNotice('No submission record was found for this review. Check your broker orders before taking further action.'); if (status?.connected) setSnapshot(await broker<PersonalSnapshot>('snapshot')); })}>Check order status <RefreshCw size={14} /></button>{discardAvailable && <button className={styles.textButton} disabled={!!busy} onClick={() => void run('discard', async () => { const result = await broker<{discarded:boolean;command:OrderCommand|null}>(`previews/${pendingPreview}/discard`, {}); if (result.discarded) { clearOrder(); setNotice('The unused review was discarded. You can create a fresh review.'); } else { setCommand(result.command); setDiscardAvailable(false); } })}>Discard unused review</button>}{command && command.status !== 'unknown' && <button className={styles.textButton} disabled={!!busy} onClick={clearOrder}>Start a new order</button>}</section>}
      </aside>
    </div>
    <p className={styles.bottomNote}>Personal account connection through moomoo OpenD. IBKR and Webull can be added through their personal API routes next. No automatic execution.</p>
  </>;
}
