import React, { useEffect, useState } from 'react';
import { ArrowRight, Download, ExternalLink, Monitor, RefreshCw } from 'lucide-react';
import { useWorkspace } from '../useWorkspace';
import { signIn } from '../auth';
import { displayTime } from '../catalog';
import { BROKER_TOOLS_RELEASE } from './release';
import { DirectMoomooLink } from './DirectMoomooLink';
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
  const status = state.loading ? 'Checking your account…' : !state.user ? 'Sign in to view your computers' : !state.snapshot ? 'Computer status not verified' : reporting ? 'Computer reporting' : devices.length ? 'Computer offline or status expired' : 'No local computer paired';

  async function login() {
    if (!state.auth || busy) return;
    setBusy(true); state.setError('');
    try { await signIn(state.auth, '/#/brokers'); }
    catch (error) { state.setError(error instanceof Error ? error.message : 'Google sign-in could not start. Try again.'); }
    finally { setBusy(false); }
  }

  return <div className="broker-workspace">
    <header className="broker-heading"><h1>Connect your broker</h1><p>Link moomoo for read-only account access, or set up a local runner for paper strategies.</p></header>
    <div className="broker-identity">
      <div role="status" aria-atomic="true"><strong>{status}</strong><p>{state.user ? `${state.user.email ?? 'Signed in'} · ${state.snapshot ? state.stale ? 'last verified Leo account records' : 'Leo account records verified' : 'checking Leo account records'}` : 'Use Google for your Leo account. Broker sign-in happens directly with moomoo or IBKR.'}</p>{reporting && <p>A computer heartbeat does not confirm broker login or permission to trade.</p>}</div>
      {!state.user && state.auth && <button className="border-button" onClick={() => { void login(); }} disabled={busy || state.loading}>{busy ? 'Opening Google…' : 'Sign in with Google'}<ArrowRight size={15}/></button>}
      {state.user && state.api && <button className="text-button" onClick={() => { void state.refresh(); }}><RefreshCw size={15}/>Refresh status</button>}
    </div>
    {state.error && <p className="broker-error" role="alert">{state.error} {state.stale ? 'Last reported account details remain below; current connectivity is unverified.' : ''}</p>}

    <div className="broker-layout">
      <div className="broker-main">
        <section className="broker-option" aria-labelledby="moomoo-title">
          <div className="broker-option-heading"><h2 id="moomoo-title">moomoo / Futu</h2><span>Account access &amp; local paper setup</span></div>
          <DirectMoomooLink/>
          <h3 className="broker-local-title">Run local paper strategies with OpenD</h3>
          <p>Use OpenD and Leo’s local runner for U.S. stock and ETF paper strategies. Keep both programs running on the same computer.</p>
          <details className="broker-local-setup"><summary>Set up automatic paper trading with OpenD</summary>
          <ol className="broker-steps">
            <li><div><h3>Install OpenD and the Leo runner</h3><p>Download and extract the Windows tools. In PowerShell 7, open the extracted folder and run <code>.\install.ps1</code>. Keep the installation folder and the pairing and start commands it prints. Already installed? Use that existing installation.</p><div className="broker-links"><a href="https://www.moomoo.com/download/OpenAPI" target="_blank" rel="noopener noreferrer">Download OpenD<ExternalLink size={13}/></a><ToolsDownload/></div></div></li>
            <li><div><h3>Sign in to your paper account in OpenD</h3><p>Complete the broker’s verification locally. Select an entitled U.S. SIMULATE account and leave OpenD running on its local port 11111. The website cannot verify this login for you.</p></div></li>
            <li><div><h3>Pair the installed runner with Leo</h3><p>Open the pairing workspace below and create a one-use token. Run the installed <code>scripts/pair.ps1</code> command, then paste the token only into its hidden local prompt. Confirm the reported account identifier matches OpenD.</p><a className="gold-button" href="#/strategies?step=connect">Set up moomoo<ArrowRight size={15}/></a></div></li>
            <li><div><h3>Review your strategy, then start the runner</h3><p>Begin with a paused dry-run mandate. Review the account, rules and limits before running the installed <code>scripts/start.ps1</code> command. A dry run sends no orders; an authorized paper mandate can send simulated orders. Pairing alone starts neither.</p></div></li>
          </ol>
          </details>
          <p className="broker-footnote">Real-money orders are disabled. Software stops need the computer and OpenD to stay running. Pausing new entries does not cancel pending orders or close positions.</p>
        </section>

        <section className="broker-option broker-ibkr" aria-labelledby="ibkr-title">
          <div className="broker-option-heading"><h2 id="ibkr-title">Interactive Brokers</h2><span>Developer preview</span></div>
          <p>Use the separate Client Portal Gateway for the local paper adapter. This is a developer setup, with explicit account and certificate checks. TWS and IB Gateway inspection are read-only and do not enable this execution path.</p>
          <div className="broker-links"><a href="https://www.interactivebrokers.com/campus/trading-lessons/launching-and-authenticating-the-gateway/" target="_blank" rel="noopener noreferrer">Set up Client Portal<ExternalLink size={13}/></a><ToolsDownload/></div>
          <details className="broker-local-setup"><summary>IBKR local paper setup</summary>
            <ol className="broker-steps">
              <li><div><h3>Prepare the local gateway</h3><p>Install Client Portal Gateway and its supported Java runtime using IBKR’s guide. Restrict the gateway to localhost and configure a trusted certificate for <code>localhost</code>. Keep its certificate file or independently verified SHA-256 fingerprint for pairing.</p></div></li>
              <li><div><h3>Authenticate directly with IBKR</h3><p>Open <code>https://localhost:5000</code> yourself, sign in to the paper environment, and complete verification there. Keep the gateway running and follow IBKR’s reauthentication prompts. A DU account name or an open port alone is not paper-session proof.</p></div></li>
              <li><div><h3>Pair the IBKR profile</h3><p>Install Leo’s Windows runner as described above, then open the pairing workspace. Replace every example path and account below with your own values. Use the installed folder printed by the installer; enter the one-use pairing token only at the hidden prompt.</p><pre className="broker-command"><code>{String.raw`$app = 'C:\replace-with-your-installed-Leo-folder'
& "$app\scripts\pair.ps1" -Broker ibkr-gateway -EnableIbkrPaper -Account 'IBKR:DU1234567' -GatewayCaFile 'C:\path\localhost.pem' -HistoryDirectory 'C:\path\history'`}</code></pre><p><code>DU1234567</code> is an example. The adapter must verify the exact account and an authenticated paper session. The bundled <code>IBKR.md</code> explains certificate fingerprint and history-file requirements.</p><a className="border-button" href="#/strategies?step=connect">Open IBKR pairing workspace<ArrowRight size={15}/></a></div></li>
              <li><div><h3>Review before starting</h3><p>Confirm the paper account, reconciliation, strategy and limits in Leo. Keep a separate IBKR profile and journal. Start only after that review:</p><pre className="broker-command"><code>{String.raw`& "$app\scripts\start.ps1" -Broker ibkr-gateway`}</code></pre><p>This command runs the local connector and can send orders under an authorized paper mandate. It is not a connection test.</p></div></li>
            </ol>
          </details>
          <p className="broker-footnote">Public IBKR automatic trading is not enabled. Broker approval and a complete paper-trading validation cycle are still required. The TWS inspector cannot place orders; keep its Read-Only API setting enabled.</p>
        </section>
      </div>

      <aside className="broker-status" aria-labelledby="broker-status-title">
        <h2 id="broker-status-title"><Monitor size={18}/>Your computers</h2>
        {!devices.length ? <p>{state.user ? 'No verified paired computer is available. Complete your broker’s local setup, then pair its Leo runner.' : 'Your paired computers and reported paper accounts appear here after sign-in.'}</p> : <div className="broker-devices">{devices.map(device => <article key={device.id}><h3>{device.name}</h3><p className="broker-device-state">{!state.stale && fresh(device.lastSeenAt) ? 'Reporting to Leo' : 'Offline or status expired'}</p><dl><dt>Last report</dt><dd>{device.lastSeenAt ? displayTime(device.lastSeenAt) : 'Not reported'}</dd><dt>Reported paper accounts</dt><dd>{device.accounts.length ? device.accounts.map(account => <span className="broker-account" key={account.accountId}>{account.accountId}<small>{account.environment} · {account.currency}</small></span>) : 'None reported'}</dd></dl></article>)}</div>}
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
