'use strict';

const $ = selector => document.querySelector(selector);
const store = {
  get(key, fallback) { try { const value = localStorage.getItem('scout:' + key); return value === null ? fallback : JSON.parse(value); } catch { return fallback; } },
  set(key, value) { try { localStorage.setItem('scout:' + key, JSON.stringify(value)); return true; } catch { return false; } },
  remove(key) { try { localStorage.removeItem('scout:' + key); } catch {} },
};
const list = text => text.split(/[,\n]/).map(s => s.trim()).filter(Boolean);
const emptyProfile = () => ({ fullName: '', firstName: '', lastName: '', email: '', phone: '', location: '', linkedin: '', website: '', github: '', currentTitle: '', currentCompany: '', education: '', skills: [], summary: '', targetTitles: [] });
const emptyFacts = () => ({ workAuthorizedUS: '', needsSponsorship: '', notes: '' });
const emptyPreferences = () => ({ titles: [], locations: [], exclude: list('senior, staff, principal, director, manager, lead, intern'), companies: [] });
let workspaceKey = store.get('workspace-key', '');
if (!/^[0-9a-f]{64}$/.test(workspaceKey)) { workspaceKey = (crypto.randomUUID() + crypto.randomUUID()).replaceAll('-', ''); store.set('workspace-key', workspaceKey); }
const state = { profile: null, facts: emptyFacts(), resume: null, resumeDirty: false, jobs: [], history: {}, hunt: null, hunts: [], preferences: emptyPreferences(), timer: null, loaded: false, loading: null, busy: 0, dirty: false, revision: 0, updatedAt: null, saveQueue: Promise.resolve(), omittedJobs: 0, legacyPending: false, legacyUnresolved: false };
const ACTIVE = new Set(['queued', 'running', 'waiting', 'waitingForPause', 'paused', 'unknown']);
const LABELS = { submitted: 'Submitted', dry_run: 'Dry run · not sent', needs_you: 'Needs you · not submitted', failed: 'Failed', working: 'Applying now', queued: 'Queued · not submitted' };
const GLYPHS = { submitted: '✦', dry_run: '◌', needs_you: '◎', failed: '✕', working: '●', queued: '·' };
const resultLabel = result => result?.legacyStatus === 'submitted' ? 'Previously submitted' : result?.legacyStatus === 'needs_review' ? 'Previous attempt — check employer' : result?.submissionAttempted && result.status !== 'submitted' ? 'Submission unconfirmed · check employer' : LABELS[result?.status] ?? result?.status ?? 'Not started';
const headers = (key = workspaceKey) => ({ 'content-type': 'application/json', 'x-access-code': $('#code').value.trim(), 'x-workspace-key': key });
async function api(path, body, method = body === undefined ? 'GET' : 'POST', key = workspaceKey) {
  const response = await fetch(path, { method, headers: headers(key), body: body === undefined ? undefined : JSON.stringify(body) });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || `Request failed (${response.status}).`);
  return data;
}
function el(tag, props = {}, ...children) { const node = Object.assign(document.createElement(tag), props); node.append(...children.filter(c => c != null && c !== false)); return node; }
const safeHref = url => (/^https:\/\//.test(url) ? url : null);
const dateLabel = value => { const date = new Date(value); return Number.isNaN(date.getTime()) ? '' : date.toLocaleString(); };
function updateControls() {
  const unavailable = !state.loaded || state.busy > 0;
  for (const id of ['resume', 'manual-profile', 'save-profile', 'search', 'add-links', 'delete-application']) $('#' + id).disabled = unavailable;
  $('#open-application').disabled = state.busy > 0;
  $('#restore-application').disabled = state.busy > 0;
  $('#code').disabled = state.busy > 0;
  const running = !!state.hunt && ACTIVE.has(state.hunt.status);
  $('#start').disabled = unavailable || running; $('#stop').disabled = unavailable || !running;
}
async function busy(task) { state.busy++; updateControls(); try { return await task(); } finally { state.busy--; updateControls(); } }
async function ensureLoaded() { if (state.loading) await state.loading; if (!state.loaded) throw new Error('Enter your access code and open your saved application first.'); }
function showPreferences() { for (const key of ['titles', 'locations', 'exclude', 'companies']) $('#' + key).value = (state.preferences[key] ?? []).join(key === 'companies' ? '\n' : ', '); }
function readPreferences() { state.preferences = Object.fromEntries(['titles', 'locations', 'exclude', 'companies'].map(key => [key, list($('#' + key).value)])); }
function showProfile() {
  for (const field of document.querySelectorAll('[data-p]')) { const value = state.profile?.[field.dataset.p] ?? ''; field.value = Array.isArray(value) ? value.join(', ') : value; }
  for (const field of document.querySelectorAll('[data-f]')) field.value = state.facts[field.dataset.f] ?? '';
  $('#profile-section').hidden = !state.profile; $('#search-section').hidden = !state.profile;
}
function readProfile() {
  if (state.profile) { const profile = { ...state.profile }; for (const field of document.querySelectorAll('[data-p]')) profile[field.dataset.p] = 'list' in field.dataset ? list(field.value) : field.value.trim(); state.profile = profile; }
  state.facts = Object.fromEntries(Array.from(document.querySelectorAll('[data-f]')).map(field => [field.dataset.f, field.value.trim()])); readPreferences();
}
function emailValid(required = false) {
  const field = $('[data-p="email"]');
  if ((required && !field.value.trim()) || !field.validity.valid) { field.setCustomValidity(required && !field.value.trim() ? 'Enter the email address employers should contact.' : ''); field.reportValidity(); field.setCustomValidity(''); return false; }
  return true;
}
function removeLegacyDraft(clearHistory = false) {
  const keys = ['profile', 'facts', 'resume', 'companies'];
  if (clearHistory) keys.push('jobs', 'history', 'hunt');
  for (const key of keys) store.remove(key);
}
function quarantineLegacyJobs() {
  const oldJobs = store.get('jobs', []), oldHistory = store.get('history', {}), oldHunt = store.get('hunt', null);
  const activeKeys = new Set(oldHunt && ACTIVE.has(oldHunt.status) ? oldHunt.jobKeys ?? [] : []);
  const quarantined = new Map();
  for (const [key, result] of Object.entries(oldHistory)) {
    if (result?.status === 'submitted') quarantined.set(key, 'submitted');
    else if (result?.status && result.status !== 'dry_run') quarantined.set(key, 'needs_review');
  }
  for (const key of activeKeys) if (quarantined.get(key) !== 'submitted') quarantined.set(key, 'needs_review');
  const jobs = new Map(state.jobs.map(job => [job.key, job]));
  for (const oldJob of oldJobs) if (!jobs.has(oldJob.key) && jobs.size < 1000) jobs.set(oldJob.key, { ...oldJob });
  for (const [key, legacyStatus] of quarantined) {
    const job = jobs.get(key);
    if (job) job.legacyStatus = job.legacyStatus === 'submitted' || legacyStatus === 'submitted' ? 'submitted' : 'needs_review';
  }
  state.jobs = [...jobs.values()];
  state.legacyPending = oldJobs.length > 0 || Object.keys(oldHistory).length > 0 || !!oldHunt;
  state.legacyUnresolved = [...quarantined.keys()].some(key => !jobs.has(key));
  return state.legacyPending;
}
function rememberHunts(hunts) {
  state.hunts = [...hunts].sort((a, b) => b.createdAt.localeCompare(a.createdAt)); state.history = {};
  const jobs = new Map(state.jobs.map(job => [job.key, job]));
  for (const hunt of [...state.hunts].reverse()) for (const job of hunt.jobs) {
    if (!jobs.has(job.key)) jobs.set(job.key, job);
    const result = hunt.results[job.key];
    if (result) state.history[job.key] = { ...result, submissionAttempted: !!state.history[job.key]?.submissionAttempted || !!result.submissionAttempted, huntId: hunt.id };
    else if (ACTIVE.has(hunt.status)) state.history[job.key] = { status: 'queued', message: '', huntId: hunt.id };
  }
  state.jobs = [...jobs.values()];
  const current = state.hunts.find(hunt => ACTIVE.has(hunt.status)) ?? state.hunts[0];
  state.hunt = current ? { id: current.id, jobKeys: current.jobs.map(job => job.key), status: current.status } : null;
}
async function loadApplication() {
  if (state.loading) return state.loading;
  if (!$('#code').value.trim()) { $('#application-status').textContent = 'Enter your access code above, then open your saved application.'; return; }
  if (state.dirty && !window.confirm('Open the last saved version? Changes you have not saved will be replaced.')) return;
  state.loaded = false; clearTimeout(state.timer); $('#application-status').textContent = 'Opening your private application…';
  state.loading = busy(async () => {
    try {
      await state.saveQueue.catch(() => {});
      const { application, hunts } = await api('/api/application');
      state.profile = application?.profile ?? null; state.facts = application?.facts ?? emptyFacts(); state.resume = application?.resume ?? null; state.jobs = application?.jobs ?? []; state.preferences = application?.preferences ?? emptyPreferences(); state.updatedAt = application?.updatedAt ?? null;
      let legacy = false;
      if (!application) {
        const oldProfile = store.get('profile', null), oldResume = store.get('resume', null);
        if (oldProfile || oldResume) { state.profile = oldProfile; state.facts = store.get('facts', emptyFacts()); state.resume = oldResume; state.jobs = store.get('jobs', []); state.preferences.titles = oldProfile?.targetTitles ?? []; state.preferences.companies = store.get('companies', []); legacy = true; }
      }
      rememberHunts(hunts ?? []);
      const legacyJobs = quarantineLegacyJobs();
      state.loaded = true; state.dirty = legacy || legacyJobs; state.resumeDirty = legacy && !!state.resume;
      $('#real').checked = false; $('#consent').checked = false; showProfile(); showPreferences();
      $('#resume-status').textContent = state.resume ? `${state.resume.name} · ${legacy ? 'browser draft' : 'saved privately'}. Drop another to replace it.` : 'PDF, up to 5 MB';
      $('#application-status').textContent = legacy || legacyJobs ? 'Found a browser draft. Previous application attempts are protected from retries. Choose Save application to store this record privately online.' : application ? `Saved application opened. Last saved ${dateLabel(state.updatedAt)}.` : 'Your private workspace is ready. Upload a resume or enter your profile below.';
      $('#profile-status').textContent = ''; $('#search-status').textContent = ''; render(); if (!state.preferences.companies.length) loadCompanies(); poll();
    } catch (error) { $('#application-status').textContent = `Could not open your saved application. ${error.message}`; }
  });
  try { await state.loading; } finally { state.loading = null; updateControls(); }
}
async function persistApplication({ includeResume = false } = {}) {
  await ensureLoaded(); readProfile(); if (state.legacyPending) quarantineLegacyJobs(); if (!emailValid()) throw new Error('Check the email address in your profile.');
  const body = { profile: state.profile, facts: state.facts, preferences: state.preferences, jobs: state.jobs }; if (includeResume || state.resumeDirty) body.resume = state.resume;
  // Each queued version is captured now, so a slow earlier save cannot replace a later one.
  const snapshot = structuredClone(body), revision = state.revision;
  const saving = state.saveQueue.catch(() => {}).then(() => api('/api/application', snapshot)); state.saveQueue = saving;
  const { updatedAt } = await saving; state.updatedAt = updatedAt; if (state.revision === revision) state.dirty = false; if ('resume' in snapshot) state.resumeDirty = false;
  let clearLegacy = !state.legacyPending;
  if (state.legacyPending && !state.legacyUnresolved) {
    const { application } = await api('/api/application');
    const savedJobs = new Map((application?.jobs ?? []).map(job => [job.key, job]));
    const verified = snapshot.jobs.every(job => savedJobs.has(job.key) && (!job.legacyStatus || savedJobs.get(job.key).legacyStatus === job.legacyStatus));
    if (!verified) { state.dirty = true; throw new Error('Your draft was saved, but previous application records could not be verified. They remain in this browser; save again before switching devices.'); }
    clearLegacy = true; state.legacyPending = false;
  }
  removeLegacyDraft(clearLegacy);
  $('#application-status').textContent = `Saved privately online · ${dateLabel(updatedAt)}.` + (state.dirty ? ' You have newer unsaved changes.' : ' Results appear here; email delivery is not connected yet.') + (state.legacyUnresolved ? ' Some older attempts have no saved job link; their records remain in this browser.' : '');
}
async function saveApplication() { return busy(async () => { $('#profile-status').textContent = 'Saving your application…'; try { await persistApplication({ includeResume: !!state.resume && !state.updatedAt }); $('#profile-status').textContent = state.dirty ? 'Saved online. You have newer unsaved changes.' : 'Application saved online.'; } catch (error) { $('#profile-status').textContent = `Not saved. ${error.message}`; } }); }
async function copyRecoveryKey() {
  try { await navigator.clipboard.writeText(workspaceKey); $('#application-status').textContent = 'Recovery key copied. Keep it private; it opens your application with the access code.'; }
  catch { $('#application-status').textContent = 'Clipboard access was unavailable. Allow clipboard access in your browser, then try again.'; }
}
async function restoreApplication() {
  const entered = window.prompt('Paste the private recovery key from your other browser. It is 64 characters. Keep the access code entered above.'); if (entered === null) return;
  const key = entered.trim().toLowerCase();
  if (!/^[0-9a-f]{64}$/.test(key)) { $('#application-status').textContent = 'That recovery key is not valid. Copy the full key from your original browser.'; return; }
  if (state.dirty && !window.confirm('Switch workspaces? Save your current changes first if you want to keep them.')) return;
  return busy(async () => {
    try {
      const saved = await api('/api/application', undefined, 'GET', key);
      if (!saved.application && !saved.hunts?.length) { $('#application-status').textContent = 'No saved application was found for that recovery key. Your current workspace is still open.'; return; }
      clearTimeout(state.timer); workspaceKey = key; store.set('workspace-key', key); state.dirty = false; await loadApplication();
    } catch (error) { $('#application-status').textContent = `Could not restore the application. ${error.message}`; }
  });
}
async function deleteApplication() {
  if (!window.confirm('Delete your saved resume, profile, preferences and application history? Running scouts will be stopped. Applications already sent to employers cannot be withdrawn here.')) return;
  return busy(async () => {
    try {
      await ensureLoaded(); await state.saveQueue.catch(() => {}); await api('/api/application', undefined, 'DELETE'); clearTimeout(state.timer); removeLegacyDraft(true);
      state.profile = null; state.resume = null; state.resumeDirty = false; state.facts = emptyFacts(); state.jobs = []; state.history = {}; state.hunt = null; state.hunts = []; state.preferences = emptyPreferences(); state.updatedAt = null; state.dirty = false; state.legacyPending = false; state.legacyUnresolved = false;
      $('#real').checked = false; $('#consent').checked = false; $('#resume').value = ''; $('#resume-status').textContent = 'PDF, up to 5 MB'; $('#profile-status').textContent = ''; $('#run-status').textContent = '';
      showProfile(); showPreferences(); render(); $('#application-status').textContent = 'Your saved application and history were deleted. You can start again in this workspace.';
    } catch (error) { $('#application-status').textContent = `Could not delete your application. ${error.message}`; }
  });
}

/* Resume intake: save the PDF before asking AI to read it. */
function readFile(file) { return new Promise((resolve, reject) => { const reader = new FileReader(); reader.onload = () => resolve(String(reader.result).split(',')[1]); reader.onerror = () => reject(new Error('The PDF could not be read. Try selecting it again.')); reader.readAsDataURL(file); }); }
async function useResume(file) {
  const status = $('#resume-status'); if (!file) return;
  if ((file.type && file.type !== 'application/pdf') || file.size > 5_000_000) { status.textContent = 'Please choose a PDF under 5 MB.'; return; }
  return busy(async () => {
    try { await ensureLoaded(); status.textContent = `Saving ${file.name}…`; state.resume = { name: file.name, base64: await readFile(file) }; state.resumeDirty = true; await persistApplication({ includeResume: true }); }
    catch (error) { status.textContent = `Resume not saved. ${error.message}`; return; }
    status.textContent = `${file.name} saved. Reading your profile…`;
    try {
      const { profile } = await api('/api/profile', { resume: state.resume.base64 }); state.profile = profile;
      if (!state.preferences.titles.length) state.preferences.titles = profile.targetTitles;
      showProfile(); showPreferences(); await persistApplication(); status.textContent = `${file.name} and your profile are saved. Review the details below.`;
    } catch (error) { state.profile ??= emptyProfile(); showProfile(); status.textContent = `Your PDF is saved. Automatic reading was unavailable. ${error.message} Enter your profile below and save it.`; }
    $('#profile-section').scrollIntoView({ block: 'start' });
  });
}

/* Search */
async function loadCompanies() { try { const result = await api('/api/companies'); if (!$('#companies').value.trim()) $('#companies').value = result.companies.join('\n'); } catch {} }
function mergeJobs(jobs) { const known = new Set(state.jobs.map(job => job.key)), added = []; for (const job of jobs) if (!known.has(job.key)) { known.add(job.key); added.push(job); } const accepted = added.slice(0, Math.max(0, 1000 - state.jobs.length)); state.omittedJobs = added.length - accepted.length; state.jobs.push(...accepted); if (state.legacyPending) quarantineLegacyJobs(); state.dirty = true; render(); return accepted.length; }
const jobLimitNotice = () => state.omittedJobs ? ` ${state.omittedJobs} more jobs were left out because this workspace holds up to 1,000 jobs.` : '';
async function search() {
  return busy(async () => {
    const status = $('#search-status'); status.textContent = 'Saving your preferences and searching the boards…';
    try { await persistApplication(); const result = await api('/api/jobs', state.preferences); const added = mergeJobs(result.jobs); await persistApplication(); status.textContent = `${result.searched} boards searched: ${result.jobs.length} matches, ${added} new. Saved online.` + jobLimitNotice() + (result.skipped.length ? ` Skipped: ${result.skipped.join(', ')}.` : ''); }
    catch (error) { status.textContent = error.message; }
  });
}
async function addLinks() {
  return busy(async () => {
    const status = $('#search-status'); status.textContent = 'Adding your job links…';
    try { await ensureLoaded(); const result = await api('/api/links', { links: list($('#links').value.replace(/\s+/g, '\n')) }); const added = mergeJobs(result.jobs); await persistApplication(); status.textContent = `Added ${added} job(s) and saved online.` + jobLimitNotice() + (result.invalid.length ? ` Not supported: ${result.invalid.join(', ')}.` : ''); }
    catch (error) { status.textContent = `Could not save your job links. ${error.message}`; }
  });
}

/* Hunt */
const resultFor = job => job.legacyStatus ? { legacyStatus: job.legacyStatus, status: job.legacyStatus === 'submitted' ? 'submitted' : 'needs_you', submissionAttempted: job.legacyStatus === 'needs_review', message: 'Imported from your previous browser record. Automatic retries are blocked; check the employer application directly.' } : state.history[job.key];
const statusOf = job => resultFor(job)?.status;
const cannotRetry = job => !!job.legacyStatus || statusOf(job) === 'submitted' || !!state.history[job.key]?.submissionAttempted;
function selectedJobs() { const keys = new Set(Array.from(document.querySelectorAll('#jobs input[type=checkbox]:checked')).map(box => box.dataset.key)); return state.jobs.filter(job => keys.has(job.key) && !cannotRetry(job)); }
async function startHunt() {
  return busy(async () => {
    const status = $('#run-status');
    try {
      await ensureLoaded(); readProfile();
      if (!state.profile?.fullName) { status.textContent = 'Enter your full name in the profile first.'; return; }
      if (!emailValid(true)) { status.textContent = 'Enter a valid contact email in your profile first.'; return; }
      if (!$('#consent').checked) { status.textContent = 'Tick the authorization box first.'; return; }
      if (!state.resume) { status.textContent = 'Upload your resume first.'; return; }
      const jobs = selectedJobs(); if (!jobs.length) { status.textContent = 'Pick at least one job.'; return; }
      status.textContent = 'Saving your application and starting the scout…'; await persistApplication();
      const submit = $('#real').checked;
      const { id } = await api('/api/hunts', { jobs, profile: state.profile, facts: state.facts, resume: state.resume, submit, consent: true });
      state.hunt = { id, jobKeys: jobs.map(job => job.key), status: 'queued' }; state.hunts.unshift({ id, jobs, submit, createdAt: new Date().toISOString(), results: {}, status: 'queued' });
      for (const job of jobs) state.history[job.key] = { status: 'queued', message: '', huntId: id };
      $('#consent').checked = false; render(); poll();
    } catch (error) { status.textContent = `The scout did not start. ${error.message}`; }
  });
}
async function poll() {
  clearTimeout(state.timer); const hunt = state.hunt; if (!state.loaded || !hunt || !ACTIVE.has(hunt.status)) return;
  let failure = '';
  try {
    const data = await api(`/api/hunts/${hunt.id}`); if (state.hunt !== hunt || !state.loaded) return;
    hunt.status = data.status; const record = state.hunts.find(entry => entry.id === hunt.id); if (record) { record.status = data.status; record.results = data.results; }
    for (const [key, result] of Object.entries(data.results)) state.history[key] = { ...result, huntId: hunt.id };
    if (!ACTIVE.has(hunt.status)) for (const key of hunt.jobKeys) if (state.history[key]?.status === 'queued') delete state.history[key];
  } catch (error) { failure = `Status unavailable. ${error.message} Your saved application is still here.`; }
  render(); if (failure) $('#run-status').textContent = failure;
  if (ACTIVE.has(hunt.status) && document.visibilityState === 'visible') state.timer = setTimeout(poll, 8000);
}
async function stopHunt() { if (!state.hunt) return; return busy(async () => { try { await api(`/api/hunts/${state.hunt.id}/stop`, {}); state.hunt.status = 'unknown'; await poll(); } catch (error) { $('#run-status').textContent = error.message; } }); }
async function showShot(job) {
  const entry = state.history[job.key];
    try { const response = await fetch(`/api/hunts/${entry.huntId}/shots/${encodeURIComponent(job.key)}`, { headers: headers() }); if (!response.ok) throw new Error('The screenshot is unavailable or has expired.'); const img = $('#shot img'); if (img.src.startsWith('blob:')) URL.revokeObjectURL(img.src); img.src = URL.createObjectURL(await response.blob()); img.hidden = false; $('#shot').showModal(); }
  catch (error) { $('#run-status').textContent = error.message; }
}

/* Rendering */
function renderSky() {
  const items = state.jobs.map(job => ({ key: job.key, status: statusOf(job), uncertain: !!resultFor(job)?.submissionAttempted && statusOf(job) !== 'submitted', at: resultFor(job)?.at, label: `${job.title || 'Job from link'} · ${job.company} — ${resultLabel(resultFor(job))}` }));
  Sky.huntSky($('#hunt-sky'), items, key => { const row = document.querySelector(`#jobs li[data-key="${CSS.escape(key)}"]`); if (!row) return; row.scrollIntoView({ block: 'center' }); row.classList.add('flash'); setTimeout(() => row.classList.remove('flash'), 1200); });
  const count = status => items.filter(item => item.status === status && !item.uncertain).length;
  const open = items.filter(item => !item.uncertain && (!item.status || item.status === 'queued' || item.status === 'working')).length;
  const parts = [['submitted', count('submitted'), 'submitted'], ['needs_you', count('needs_you'), 'need you'], ['failed', count('failed'), 'failed'], ['queued', open, 'not submitted']];
  if (count('dry_run')) parts.splice(3, 0, ['dry_run', count('dry_run'), 'dry runs']);
  const uncertain = items.filter(item => item.uncertain).length;
  if (uncertain) parts.splice(1, 0, ['needs_you', uncertain, 'unconfirmed']);
  $('#counts').replaceChildren(...parts.map(([status, n, word]) => el('li', {}, el('span', { className: `glyph ${status}`, textContent: GLYPHS[status], ariaHidden: 'true' }), el('b', { textContent: String(n) }), word)));
  $('#sky-summary').textContent = parts.map(([, n, word]) => `${n} ${word}`).join(', ');
}
function renderJobs() {
  const ul = $('#jobs'); ul.replaceChildren();
  for (const job of state.jobs) {
    const done = resultFor(job), blocked = cannotRetry(job);
    const box = el('input', { type: 'checkbox', checked: !job.unselected && !blocked, disabled: blocked }); box.dataset.key = job.key;
    box.addEventListener('change', () => { job.unselected = !box.checked; state.dirty = true; state.revision++; $('#profile-status').textContent = 'You have unsaved changes.'; countSelected(); });
    const href = safeHref(job.url) || safeHref(job.applyUrl), title = job.title || 'Job from link', details = el('div', { className: 'result' });
    if (done) {
      details.append(el('span', { className: 'badge' }, el('span', { className: `glyph ${done.status}`, textContent: GLYPHS[done.status] ?? '·', ariaHidden: 'true' }), resultLabel(done)), done.message);
      if (done.submissionAttempted && done.status !== 'submitted' && !done.legacyStatus) details.append(el('p', { textContent: 'A submission was attempted. Check the employer form before retrying; automatic retries are blocked.' }));
      if (done.missing?.length) details.append(el('ul', {}, ...done.missing.map(missing => el('li', { textContent: `${missing.label} — ${missing.note}` }))));
      if (done.hasShot) { const view = el('button', { type: 'button', className: 'link', textContent: 'View screenshot' }); view.addEventListener('click', () => showShot(job)); details.append(' ', view); }
      if ((done.legacyStatus || ['needs_you', 'failed', 'dry_run'].includes(done.status)) && safeHref(job.applyUrl)) details.append(' · ', el('a', { href: job.applyUrl, target: '_blank', rel: 'noopener', textContent: 'Open the form' }));
    }
    const row = el('li', {}, el('label', { className: 'check' }, box, el('span', {}, href ? el('a', { className: 'job-title', href, target: '_blank', rel: 'noopener', textContent: title }) : el('span', { className: 'job-title', textContent: title }), el('span', { className: 'job-where', textContent: ` · ${[job.company, job.location].filter(Boolean).join(' · ')}` }))), details);
    row.dataset.key = job.key; ul.append(row);
  }
  countSelected();
}
function countSelected() { $('#selected-count').textContent = `${selectedJobs().length} selected`; }
function renderHistory() {
  $('#history-section').hidden = state.hunts.length === 0;
  $('#hunt-history').replaceChildren(...state.hunts.map(hunt => {
    const counts = {}; for (const result of Object.values(hunt.results)) { const label = resultLabel(result).toLowerCase(); counts[label] = (counts[label] ?? 0) + 1; }
    const outcomes = Object.entries(counts).map(([label, count]) => `${count} ${label}`).join(' · ');
    return el('li', {}, el('strong', { textContent: hunt.submit ? 'Application run' : 'Dry run' }), el('span', { className: 'hint', textContent: `${dateLabel(hunt.createdAt)} · ${hunt.status} · ${hunt.jobs.length} jobs` }), el('p', { textContent: outcomes || 'No completed applications yet.' }));
  }));
}
function render() {
  $('#jobs-section').hidden = state.jobs.length === 0; renderSky(); renderJobs(); renderHistory(); updateControls();
  const hunt = state.hunt;
  if (hunt) { const results = hunt.jobKeys.map(key => state.history[key]?.status), finished = results.filter(status => status && status !== 'queued' && status !== 'working').length; $('#run-status').textContent = ACTIVE.has(hunt.status) ? `Scouting: ${finished} of ${hunt.jobKeys.length} processed. You can close this tab and return here.` : hunt.status === 'complete' ? `The scout is back: ${finished} of ${hunt.jobKeys.length} processed. Check each result below.` : `The scout stopped (${hunt.status}) after processing ${finished} of ${hunt.jobKeys.length}.`; }
}

/* Wiring */
function init() {
  Sky.starfield($('#starfield')); Sky.northStar($('#north-star')); $('#code').value = store.get('code', '');
  $('#code').addEventListener('change', () => { store.set('code', $('#code').value.trim()); loadApplication(); });
  $('#open-application').addEventListener('click', loadApplication); $('#copy-recovery').addEventListener('click', copyRecoveryKey); $('#restore-application').addEventListener('click', restoreApplication); $('#delete-application').addEventListener('click', deleteApplication);
  const drop = $('#drop'); $('#resume').addEventListener('change', event => useResume(event.target.files[0]));
  drop.addEventListener('dragover', event => { event.preventDefault(); drop.classList.add('over'); }); drop.addEventListener('dragleave', () => drop.classList.remove('over')); drop.addEventListener('drop', event => { event.preventDefault(); drop.classList.remove('over'); if (state.loaded && !state.busy) useResume(event.dataTransfer.files[0]); });
  $('#manual-profile').addEventListener('click', () => { if (!state.profile) { state.profile = emptyProfile(); state.dirty = true; showProfile(); } $('#profile-section').scrollIntoView({ block: 'start' }); $('[data-p="fullName"]').focus({ preventScroll: true }); });
  $('#save-profile').addEventListener('click', saveApplication); $('#search').addEventListener('click', search); $('#add-links').addEventListener('click', addLinks); $('#start').addEventListener('click', startHunt); $('#stop').addEventListener('click', stopHunt);
  $('#real').checked = false; $('#consent').checked = false;
  $('#select-all').addEventListener('change', event => { for (const job of state.jobs) if (!cannotRetry(job)) job.unselected = !event.target.checked; state.dirty = true; state.revision++; $('#profile-status').textContent = 'You have unsaved changes.'; renderJobs(); });
  for (const field of document.querySelectorAll('[data-p], [data-f], #titles, #locations, #exclude, #companies')) field.addEventListener('input', () => { state.dirty = true; state.revision++; $('#profile-status').textContent = 'You have unsaved changes.'; });
  document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible') poll(); }); let resizeTimer; window.addEventListener('resize', () => { clearTimeout(resizeTimer); resizeTimer = setTimeout(renderSky, 200); });
  $('#shot').addEventListener('close', () => { const img = $('#shot img'); if (img.src.startsWith('blob:')) { URL.revokeObjectURL(img.src); img.removeAttribute('src'); img.hidden = true; } });
  render(); if ($('#code').value) loadApplication();
}
init();
