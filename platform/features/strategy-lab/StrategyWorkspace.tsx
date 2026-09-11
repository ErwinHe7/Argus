import React, { useEffect, useRef, useState } from 'react';
import { ArrowRight, Check, ChevronRight, Copy, Download, FlaskConical, LogOut, Monitor, Pause, RefreshCw, ShieldCheck } from 'lucide-react';
import type { ConnectorDevice, DeploymentMandate, Explanation, StrategyVersion } from '../../../ritual-investing-api/src/domains/strategy-lab/contracts';
import { STRATEGIES, STEPS, displayTime, elapsedLabel, validSymbol, type StrategyId } from './catalog';
import { signIn } from './auth';
import { StrategyApiError } from './client';
import { useWorkspace } from './useWorkspace';
import { controlLabel, evidenceText, latestEvidence, safeValue } from './state';
import './strategy.css';
import { AccountEvidence } from './AccountEvidence';
import { ResearchEvidence } from './ResearchEvidence';
import { GridResearch } from './grid/GridResearch';

// THESIS: Make a chosen rule, its evidence, and the state of its local paper connector readable together.
// OWN-WORLD: Inherit Astra's aubergine surfaces, flat rules, candle-gold actions, Inter, and Lion.
// STORY: Choose a rule, save a revision, inspect evidence, pair a computer, then authorize a paper mandate.
// FIRST VIEWPORT: A two-row strategy selector beside an always-available connection and control panel.
// FORM: A practical five-step workspace and persistent monitoring rail inside the established analyzer.
// FINISH: Verify signed-out, stale, pending acknowledgement, mobile, and chart-outage behavior.

export function StrategyWorkspace() {
  const state = useWorkspace();
  const [step, setStep] = useState(0);
  const [gridResearch, setGridResearch] = useState(false);
  const [strategyId, setStrategyId] = useState<StrategyId>('MR-v1');
  const [symbol, setSymbol] = useState('');
  const [configurationId, setConfigurationId] = useState('');
  const [deviceId, setDeviceId] = useState('');
  const [accountId, setAccountId] = useState('');
  const [mode, setMode] = useState<'dry_run'|'paper'>('dry_run');
  const [accepted, setAccepted] = useState(false);
  const [busy, setBusy] = useState('');
  const [notice, setNotice] = useState('');
  const [pairing, setPairing] = useState<{pairingToken: string; expiresAt: string} | null>(null);
  const [now, setNow] = useState(Date.now());
  const [question, setQuestion] = useState('');
  const [chatScope, setChatScope] = useState('');
  const [answers, setAnswers] = useState<Explanation[]>([]);
  const previousStep = useRef(step);
  const flowElement = useRef<HTMLDivElement>(null);
  const stepHeading = useRef<HTMLHeadingElement>(null);
  const actionKeys = useRef(new Map<string, string>());
  const selected = STRATEGIES.find(item => item.id === strategyId)!;
  const snapshot = state.snapshot;
  const configuration = snapshot?.configurations.find(item => item.id === configurationId);
  const device = snapshot?.devices.find(item => item.id === deviceId && !item.revokedAt);
  const deployment = snapshot?.deployments.find(item => item.strategyVersionId === configurationId && item.state !== 'retired');
  const authorized = Boolean(state.api && state.user && snapshot && !state.stale);

  useEffect(() => { const timer = setInterval(() => setNow(Date.now()), 1_000); return () => clearInterval(timer); }, []);
  useEffect(() => {
    setConfigurationId(''); setChatScope(''); setDeviceId(''); setAccountId(''); setPairing(null); setAnswers([]); setAccepted(false); setNotice('');
    actionKeys.current.clear();
  }, [state.user?.id]);
  useEffect(() => { if (pairing && Date.parse(pairing.expiresAt) <= now) setPairing(null); }, [now, pairing]);
  useEffect(() => {
    if (previousStep.current === step) return;
    previousStep.current = step;
    flowElement.current?.scrollIntoView({block:'start',behavior:'instant'});
    stepHeading.current?.focus({preventScroll:true});
  }, [step]);

  async function act(label: string, task: (key: string) => Promise<void>) {
    if (busy) return;
    setBusy(label); state.setError(''); setNotice('');
    // Retain this action's key after an ambiguous timeout. Do not duplicate a mandate.
    const key = actionKeys.current.get(label) ?? crypto.randomUUID();
    actionKeys.current.set(label, key);
    try { await task(key); actionKeys.current.delete(label); await state.refresh(); }
    catch (reason) { if (reason instanceof StrategyApiError && reason.status > 0 && reason.status < 500) actionKeys.current.delete(label); state.setError(reason instanceof Error ? reason.message : 'The action could not finish. Refresh to check its status.'); }
    finally { setBusy(''); }
  }
  function chooseConfiguration(item: StrategyVersion) {
    setConfigurationId(item.id); setStrategyId(item.strategyId); setSymbol(item.symbol); setAccepted(false); setStep(2);
  }
  function save() {
    if (!state.api || !validSymbol(symbol)) return;
    void act(`save:${strategyId}:${symbol}`, async key => {
      const item = await state.api!.configure({strategyId, symbol, parameters: {}}, key);
      setConfigurationId(item.id); setStep(2); setNotice('Revision saved. Existing positions keep their original rules.');
    });
  }
  function control(item: DeploymentMandate, action: 'pause'|'resume') {
    if (!state.api) return;
    void act(`${action}:${item.id}:${item.mandateVersion}`, async key => {
      await state.api!.control(item, action, key);
      setNotice(`${action === 'pause' ? 'Pause' : 'Resume'} requested. Waiting for the connector to acknowledge.`);
    });
  }
  const busyButton = (name: string) => busy.startsWith(name) ? 'Working…' : null;

  return <div className="strategy-workspace">
    <div className="strategy-heading"><div><h1>Strategies</h1><p>Choose the rules. Review the evidence. Run a paper account from your computer.</p></div><span className="strategy-mode"><ShieldCheck size={16}/>Paper & dry run only</span></div>
    <div className="strategy-auth-bar">
      <div><strong>{state.user ? state.user.email ?? 'Signed in' : 'Your strategy workspace'}</strong><p>{state.loading ? 'Restoring connection settings…' : state.user ? snapshot ? 'Identity verified · brokerage credentials stay on your computer' : 'Verifying your Leo identity…' : 'Explore the rules below. Sign in to save revisions and connect a computer.'}</p></div>
      {state.auth ? state.user ? <button className="border-button" onClick={() => { void act('signout', async () => { const result = await state.auth!.auth.signOut(); if (result.error) throw new Error('Sign-out could not finish. Try again.'); }); }} disabled={Boolean(busy)}><LogOut size={15}/>Sign out</button> : <button className="gold-button" disabled={Boolean(busy)} onClick={() => { void act('signin', async () => signIn(state.auth!)); }}>Sign in with Google<ArrowRight size={15}/></button> : <span className="strategy-muted">{state.loading ? 'Loading…' : 'Account connections awaiting release setup'}</span>}
    </div>
    <div className="strategy-local-research"><div><strong>Continuous research</strong><p>Run the tests in a background program and inspect its progress here. The local monitor requires your research runner, or a connection forwarded from your VPS.</p></div><a className="border-button" href="http://127.0.0.1:3119/" target="_blank" rel="noopener noreferrer"><Monitor size={15}/>Open local monitor<ArrowRight size={15}/></a></div>
    {state.error && <div className="strategy-alert" role="alert"><div><strong>{state.stale ? 'Connection interrupted' : 'Action needs attention'}</strong><p>{state.error}</p></div><button className="border-button" onClick={() => { if (state.api && state.user) void state.refresh(); else location.reload(); }}><RefreshCw size={15}/>Retry</button></div>}
    <p className="strategy-notice" role="status" aria-live="polite">{notice}</p>
    <div className="strategy-columns"><div className="strategy-flow" ref={flowElement}>
      {gridResearch ? <GridResearch onBack={() => setGridResearch(false)}/> : <>
      <nav className="strategy-steps" aria-label="Strategy setup">{STEPS.map((title, index) => <button key={title} aria-current={step === index ? 'step' : undefined} onClick={() => setStep(index)}><span>{index + 1}</span>{title}</button>)}</nav>
      <section className="strategy-step-content" aria-labelledby="strategy-step-title" key={step}>
        <h2 id="strategy-step-title" ref={stepHeading} tabIndex={-1}>{STEPS[step]}</h2>
        {step === 0 && <>
          <p className="strategy-intro">Two paper-strategy hypotheses and a separate grid research replay. None has a proven edge in your account.</p>
          <fieldset className="strategy-options"><legend className="sr-only">Select a strategy</legend>{STRATEGIES.map(item => <label className={item.id === strategyId ? 'strategy-option selected' : 'strategy-option'} key={item.id}><input type="radio" name="strategy" value={item.id} checked={strategyId === item.id} onChange={() => { setStrategyId(item.id); setConfigurationId(''); }}/><div><div className="strategy-option-title"><h3>{item.title}</h3><span>{item.id}</span></div><p>{item.premise}</p><p className="strategy-muted">{item.character}</p><details onClick={event => event.stopPropagation()}><summary>Rules and failure cases</summary><dl><dt>Entry</dt><dd>{item.entry}</dd><dt>Exit</dt><dd>{item.exit}</dd><dt>Local stop</dt><dd>{item.stop}</dd></dl><p className="strategy-loss">{item.failure}</p></details></div></label>)}</fieldset>
          <article className="strategy-grid-entry"><FlaskConical size={18}/><div><div className="strategy-option-title"><h3>Grid research</h3><span>GRID-R1 · research only</span></div><p>Replay fixed buy-and-sell levels across a price range. Compare total portfolio P&L, unsold inventory, and costs.</p><p className="strategy-muted">Local JSON data or labeled fictitious DEMOs · no broker or paper execution.</p><button className="border-button" onClick={() => setGridResearch(true)}>Open grid research<ArrowRight size={15}/></button></div></article>
          <div className="strategy-next"><p>Options and IV remain available as research in <a href="#/iv">Options lab</a>.</p><button className="gold-button" onClick={() => setStep(1)}>Configure {selected.title.toLowerCase()}<ArrowRight size={15}/></button></div>
        </>}
        {step === 1 && <>
          <p className="strategy-intro">{selected.title} · fixed v1 rules. Every saved revision has its own identity.</p>
          <form onSubmit={event => { event.preventDefault(); save(); }}>
            <label className="strategy-field">U.S. stock or ETF symbol<input placeholder="e.g. AAPL" value={symbol} onChange={event => { setSymbol(event.target.value.trim().toUpperCase()); setConfigurationId(''); }} pattern="[A-Z][A-Z0-9.\-]{0,9}" maxLength={10} required autoCapitalize="characters" autoComplete="off" spellCheck={false}/><small>The connector verifies the instrument and data entitlement.</small></label>
            {validSymbol(symbol)&&<a className="strategy-chart-link" href={`#/structure?symbol=${encodeURIComponent(symbol)}`} target="_blank" rel="noopener noreferrer">View {symbol} market chart<ArrowRight size={14}/></a>}
            <dl className="strategy-rules"><dt>History</dt><dd>220 completed sessions before a signal is eligible</dd><dt>Entry timing</dt><dd>Next regular session, 9:35–9:40 a.m. ET</dd><dt>Entry checks</dt><dd>Quote at most 5 seconds old · spread at most 20 bps</dd><dt>Order</dt><dd>Limit at ask + 10 bps · cancel remaining quantity at 9:40 a.m.</dd><dt>Stop</dt><dd>{selected.stop}</dd><dt>Simulated risk limits</dt><dd>0.25% per entry · 5% per position · 20% total exposure</dd><dt>Entry pause limits</dt><dd>1% daily loss · 5% drawdown, including unrealized P&L</dd><dt>Position policy</dt><dd>Whole shares · long only · no borrowing or adding to an open position</dd></dl>
            <p className="strategy-muted">Custom thresholds need a separately evaluated strategy version. These defaults are simulation settings, not a personal allocation recommendation.</p>
            <div className="strategy-next"><p>{authorized ? 'Save to your signed-in workspace.' : 'Sign in and connect to the strategy service to save.'}</p><button className="gold-button" disabled={!authorized || !validSymbol(symbol) || Boolean(busy)}>{busyButton('save:') ?? 'Save revision'}<ArrowRight size={15}/></button></div>
          </form>
          {Boolean(snapshot?.configurations.length) && <div className="strategy-saved"><h3>Saved revisions</h3>{snapshot!.configurations.map(item => <button key={item.id} onClick={() => chooseConfiguration(item)}><span><b>{item.symbol}</b> · {item.strategyId}<small>{displayTime(item.createdAt)}</small></span><ChevronRight size={16}/></button>)}</div>}
        </>}
        {step === 2 && <>
          <p className="strategy-intro">{configuration ? `${configuration.symbol} · ${configuration.strategyId}` : 'Save or select a revision to request historical evaluation.'}</p>
          <div className="strategy-evidence-note"><h3>Evidence comes from your local data</h3><p>The connector reads entitled OpenD history or a validated file import. Source, adjustment, calendar, and coverage travel with each report. Daily-bar approximations cannot verify the 9:35 entry window.</p><p>No return estimate is available until a valid report is produced.</p></div>
          <button className="border-button" disabled={!authorized || !configuration || Boolean(busy)} onClick={() => { void act(`research:${configurationId}`, async key => { await state.api!.research(configurationId, key); setNotice('Research request recorded. Check its data and connector requirements below.'); }); }}>{busyButton('research:') ?? 'Request historical evaluation'}</button>
          <ResearchEvidence events={snapshot?.evidence.filter(event => !configurationId || snapshot.researchRuns.some(run => run.strategyVersionId === configurationId && run.evidenceEventId === event.id)) ?? []}/><div className="strategy-research-list">{snapshot?.researchRuns.filter(run => !configurationId || run.strategyVersionId === configurationId).map(run => <article key={run.id}><header><strong>{run.status === 'completed' ? 'Report available' : run.status}</strong><time>{displayTime(run.createdAt)}</time></header><p>{run.reason}</p>{run.status !== 'completed' && <label className="strategy-report-import">Import the local research report<input type="file" accept="application/json,.json" disabled={!authorized || Boolean(busy)} onChange={event => { const file=event.target.files?.[0]; event.target.value=''; if(!file)return; void act(`report:${run.id}:${file.name}:${file.lastModified}`,async key => { if(file.size>48*1024)throw new Error('Use the summary report from the research CLI, under 48 KiB. Keep raw histories on your computer.'); let report:unknown; try { report=JSON.parse(await file.text()); } catch { throw new Error('This file is not valid JSON. Export the research summary again.'); } if(!report || typeof report !== 'object' || 'bars' in report || 'input_manifest' in report)throw new Error('Choose the research summary report. Raw historical datasets remain local.'); await state.api!.uploadReport(run.id,report,key);setNotice('Research report attached. Review its exploratory status and limitations.'); }); }}/></label>}{run.evidenceEventId && <a href={`#strategy-event-${run.evidenceEventId}`} onClick={event => { event.preventDefault(); document.getElementById(`strategy-event-${run.evidenceEventId}`)?.scrollIntoView({block:'center'}); }}>View recorded report</a>}</article>)}</div>
          <div className="strategy-next"><p>Pair your computer to supply local research and paper-account evidence.</p><button className="gold-button" onClick={() => setStep(3)}>Connect computer<ArrowRight size={15}/></button></div>
        </>}
        {step === 3 && <>
          <p className="strategy-intro">OpenD stays locally installed and authenticated. Leo receives status and evidence through outbound connections.</p>
          <ol className="strategy-install"><li><strong>Install OpenD and Leo Connector</strong><p>Use the installation guide for your operating system. Keep OpenD running and select a U.S. paper account.</p><a className="text-button" href="/app/research-desk/strategy-connector-guide.md" download><Download size={15}/>Connector guide</a></li><li><strong>Authorize this computer</strong><p>Create a short-lived, single-use pairing token here. Paste it into the connector’s pairing prompt on your computer.</p><button className="border-button" disabled={!authorized || Boolean(busy)} onClick={() => { void act('pairing', async key => setPairing(await state.api!.pairing(key))); }}>{busyButton('pairing') ?? 'Create pairing token'}</button>{pairing && <div className="strategy-pairing"><label>Single-use pairing token<input readOnly value={pairing.pairingToken} onFocus={event => event.currentTarget.select()}/></label><button className="border-button" onClick={() => { void navigator.clipboard.writeText(pairing.pairingToken).then(() => setNotice('Pairing token copied.'), () => setNotice('Select and copy the token manually.')); }}><Copy size={15}/>Copy</button><p>Expires {displayTime(pairing.expiresAt)}. Only paste into a connector you control.</p></div>}</li><li><strong>Confirm the paper account</strong><p>Your paired device and discovered SIMULATE accounts appear below.</p><DeviceFields devices={snapshot?.devices ?? []} deviceId={deviceId} accountId={accountId} onDevice={value => { setDeviceId(value); setAccountId(''); setAccepted(false); }} onAccount={value => { setAccountId(value); setAccepted(false); }}/></li></ol>
          <div className="strategy-next"><p>Windows x64 · macOS Intel / Apple Silicon · Ubuntu x64. Native verification status is in the guide.</p><button className="gold-button" onClick={() => setStep(4)}>Review authorization<ArrowRight size={15}/></button></div>
        </>}
        {step === 4 && <>
          <p className="strategy-intro">Authorize one policy for one paper account and instrument. A new mandate starts paused.</p>
          <label className="strategy-field">Saved revision<select value={configurationId} onChange={event => { setConfigurationId(event.target.value); setAccepted(false); }}><option value="">Choose a saved revision</option>{snapshot?.configurations.map(item => <option key={item.id} value={item.id}>{item.symbol} · {item.strategyId} · {displayTime(item.createdAt)}</option>)}</select></label>
          <DeviceFields devices={snapshot?.devices ?? []} deviceId={deviceId} accountId={accountId} onDevice={value => { setDeviceId(value); setAccountId(''); setAccepted(false); }} onAccount={value => { setAccountId(value); setAccepted(false); }}/>
          <fieldset className="strategy-run-mode"><legend>Execution mode</legend><label><input type="radio" checked={mode === 'dry_run'} onChange={() => { setMode('dry_run'); setAccepted(false); }}/>Dry run <small>Record decisions without sending orders</small></label><label><input type="radio" checked={mode === 'paper'} onChange={() => { setMode('paper'); setAccepted(false); }}/>Paper account <small>Submit only to the selected SIMULATE account</small></label></fieldset>
          <label className="strategy-consent"><input type="checkbox" checked={accepted} onChange={event => setAccepted(event.target.checked)}/><span>I authorize these fixed rules for this account. Local software stops require my computer and OpenD to stay running. Pause stops new entries after acknowledgement; it does not cancel orders or close positions.</span></label>
          <button className="gold-button" disabled={!authorized || !configuration || !device || !accountId || !accepted || Boolean(busy)} onClick={() => { void act(`deploy:${configurationId}:${deviceId}:${accountId}:${mode}`, async key => { await state.api!.deploy({strategyVersionId: configuration!.id, configurationHash: configuration!.configurationHash, deviceId, accountId, mode}, key); setNotice('Mandate saved and paused. Resume after the connector completes reconciliation.'); }); }}>{busyButton('deploy:') ?? `Create paused ${mode === 'paper' ? 'paper' : 'dry-run'} mandate`}<Check size={15}/></button>
          {deployment && <p className="strategy-muted">Current mandate: {controlLabel(deployment, snapshot?.controls ?? [], now)}. Use the monitor to request resume.</p>}
        </>}
      </section>
      </>}
    </div>
    <aside className="strategy-monitor" aria-labelledby="strategy-monitor-title"><div className="strategy-monitor-heading"><h2 id="strategy-monitor-title">Local monitor</h2><button className="icon-button" aria-label="Refresh connector status" disabled={!state.user} onClick={() => { void state.refresh(); }}><RefreshCw size={16}/></button></div><p className="strategy-muted">{state.stale ? 'Data may be stale. Last reported values shown.' : state.lastUpdated ? `Updated ${displayTime(state.lastUpdated)}` : 'No connector evidence received.'}</p>
      {snapshot?.devices.filter(item => !item.revokedAt).map(item => <div className="strategy-device-health" key={item.id}><Monitor size={18}/><div><strong>{item.name}</strong><small>{item.platform} · {elapsedLabel(item.lastSeenAt, now)}</small></div><button className="text-button strategy-revoke" disabled={!authorized || Boolean(busy)} onClick={() => { void act(`revoke:${item.id}`, async key => { await state.api!.revoke(item.id,key); setNotice('Device revoked. It can no longer renew authorization for new entries.'); }); }}>Revoke</button></div>)}
      {!snapshot?.devices.some(item => !item.revokedAt) && <div className="strategy-monitor-empty"><Monitor size={25}/><h3>No computer connected</h3><p>Pair a local connector to see its heartbeat, broker connection, and account status.</p><button className="text-button" onClick={() => { setGridResearch(false); setStep(3); }}>Set up a connector<ArrowRight size={14}/></button></div>}
      {snapshot?.deployments.map(item => { const label = controlLabel(item, snapshot.controls, now); const heartbeat = latestEvidence(snapshot.evidence, 'heartbeat', item.id); const reconcile = latestEvidence(snapshot.evidence, 'reconciliation', item.id); const pending = snapshot.controls.some(control => control.deploymentId === item.id && control.status === 'pending'); return <section className="strategy-mandate" key={item.id}><h3>{item.strategyVersion.symbol}<span>{item.strategyVersion.strategyId} · {item.mode === 'paper' ? 'Paper' : 'Dry run'}</span></h3><strong className={label === 'Running' ? 'strategy-live-state' : 'strategy-pause-state'}>{label}</strong><dl><dt>Broker</dt><dd>{safeValue(heartbeat?.payload.brokerConnectivity ?? heartbeat?.payload.broker_connected)}</dd><dt>Quote age</dt><dd>{safeValue(heartbeat?.payload.quoteAgeSeconds ?? heartbeat?.payload.quote_age_seconds)} {heartbeat?.payload.quoteAgeSeconds != null || heartbeat?.payload.quote_age_seconds != null ? 'seconds' : ''}</dd><dt>Reconciliation</dt><dd>{evidenceText(reconcile)}</dd><dt>Local stops</dt><dd>{state.stale || !heartbeat || now - Date.parse(heartbeat.occurredAt) > 15_000 ? 'Protection unavailable' : heartbeat.payload.protectionStatus === 'unavailable' ? 'Protection unavailable' : heartbeat.payload.protectionStatus === 'local_software_stop' ? 'Local software monitoring' : safeValue(heartbeat.payload.protectionStatus ?? heartbeat.payload.protection_status)}</dd></dl><p className="strategy-muted">{item.pauseReason}</p>{item.state !== 'retired' && <div className="strategy-control-buttons"><button className="strategy-pause-button" disabled={!state.user || Boolean(busy) || pending && label === 'Pause requested'} onClick={() => control(item, 'pause')}><Pause size={15}/>Pause entries</button><button className="border-button" disabled={!authorized || Boolean(busy) || pending || item.state === 'running'} onClick={() => control(item, 'resume')}>Request resume</button></div>}<p className="strategy-control-note">Pending orders and existing positions remain active.</p>{item.state === 'paused' && <details className="strategy-retire"><summary>Replace this policy</summary><p>Retirement requires an acknowledged pause and fresh reconciliation showing no positions, working orders, or unknown submissions. It never closes a position.</p><button className="border-button" disabled={!authorized || Boolean(busy) || pending} onClick={() => { void act(`retire:${item.id}:${item.mandateVersion}`, async key => { await state.api!.retire(item,key); setNotice('Retirement requested. Wait for acknowledgement before creating a replacement mandate.'); }); }}>Retire flat policy</button></details>}</section>; })}
      <p className="strategy-monitor-foot">Keep your computer and OpenD awake. This release has no native stop or OCO protection.</p>
    </aside></div>
    <AccountEvidence deployments={snapshot?.deployments ?? []} events={snapshot?.evidence ?? []} stale={state.stale}/><section className="strategy-records" aria-labelledby="strategy-records-title"><div className="strategy-section-heading"><h2 id="strategy-records-title">Recorded activity</h2><span>Times in ET · last reported values</span></div><p className="strategy-muted">Decisions, positions, equity, drawdown, orders, fill observations, reconciliation, and incidents come from your connector. Modeled costs remain separate from broker facts.</p>{!snapshot?.evidence.length ? <p className="strategy-records-empty">No evidence has been uploaded. Account values and performance remain unreported.</p> : <div className="strategy-event-list">{[...snapshot.evidence].sort((a,b) => Date.parse(b.occurredAt)-Date.parse(a.occurredAt)).slice(0,50).map(event => <details id={`strategy-event-${event.id}`} key={event.id}><summary><time>{displayTime(event.occurredAt)}</time><span className={event.kind === 'incident' ? 'strategy-loss' : ''}>{event.kind.replaceAll('_',' ')}</span><strong>{evidenceText(event)}</strong></summary><pre>{JSON.stringify(event.payload, null, 2)}</pre><small>Evidence {event.id} · sequence {event.sequence}</small></details>)}</div>}</section>
    <section className="strategy-supervisor" aria-labelledby="strategy-supervisor-title"><div><h2 id="strategy-supervisor-title">Ask about the evidence</h2><p className="strategy-muted">The supervisor explains recorded activity and can request a pause. It cannot place orders, change rules, or resume.</p><div className="strategy-quick-questions">{['Why was there no trade today?', 'Explain the latest order.', 'What needs attention?'].map(text => <button className="border-button" key={text} onClick={() => setQuestion(text)}>{text}</button>)}</div></div><div className="strategy-conversation"><label className="strategy-field">Evidence scope<select value={chatScope} onChange={event => setChatScope(event.target.value)}><option value="">All my records</option>{snapshot?.deployments.filter(item => item.state !== 'retired').map(item => <option key={item.id} value={item.id}>{item.strategyVersion.symbol} · {item.strategyVersion.strategyId} · {item.accountId}</option>)}</select></label>{answers.map(answer => <article key={answer.id}><p>{answer.answer}</p>{answer.pauseControlId && <p className="strategy-pause-state">Supervisor pause requested. Check Local monitor for acknowledgement.</p>}<small>{displayTime(answer.createdAt)} · {answer.providerStatus === 'available' ? 'Supervisor explanation' : 'Recorded-evidence fallback'} · {answer.evidenceIds.length} evidence references</small></article>)}<form onSubmit={event => { event.preventDefault(); if (!state.api || !question.trim()) return; void act(`explain:${question.trim()}:${chatScope}`, async key => { const answer = await state.api!.explain(question.trim(), chatScope || undefined, key); setAnswers(current => [...current, answer]); setQuestion(''); if(answer.pauseControlId)setNotice('Supervisor requested a pause for the selected policy. Waiting for connector acknowledgement.'); }); }}><label htmlFor="strategy-question">Your question</label><textarea id="strategy-question" value={question} maxLength={1500} onChange={event => setQuestion(event.target.value)} rows={3} placeholder="Ask why the connector made a decision…"/><button className="gold-button" disabled={!authorized || !question.trim() || Boolean(busy)}>{busyButton('explain') ?? 'Explain records'}<ArrowRight size={15}/></button></form></div></section>
  </div>;

}

function DeviceFields({devices, deviceId, accountId, onDevice, onAccount}: {
  devices: ConnectorDevice[]; deviceId: string; accountId: string;
  onDevice: (id: string) => void; onAccount: (id: string) => void;
}) {
  const device = devices.find(item => item.id === deviceId && !item.revokedAt);
  return <div className="strategy-device-fields">
    <label className="strategy-field">Paired computer
      <select value={deviceId} onChange={event => onDevice(event.target.value)}>
        <option value="">Choose a computer</option>
        {devices.filter(item => !item.revokedAt).map(item => <option key={item.id} value={item.id}>{item.name} / {item.platform}</option>)}
      </select>
    </label>
    <label className="strategy-field">Paper account
      <select value={accountId} onChange={event => onAccount(event.target.value)} disabled={!device}>
        <option value="">Choose a SIMULATE account</option>
        {device?.accounts.map(account => <option key={account.accountId} value={account.accountId}>{account.accountId} / {account.currency} / SIMULATE</option>)}
      </select>
    </label>
  </div>;
}
