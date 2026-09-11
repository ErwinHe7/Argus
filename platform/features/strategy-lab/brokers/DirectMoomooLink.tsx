import React, { useCallback, useEffect, useRef, useState } from 'react';
import { ArrowUpRight, RefreshCw } from 'lucide-react';
import { useIdentity } from '../Identity';
import { signIn } from '../auth';
import { brokerLinkToken, directLinkFresh, MOOMOO_START, requestDirectLink, type DirectLinkStatus } from './direct-link';

export function DirectMoomooLink() {
  const { user } = useIdentity();
  return <DirectLinkView key={user?.id ?? 'guest'} />;
}
function DirectLinkView() {
  const identity = useIdentity();
  const [status, setStatus] = useState<DirectLinkStatus | null>(null);
  const [checking, setChecking] = useState(false), [busy, setBusy] = useState(false), [error, setError] = useState('');
  const [now, setNow] = useState(Date.now);
  const alive = useRef(true), generation = useRef(0);
  const pending = useRef<AbortController | null>(null), starting = useRef(false), disconnecting = useRef(false);
  const refresh = useCallback(async (path: '/status' | '/disconnect' = '/status') => {
    if (!identity.auth || !identity.user || disconnecting.current) return;
    if (path === '/disconnect') disconnecting.current = true;
    pending.current?.abort();
    const controller = new AbortController(); pending.current = controller;
    const revision = ++generation.current;
    const timeout = setTimeout(() => controller.abort(), 15_000);
    setChecking(true); setError('');
    try {
      const next = await requestDirectLink(identity.auth, identity.user.id, path, controller.signal);
      if (alive.current && revision === generation.current) { setStatus(next); setNow(Date.now()); }
      if (path === '/disconnect' && alive.current && revision === generation.current) {
        const confirmed = await requestDirectLink(identity.auth, identity.user.id, '/status', controller.signal);
        if (alive.current && revision === generation.current) { setStatus(confirmed); setNow(Date.now()); }
      }
    } catch (reason) {
      if (alive.current && revision === generation.current) setError(reason instanceof Error && reason.message.startsWith('Your sign-in') ? reason.message : 'The account link could not be verified. Try again.');
    } finally { clearTimeout(timeout); if (path === '/disconnect') disconnecting.current = false; if (alive.current && revision === generation.current) setChecking(false); }
  }, [identity.auth, identity.user?.id]);
  useEffect(() => {
    alive.current = true;
    return () => { alive.current = false; generation.current++; pending.current?.abort(); };
  }, []);
  useEffect(() => {
    if (!identity.loading) void refresh();
    const focus = () => { if (document.visibilityState === 'visible') void refresh(); };
    window.addEventListener('focus', focus);
    const timer = setInterval(() => setNow(Date.now()), 30_000);
    return () => { window.removeEventListener('focus', focus); clearInterval(timer); };
  }, [identity.loading, refresh]);
  const connected = Boolean(status && !error && directLinkFresh(status, now));
  const start = async () => {
    if (!identity.auth || starting.current || checking || identity.loading) return;
    starting.current = true; setBusy(true); setError('');
    try {
      if (!identity.user || error.startsWith('Your sign-in')) { await signIn(identity.auth, '/#/brokers'); return; }
      if (!status?.configured) return;
      const token = await brokerLinkToken(identity.auth, identity.user.id);
      if (!alive.current) return;
      // Top-level POST lets the first-party worker set its one-use OAuth cookie.
      // The Leo token is never put in a URL or browser storage by this feature.
      const form = document.createElement('form'); form.method = 'POST'; form.action = MOOMOO_START; form.hidden = true;
      const input = document.createElement('input'); input.type = 'hidden'; input.name = 'access_token'; input.value = token;
      form.append(input); document.body.append(form); form.submit(); form.remove();
    } catch (reason) {
      if (alive.current) setError(reason instanceof Error && reason.message.startsWith('Your sign-in') ? reason.message : 'The moomoo sign-in could not start. Try again.');
    } finally { starting.current = false; if (alive.current) setBusy(false); }
  };
  const returned = new URLSearchParams(location.hash.split('?')[1] ?? '').get('moomoo');
  const returnNote = returned === 'denied' ? 'Account access was not approved. You can try again when ready.' : returned === 'readonly_required' ? 'This connection accepts read-only access only. Review the permissions before trying again.' : returned === 'failed' ? 'The account link did not finish. Refresh its status, then try again.' : returned === 'linked' ? 'Returned from moomoo. The status below comes from a separate account check.' : '';
  const label = identity.loading ? 'Restoring your Leo account…' : !identity.user ? 'Sign in to link your account' : checking ? 'Checking moomoo access…' : connected ? 'Connected · read-only' : status?.configured === false ? 'Direct account linking is not available yet' : status?.state === 'reauthorization_required' ? 'Moomoo sign-in required again' : status?.state === 'disconnected' && !error ? 'No moomoo account linked' : 'Moomoo connection not verified';
  return <section className="broker-direct-link" aria-labelledby="moomoo-link-heading">
    <h3 id="moomoo-link-heading">Link your account to Leo</h3>
    <p>Review account access on moomoo’s website. This read-only link does not authorize trades or start the local runner.</p>
    <p>Choose read-only access and individual accounts when moomoo asks for permission. Trading permission is not supported.</p>
    {returnNote && <p className="broker-return-note">{returnNote}</p>}
    <div className="broker-link-state" role="status" aria-live="polite"><strong>{label}</strong>
      {status?.checkedAt && <p>{connected ? 'Verified' : 'Last account check'}: {new Date(status.checkedAt).toLocaleString()}</p>}
    </div>
    {!!status?.accounts.length && <ul className="broker-linked-accounts" aria-label={connected ? 'Verified moomoo accounts' : 'Previously reported moomoo accounts'}>{status.accounts.map((account, index) => <li key={`${account.label}-${index}`}>{account.accountType === 'cash' ? 'Cash' : 'Margin'} account <span>{account.label}</span>{!connected && <small>Current access not verified</small>}</li>)}</ul>}
    <div className="broker-direct-actions">
      {identity.auth && (!identity.user || status?.configured || error.startsWith('Your sign-in')) && !connected && <button className="gold-button" disabled={busy || checking || identity.loading} onClick={() => { void start(); }}>{busy ? 'Opening sign-in…' : error.startsWith('Your sign-in') ? 'Sign in to Leo again' : identity.user ? 'Link moomoo account' : 'Sign in to link moomoo'}<ArrowUpRight size={15}/></button>}
      {identity.user && <button className="border-button" disabled={checking || busy} onClick={() => { void refresh(); }}><RefreshCw size={14}/>{checking ? 'Checking…' : 'Refresh account link'}</button>}
      {identity.user && status?.configured && (connected || status?.state === 'reauthorization_required' || !!status?.accounts.length) && <button className="text-button" disabled={checking || busy} onClick={() => { void refresh('/disconnect'); }}>Disconnect from Leo</button>}
    </div>
    {error && <p className="broker-error" role="alert">{error}</p>}
    {status?.configured === false && <p className="broker-footnote">You can still follow the OpenD setup below for the local paper preview.</p>}
    {identity.user && status?.configured && <p className="broker-footnote">Disconnect removes Leo’s saved link. Manage any remaining provider permission in your moomoo account. It does not stop a separate OpenD paper strategy.</p>}
  </section>;
}
