import React, { useEffect, useState } from 'react';
import { ArrowRight, Download, ExternalLink, Monitor, RefreshCw } from 'lucide-react';
import { useWorkspace } from '../useWorkspace';
import { signIn } from '../auth';
import { displayTime } from '../catalog';
import { BROKER_TOOLS_RELEASE } from './release';
import './brokers.css';

// Extend the existing Leo workspace: one setup path, explicit reported state, no browser order controls.
export function Brokers() {
  const state = useWorkspace();
  const [busy, setBusy] = useState(false);
  const [now, setNow] = useState(Date.now());
  useEffect(() => { const timer = setInterval(() => setNow(Date.now()), 1_000); return () => clearInterval(timer); }, []);
  const devices = state.snapshot?.devices.filter(device => !device.revokedAt) ?? [];
  const fresh = (time: string | null) => time !== null && Date.parse(time) <= now && now - Date.parse(time) < 15_000;
  const reporting = !state.stale && devices.some(device => fresh(device.lastSeenAt));
  const status = state.loading ? 'Checking your account…' : !state.user ? 'No broker connected' : !state.snapshot ? 'Broker connection not verified' : reporting ? 'Computer reporting' : devices.length ? 'Computer offline or status expired' : 'No computer paired';

  async function login() {
    if (!state.auth || busy) return;
    setBusy(true); state.setError('');
    try { await signIn(state.auth); }
    catch (error) { state.setError(error instanceof Error ? error.message : 'Google sign-in could not start. Try again.'); }
    finally { setBusy(false); }
  }

  return <div className="broker-workspace">
    <header className="broker-heading"><h1>Connect your broker</h1><p>Choose your broker, connect your computer, then choose the rules it can follow.</p></header>
    <div className="broker-identity">
      <div role="status" aria-atomic="true"><strong>{status}</strong><p>{state.user ? `${state.user.email ?? 'Signed in'} · ${state.snapshot ? state.stale ? 'last verified Leo account records' : 'Leo identity verified' : 'verifying Leo membership'}` : 'Sign in with Google to pair a computer. Broker login stays in the broker’s own app.'}</p></div>
      {!state.user && state.auth && <button className="border-button" onClick={() => { void login(); }} disabled={busy || state.loading}>{busy ? 'Opening Google…' : 'Sign in with Google'}<ArrowRight size={15}/></button>}
      {state.user && state.api && <button className="text-button" onClick={() => { void state.refresh(); }}><RefreshCw size={15}/>Refresh status</button>}
    </div>
    {state.error && <p className="broker-error" role="alert">{state.error} {state.stale ? 'Last reported account details remain below; current connectivity is unverified.' : ''}</p>}

    <div className="broker-layout">
      <div className="broker-main">
        <section className="broker-option" aria-labelledby="moomoo-title">
          <div className="broker-option-heading"><h2 id="moomoo-title">moomoo / Futu</h2><span>Paper trading</span></div>
          <p>Run mean reversion or momentum rules through your local connector. This release supports U.S. stocks and ETFs in a paper account.</p>
          <ol className="broker-steps">
            <li><div><h3>Install the tools on your computer</h3><p>OpenD connects to moomoo. Leo’s connector checks your strategy and reports back to this workspace.</p><div className="broker-links"><a href="https://www.moomoo.com/download/OpenAPI" target="_blank" rel="noopener noreferrer">Download OpenD<ExternalLink size={13}/></a><ToolsDownload/></div></div></li>
            <li><div><h3>Sign in to OpenD</h3><p>Use the broker’s app to log in and complete its verification. Keep OpenD running and select a U.S. paper account.</p></div></li>
            <li><div><h3>Pair your computer with Leo</h3><p>Open Connect computer, create a pairing token, and enter it in your local connector. Then review a strategy and authorize its paper mandate.</p><a className="gold-button" href="#/strategies?step=connect">Set up moomoo<ArrowRight size={15}/></a></div></li>
          </ol>
          <p className="broker-footnote">Real-money orders are disabled. Software stops need the computer and OpenD to stay running. Pausing new entries does not cancel pending orders or close positions.</p>
        </section>

        <section className="broker-option broker-ibkr" aria-labelledby="ibkr-title">
          <div className="broker-option-heading"><h2 id="ibkr-title">Interactive Brokers</h2><span>Developer preview</span></div>
          <p>The local tools include a Client Portal paper adapter and a read-only TWS inspector. Paper execution needs explicit local setup and a verified paper session; the download includes the setup guide.</p>
          <div className="broker-links"><a href="https://www.interactivebrokers.com/campus/trading-lessons/launching-and-authenticating-the-gateway/" target="_blank" rel="noopener noreferrer">Set up Client Portal<ExternalLink size={13}/></a><ToolsDownload/></div>
          <p className="broker-footnote">Public IBKR automatic trading is not enabled. Broker approval and a complete paper-trading validation cycle are still required. The TWS inspector cannot place orders; keep its Read-Only API setting enabled.</p>
        </section>
      </div>

      <aside className="broker-status" aria-labelledby="broker-status-title">
        <h2 id="broker-status-title"><Monitor size={18}/>Your computers</h2>
        {!devices.length ? <p>{state.user ? 'No verified paired computer is available. Complete the moomoo setup to see its reported status here.' : 'Your paired computers and reported paper accounts appear here after sign-in.'}</p> : <div className="broker-devices">{devices.map(device => <article key={device.id}><h3>{device.name}</h3><p className="broker-device-state">{!state.stale && fresh(device.lastSeenAt) ? 'Reporting to Leo' : 'Offline or status expired'}</p><dl><dt>Last report</dt><dd>{device.lastSeenAt ? displayTime(device.lastSeenAt) : 'Not reported'}</dd><dt>Reported paper accounts</dt><dd>{device.accounts.length ? device.accounts.map(account => <span className="broker-account" key={account.accountId}>{account.accountId}<small>{account.environment} · {account.currency}</small></span>) : 'None reported'}</dd></dl></article>)}</div>}
        <p className="broker-footnote">A computer heartbeat shows that the connector can reach Leo. Account availability, broker connectivity, reconciliation, and your mandate are checked separately.</p>
        <a className="text-button" href="#/strategies?step=connect">Open connection workspace<ArrowRight size={14}/></a>
        <details className="broker-help"><summary>Does my computer need to stay on?</summary><p>Yes, while the connector manages a paper strategy. A VPS can run it instead of your laptop, but you still sign in to the broker there. Your website alone does not keep OpenD or IB Gateway running.</p></details>
        <details className="broker-help"><summary>What happens after a pattern appears?</summary><p>The local program evaluates your saved rule. It can submit a paper order only when your mandate, account, data, and risk checks pass. The website’s chart or an AI explanation cannot place an order.</p></details>
      </aside>
    </div>
  </div>;
}

function ToolsDownload() {
  return BROKER_TOOLS_RELEASE.available ? <a href={BROKER_TOOLS_RELEASE.download} download><Download size={14}/>Windows tools · unsigned preview</a> : <span className="broker-package-pending">Leo tools download is being prepared</span>;
}
