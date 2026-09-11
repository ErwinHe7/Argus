import React, { useCallback, useEffect, useRef, useState } from 'react';
import { ArrowLeft, ArrowRight, ArrowUpRight, RefreshCw } from 'lucide-react';
import { useIdentity } from '../../strategy-lab/Identity';
import { signIn } from '../../strategy-lab/auth';
import { createCheckout, loadMembership, statusIsFresh, WHOP_ORDERS, type MembershipStatus } from './api';
import './membership.css';

function dateLabel(value: string): string {
  return new Date(value).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' });
}

export function Membership() {
  const identity = useIdentity();
  // An account switch remounts the entire private view, including pending work.
  return <MembershipView key={identity.user?.id ?? 'signed-out'} />;
}

function MembershipView() {
  const identity = useIdentity();
  const [snapshot, setSnapshot] = useState<{ value: MembershipStatus; receivedAt: number } | null>(null);
  const [checking, setChecking] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [now, setNow] = useState(Date.now);
  const latest = useRef(0);
  const alive = useRef(true);
  const pending = useRef<AbortController | null>(null);
  const checkoutPending = useRef<AbortController | null>(null);
  const refresh = useCallback(async () => {
    if (!identity.auth || !identity.user) return;
    pending.current?.abort();
    const request = new AbortController(); pending.current = request;
    const revision = ++latest.current;
    setChecking(true); setError('');
    try {
      const value = await loadMembership(identity.auth, identity.user.id, request.signal);
      if (alive.current && revision === latest.current) { const receivedAt = Date.now(); setSnapshot({ value, receivedAt }); setNow(receivedAt); }
    } catch (reason) {
      if (alive.current && revision === latest.current) setError(reason instanceof Error ? reason.message : 'Membership status is unavailable. Please try again.');
    } finally { if (alive.current && revision === latest.current) setChecking(false); }
  }, [identity.auth, identity.user?.id]);

  useEffect(() => {
    alive.current = true;
    return () => { alive.current = false; latest.current++; pending.current?.abort(); checkoutPending.current?.abort(); };
  }, []);
  useEffect(() => {
    if (!identity.loading) void refresh();
    const onFocus = () => { setNow(Date.now()); if (document.visibilityState === 'visible') void refresh(); };
    window.addEventListener('focus', onFocus);
    const timer = setInterval(() => setNow(Date.now()), 30_000);
    return () => { window.removeEventListener('focus', onFocus); clearInterval(timer); };
  }, [identity.loading, refresh]);

  const fresh = Boolean(snapshot && !error && statusIsFresh(snapshot.value, snapshot.receivedAt, now));
  const active = fresh && snapshot?.value.status === 'active';
  const canCheckout = fresh && ['none', 'inactive'].includes(snapshot?.value.status ?? '');
  const openCheckout = async () => {
    if (!identity.auth || !identity.user || busy || checkoutPending.current || !canCheckout) return;
    setBusy(true); setError('');
    const request = new AbortController(); checkoutPending.current = request;
    try {
      const url = await createCheckout(identity.auth, identity.user.id, request.signal);
      if (alive.current && !request.signal.aborted) window.location.assign(url);
    } catch (reason) {
      if (alive.current) setError(reason instanceof Error ? reason.message : 'Checkout could not be opened. Please try again.');
    } finally { checkoutPending.current = null; if (alive.current) setBusy(false); }
  };
  const googleSignIn = async () => {
    if (!identity.auth || busy) return;
    setBusy(true); setError('');
    try { await signIn(identity.auth, '/#/membership'); }
    catch (reason) { if (alive.current) setError(reason instanceof Error ? reason.message : 'Google sign-in could not start. Please try again.'); }
    finally { if (alive.current) setBusy(false); }
  };

  return <section className="leo-membership" aria-labelledby="membership-heading">
    <a className="text-button membership-back" href="#/welcome"><ArrowLeft size={15}/>Your account</a>
    <div className="membership-heading"><h1 id="membership-heading">Membership</h1><p>Your AXIO7 subscription, managed through Whop.</p></div>
    <div className="membership-layout">
      <section className="membership-plan" aria-labelledby="membership-plan-heading">
        <h2 id="membership-plan-heading">AXIO7 Live Trading</h2>
        <p className="membership-price">$99.99 <span>USD / month</span></p>
        <p>Read-only broker order visibility plus AXIO7 research.</p>
        <p className="membership-renewal">Renews automatically every month until canceled. Any applicable taxes and the total due appear at Whop checkout. Manage or cancel renewal in your Whop account.</p>
        <p className="membership-boundary">Payment does not connect a broker, place orders, or enable real-money trading. Broker connections require their own setup.</p>
        <a className="text-button" href="#/brokers">Review broker connections<ArrowRight size={15}/></a>
      </section>
      <section className="membership-account" aria-labelledby="membership-status-heading">
        <h2 id="membership-status-heading">{identity.user ? 'Your membership' : 'Sign in to continue'}</h2>
        {identity.loading ? <p role="status">Restoring your account…</p> : identity.user ? <>
          <p className="membership-email">{identity.user.email ?? 'Your Google account'}</p>
          <div className="membership-state" role="status" aria-live="polite">
            <strong>{checking ? 'Checking membership…' : active ? 'Active' : fresh && snapshot?.value.status === 'none' ? 'No linked Whop membership' : fresh && snapshot?.value.status === 'inactive' ? 'Membership inactive' : 'Membership status unavailable'}</strong>
            {!checking && active && <p>{snapshot?.value.cancelAtPeriodEnd ? 'Renewal is canceled.' : 'Your monthly subscription renews automatically.'}{snapshot?.value.renewalPeriodEnd && ` ${snapshot.value.cancelAtPeriodEnd ? 'Current access ends' : 'Current billing period ends'} ${dateLabel(snapshot.value.renewalPeriodEnd)}.`}</p>}
            {!checking && !fresh && <p>Refresh to confirm your current membership before starting checkout.</p>}
            {!checking && fresh && !active && <p>Already subscribed? Refresh your status after checkout. If a purchase is still missing, check the account used on Whop before subscribing again.</p>}
            {snapshot?.value.checkedAt && <p className="membership-checked">{fresh ? 'Checked' : `Last confirmation (${snapshot.value.status})`}: {dateLabel(snapshot.value.checkedAt)}</p>}
          </div>
          <div className="membership-actions">
            {canCheckout && <button className="gold-button" onClick={() => { void openCheckout(); }} disabled={busy || checking}>{busy ? 'Opening Whop…' : 'Continue to Whop checkout'}<ArrowUpRight size={16}/></button>}
            <button className="border-button" onClick={() => { void refresh(); }} disabled={checking || busy}><RefreshCw size={15}/>{checking ? 'Checking…' : 'Refresh membership'}</button>
          </div>
          {canCheckout && <p className="membership-fine">Review the subscription and confirm payment on Whop. Returning here alone does not confirm payment.</p>}
        </> : <>
          <p>Use Google to view your membership or start checkout. You can review the total on Whop before paying.</p>
          {identity.auth ? <button className="welcome-google" aria-label={busy ? 'Opening Google…' : 'Sign in with Google'} disabled={busy} onClick={() => { void googleSignIn(); }}><img src="/app/research-desk/google-signin.png" width="216" height="48" alt=""/></button> : <p>Google sign-in is temporarily unavailable. <button className="text-button" onClick={identity.retry}>Try again</button></p>}
        </>}
        {(error || identity.error) && <p className="membership-error" role="alert">{error || identity.error}</p>}
        <a className="text-button membership-manage" href={WHOP_ORDERS} target="_blank" rel="noreferrer">Manage membership on Whop<ArrowUpRight size={15}/></a>
        <p className="membership-fine">View receipts, update your payment method, or cancel renewal in Whop’s Orders page.</p>
      </section>
    </div>
    <div className="membership-footer"><p>Public research and your browser-saved plans remain available without this subscription.</p><a className="text-button" href="/pricing">Paddle plans &amp; payment<ArrowRight size={15}/></a><a className="text-button" href="#/home">Back to Picks<ArrowRight size={15}/></a></div>
  </section>;
}
