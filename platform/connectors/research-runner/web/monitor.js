'use strict';
const el = id => document.getElementById(id);
const token = document.querySelector('meta[name="leo-control"]').content;
let latest = null, pending = null, busy = false;
const names = {running:'Running a research test',waiting:'Watching for new data',paused:'Research is paused',error:'Worker needs attention',unavailable:'Worker status unavailable',stopped:'Worker has stopped',stopping:'Worker is stopping'};
const jobStates = {pending:'Waiting for input',running:'Testing',completed:'Recorded',rejected:'Input needs attention',insufficient_evidence:'More evidence needed',recovered:'Recovered after restart'};
const blockers = {fewer_than_220_completed_sessions:'Fewer than 220 completed sessions for warm-up.',split_adjustment_attestation_missing:'The source does not verify its split-adjustment policy.',official_session_coverage_unverified:'Complete exchange-session coverage has not been verified.',per_bar_historical_availability_receipt_missing:'No record shows when each historical bar became available.',historical_executable_option_chain_missing:'Historical executable option quotes are unavailable.'};
function node(tag, text, className) {const item=document.createElement(tag);item.textContent=String(text??'');if(className)item.className=className;return item;}
function notice(text) {el('notice').textContent=text;el('notice').hidden=!text;}
function render(data) {
  latest=data;
  const failed=['error','stopped','stopping','unavailable'].includes(data.state);
  document.body.dataset.stale=String(!data.fresh||failed);
  el('headline').textContent=!data.fresh?'The worker needs a check.':failed?'The worker needs attention.':data.state==='paused'?'Research is paused.':data.state==='running'?'Research is running.':'Research is watching.';
  el('state').textContent=data.fresh?(names[data.state]||'Worker status received'):'No recent worker heartbeat';
  el('heartbeat').textContent=data.heartbeat_age_seconds===null?'No heartbeat received':`Last heartbeat ${data.heartbeat_age_seconds} seconds ago`;
  el('cadence').textContent=data.interval_seconds?`Checks for changed inputs every ${data.interval_seconds} seconds.`:'Start the worker to check for inputs.';
  el('trials').textContent=data.counters?.trials??'—';el('completed').textContent=data.counters?.replay_trials??'—';
  el('attention').textContent=data.attention_count??'—';
  el('ai').textContent=data.llm_calls===0?'0':'—';
  if(pending==='pause'&&data.state==='paused'){pending=null;notice('Research paused. An active read-only test may finish.');}
  if(pending==='resume'&&data.state!=='paused'&&!data.pause_requested){pending=null;notice('Research resumed. Unchanged inputs keep their recorded result.');}
  const paused=data.state==='paused'||data.pause_requested;
  el('control').textContent=pending?`${pending==='pause'?'Pause':'Resume'} requested…`:paused?'Resume research':'Pause research';
  el('control').disabled=busy||Boolean(pending)||!data.fresh||failed||data.shutdown_requested;
  if(data.state==='error'&&data.reason)notice(data.reason);
  el('jobs').replaceChildren();
  for(const job of data.jobs||[]) {
    const row=node('article','','job'), title=node('div','');
    title.append(node('h3',job.id),node('p',job.kind==='source-capability'?'Source readiness':'Strategy evaluation','job-type'));
    const detail=node('div','');detail.append(node('p',jobStates[job.state]||job.state,'job-state'),node('p',job.reason||'The result stays recorded until the input or engine changes.','job-reason'));
    row.append(title,detail);el('jobs').append(row);
  }
  if(!data.jobs?.length)el('jobs').append(node('p',data.reason||'No research jobs are configured. Add validated inputs to the local configuration.','note'));
  el('source').textContent=data.source?`${data.source} · collected ${data.retrieved_at||'time unavailable'}`:'No source receipt loaded yet.';
  const open=new Set([...el('coverage').querySelectorAll('details[open]')].map(item=>item.dataset.symbol));
  el('coverage').replaceChildren();
  for(const row of data.coverage||[]) {
    const detail=node('details','','coverage-row');detail.dataset.symbol=String(row.symbol);detail.open=open.has(String(row.symbol));
    const summary=node('summary','');summary.append(node('strong',row.symbol),node('span',`${row.observed_sessions??'Unknown'} observed sessions`),node('span',row.blockers?.length?'View missing evidence':'Source receipt available','condition'));
    detail.append(summary,node('p',`${row.first_session||'Unknown start'} to ${row.last_session||'unknown cutoff'}`,'coverage-range'));
    const list=node('ul','');for(const blocker of row.blockers||[])list.append(node('li',blockers[blocker]||String(blocker).replaceAll('_',' ')));
    detail.append(list);el('coverage').append(detail);
  }
  if(!data.coverage?.length)el('coverage').append(node('p','A source check will show available history and any missing evidence here.','note'));
  el('last-start').textContent=data.started_at?`Worker started ${new Date(data.started_at).toLocaleString()}. Its trial journal survives restarts.`:'The worker retains its journal across restarts.';
}
async function refresh() {
  try {
    const response=await fetch('/api/status',{cache:'no-store',signal:AbortSignal.timeout(5000)});
    if(!response.ok)throw new Error('Status request failed');
    const data=await response.json();
    if(data.schema_version!=='leo-research-monitor.v1'||data.execution_authorized!==false||data.llm_calls!==0)throw new Error('Unexpected status');
    render(data);
  } catch {
    document.body.dataset.stale='true';el('headline').textContent='The monitor is disconnected.';el('state').textContent='Connection lost';
    el('heartbeat').textContent='Last values retained; they may be out of date.';el('control').disabled=true;
    notice('Cannot reach the local monitor. Keep its process running, then refresh.');
  }
}
el('refresh').addEventListener('click',()=>{notice('');void refresh();});
el('control').addEventListener('click',async()=>{
  if(!latest?.fresh||busy||pending)return;
  const action=latest.state==='paused'||latest.pause_requested?'resume':'pause';busy=true;el('control').disabled=true;
  try {
    const response=await fetch('/api/control',{method:'POST',headers:{'Content-Type':'application/json','X-Leo-Control':token},body:JSON.stringify({action}),signal:AbortSignal.timeout(5000)});
    if(!response.ok){const error=await response.json();throw new Error(error.error||'Control was not accepted');}
    pending=action;notice(`${action==='pause'?'Pause':'Resume'} requested. Waiting for the worker’s next heartbeat.`);
  }catch(error){notice(error.message||'Check the worker state before retrying.');}
  finally{busy=false;await refresh();}
});
void refresh();setInterval(()=>void refresh(),5000);
