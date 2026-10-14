'use strict';

const $ = selector => document.querySelector(selector);
const store = {
  get(key, fallback) {
    try {
      const value = localStorage.getItem('hunter:' + key);
      return value === null ? fallback : JSON.parse(value);
    } catch {
      return fallback;
    }
  },
  set(key, value) {
    try {
      localStorage.setItem('hunter:' + key, JSON.stringify(value));
      return true;
    } catch {
      return false;
    }
  },
};

const state = {
  profile: store.get('profile', null),
  facts: store.get('facts', { workAuthorizedUS: '', needsSponsorship: '', notes: '' }),
  resume: store.get('resume', null),
  jobs: store.get('jobs', []),
  history: store.get('history', {}),
  hunt: store.get('hunt', null), // { id, jobKeys, status }
  timer: null,
};

const ACTIVE = new Set(['queued', 'running', 'waiting', 'waitingForPause', 'paused', 'unknown']);
const LABELS = { submitted: 'Submitted', dry_run: 'Dry run', needs_you: 'Needs you', failed: 'Failed', working: 'Applying now', queued: 'In line' };
const GLYPHS = { submitted: '✦', dry_run: '◌', needs_you: '◎', failed: '✕', working: '●', queued: '·' };

const list = text => text.split(/[,\n]/).map(s => s.trim()).filter(Boolean);

async function api(path, body) {
  const response = await fetch(path, {
    method: body ? 'POST' : 'GET',
    headers: { 'content-type': 'application/json', 'x-access-code': $('#code').value },
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || `Request failed (${response.status}).`);
  return data;
}

function el(tag, props = {}, ...children) {
  const node = Object.assign(document.createElement(tag), props);
  node.append(...children.filter(c => c != null && c !== false));
  return node;
}

const safeHref = url => (/^https:\/\//.test(url) ? url : null);

/* Profile */

function showProfile() {
  for (const field of document.querySelectorAll('[data-p]')) {
    const value = state.profile?.[field.dataset.p] ?? '';
    field.value = Array.isArray(value) ? value.join(', ') : value;
  }
  for (const field of document.querySelectorAll('[data-f]')) field.value = state.facts[field.dataset.f] ?? '';
  $('#profile-section').hidden = false;
  $('#search-section').hidden = false;
  if (!$('#titles').value) $('#titles').value = (state.profile?.targetTitles ?? []).join(', ');
}

function saveProfile() {
  if (!state.profile) return;
  const profile = { ...state.profile };
  for (const field of document.querySelectorAll('[data-p]')) profile[field.dataset.p] = 'list' in field.dataset ? list(field.value) : field.value.trim();
  const facts = {};
  for (const field of document.querySelectorAll('[data-f]')) facts[field.dataset.f] = field.value.trim();
  state.profile = profile;
  state.facts = facts;
  store.set('profile', profile);
  store.set('facts', facts);
}

function readFile(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result).split(',')[1]);
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(file);
  });
}

async function useResume(file) {
  const status = $('#resume-status');
  if (!file) return;
  if (file.type !== 'application/pdf' || file.size > 5_000_000) {
    status.textContent = 'Please choose a PDF under 5 MB.';
    return;
  }
  status.textContent = `Reading ${file.name}…`;
  try {
    const base64 = await readFile(file);
    state.resume = { name: file.name, base64 };
    const kept = store.set('resume', state.resume);
    const { profile } = await api('/api/profile', { resume: base64 });
    state.profile = profile;
    store.set('profile', profile);
    $('#titles').value = '';
    showProfile();
    status.textContent = `Using ${file.name}.` + (kept ? '' : ' It is too large to remember, so upload it again after reloading.');
    $('#profile-section').scrollIntoView({ block: 'start' });
  } catch (error) {
    status.textContent = error.message;
  }
}

/* Search */

function mergeJobs(jobs) {
  const known = new Set(state.jobs.map(j => j.key));
  const added = jobs.filter(j => !known.has(j.key));
  state.jobs = [...state.jobs, ...added];
  store.set('jobs', state.jobs);
  render();
  return added.length;
}

async function search() {
  saveProfile();
  const status = $('#search-status');
  status.textContent = 'Searching the boards…';
  try {
    const companies = list($('#companies').value);
    store.set('companies', companies);
    const result = await api('/api/jobs', {
      titles: list($('#titles').value), locations: list($('#locations').value), exclude: list($('#exclude').value), companies,
    });
    const added = mergeJobs(result.jobs);
    status.textContent = `${result.searched} boards searched: ${result.jobs.length} matches, ${added} new.`
      + (result.skipped.length ? ` Skipped: ${result.skipped.join(', ')}.` : '');
  } catch (error) {
    status.textContent = error.message;
  }
}

async function addLinks() {
  const status = $('#search-status');
  try {
    const result = await api('/api/links', { links: list($('#links').value.replace(/\s+/g, '\n')) });
    const added = mergeJobs(result.jobs);
    status.textContent = `Added ${added} job(s).` + (result.invalid.length ? ` Not supported: ${result.invalid.join(', ')}.` : '');
  } catch (error) {
    status.textContent = error.message;
  }
}

/* Hunt */

const statusOf = job => state.history[job.key]?.status;

function selectedJobs() {
  const keys = new Set(Array.from(document.querySelectorAll('#jobs input[type=checkbox]:checked')).map(b => b.dataset.key));
  return state.jobs.filter(j => keys.has(j.key) && statusOf(j) !== 'submitted');
}

function saveHistory() {
  store.set('history', state.history);
}

async function startHunt() {
  saveProfile();
  const status = $('#run-status');
  if (!$('#consent').checked) { status.textContent = 'Tick the authorization box first.'; return; }
  if (!state.resume) { status.textContent = 'Upload your resume first.'; return; }
  const jobs = selectedJobs();
  if (!jobs.length) { status.textContent = 'Pick at least one job.'; return; }
  $('#start').disabled = true;
  status.textContent = 'Sending the hunt out…';
  try {
    const { id } = await api('/api/hunts', { jobs, profile: state.profile, facts: state.facts, resume: state.resume, submit: $('#real').checked });
    state.hunt = { id, jobKeys: jobs.map(j => j.key), status: 'queued' };
    store.set('hunt', state.hunt);
    for (const job of jobs) state.history[job.key] = { status: 'queued', message: '', huntId: id };
    saveHistory();
    render();
    poll();
  } catch (error) {
    status.textContent = error.message;
    $('#start').disabled = false;
  }
}

async function poll() {
  clearTimeout(state.timer);
  const hunt = state.hunt;
  if (!hunt || !ACTIVE.has(hunt.status)) return;
  try {
    const data = await api(`/api/hunts/${hunt.id}`);
    hunt.status = data.status;
    for (const [key, result] of Object.entries(data.results)) state.history[key] = { ...result, huntId: hunt.id };
    if (!ACTIVE.has(hunt.status)) {
      // Jobs the hunt never reached go back to the open pile.
      for (const key of hunt.jobKeys) if (state.history[key]?.status === 'queued') delete state.history[key];
    }
    store.set('hunt', hunt);
    saveHistory();
  } catch (error) {
    $('#run-status').textContent = error.message;
  }
  render();
  if (ACTIVE.has(hunt.status) && document.visibilityState === 'visible') state.timer = setTimeout(poll, 8000);
}

async function stopHunt() {
  if (!state.hunt) return;
  $('#stop').disabled = true;
  try {
    await api(`/api/hunts/${state.hunt.id}/stop`, {});
  } catch (error) {
    $('#run-status').textContent = error.message;
  }
  // One more poll picks up the final status and results.
  state.hunt.status = 'unknown';
  poll();
}

async function showShot(job) {
  const entry = state.history[job.key];
  try {
    const response = await fetch(`/api/hunts/${entry.huntId}/shots/${encodeURIComponent(job.key)}`, { headers: { 'x-access-code': $('#code').value } });
    if (!response.ok) throw new Error('The screenshot has expired.');
    const img = $('#shot img');
    if (img.src.startsWith('blob:')) URL.revokeObjectURL(img.src);
    img.src = URL.createObjectURL(await response.blob());
    $('#shot').showModal();
  } catch (error) {
    $('#run-status').textContent = error.message;
  }
}

/* Rendering */

function renderSky() {
  const items = state.jobs.map(job => ({
    key: job.key,
    status: statusOf(job),
    at: state.history[job.key]?.at,
    label: `${job.title || 'Job from link'} · ${job.company} — ${LABELS[statusOf(job)] ?? 'Not started'}`,
  }));
  Sky.huntSky($('#hunt-sky'), items, key => {
    const row = document.querySelector(`#jobs li[data-key="${CSS.escape(key)}"]`);
    if (!row) return;
    row.scrollIntoView({ block: 'center' });
    row.classList.add('flash');
    setTimeout(() => row.classList.remove('flash'), 1200);
  });
  const count = status => items.filter(i => i.status === status).length;
  const open = items.filter(i => !i.status || i.status === 'queued' || i.status === 'working').length;
  const parts = [['submitted', count('submitted'), 'submitted'], ['needs_you', count('needs_you'), 'need you'], ['failed', count('failed'), 'failed'], ['queued', open, 'to go']];
  if (count('dry_run')) parts.splice(3, 0, ['dry_run', count('dry_run'), 'dry runs']);
  $('#counts').replaceChildren(...parts.map(([status, n, word]) =>
    el('li', {}, el('span', { className: `glyph ${status}`, textContent: GLYPHS[status], ariaHidden: 'true' }), el('b', { textContent: String(n) }), word)));
  $('#sky-summary').textContent = parts.map(([, n, word]) => `${n} ${word}`).join(', ');
}

function renderJobs() {
  const ul = $('#jobs');
  ul.replaceChildren();
  for (const job of state.jobs) {
    const done = state.history[job.key];
    const box = el('input', { type: 'checkbox', checked: !job.unselected && done?.status !== 'submitted' });
    box.dataset.key = job.key;
    box.addEventListener('change', () => { job.unselected = !box.checked; store.set('jobs', state.jobs); countSelected(); });
    const href = safeHref(job.url) || safeHref(job.applyUrl);
    const title = job.title || 'Job from link';
    const details = el('div', { className: 'result' });
    if (done) {
      details.append(el('span', { className: 'badge' }, el('span', { className: `glyph ${done.status}`, textContent: GLYPHS[done.status] ?? '·', ariaHidden: 'true' }), LABELS[done.status] ?? done.status), done.message);
      if (done.missing?.length) details.append(el('ul', {}, ...done.missing.map(m => el('li', { textContent: `${m.label} — ${m.note}` }))));
      if (done.hasShot) {
        const view = el('button', { type: 'button', className: 'link', textContent: 'View screenshot' });
        view.addEventListener('click', () => showShot(job));
        details.append(' ', view);
      }
      if (['needs_you', 'failed', 'dry_run'].includes(done.status) && safeHref(job.applyUrl)) {
        details.append(' · ', el('a', { href: job.applyUrl, target: '_blank', rel: 'noopener', textContent: 'Open the form' }));
      }
    }
    const li = el('li', {}, el('label', { className: 'check' }, box,
      el('span', {}, href ? el('a', { className: 'job-title', href, target: '_blank', rel: 'noopener', textContent: title }) : el('span', { className: 'job-title', textContent: title }),
        el('span', { className: 'job-where', textContent: ` · ${[job.company, job.location].filter(Boolean).join(' · ')}` }))),
    details);
    li.dataset.key = job.key;
    ul.append(li);
  }
  countSelected();
}

function countSelected() {
  $('#selected-count').textContent = `${selectedJobs().length} selected`;
}

function render() {
  $('#jobs-section').hidden = state.jobs.length === 0;
  renderSky();
  renderJobs();
  const hunt = state.hunt;
  const running = !!hunt && ACTIVE.has(hunt.status);
  $('#start').disabled = running;
  $('#stop').disabled = !running;
  if (hunt) {
    const results = hunt.jobKeys.map(k => state.history[k]?.status);
    const finished = results.filter(s => s && s !== 'queued' && s !== 'working').length;
    $('#run-status').textContent = running
      ? `Hunting: ${finished} of ${hunt.jobKeys.length} done. You can close this tab.`
      : hunt.status === 'complete' ? `The hunt is over: ${finished} of ${hunt.jobKeys.length} done.`
        : `The hunt stopped (${hunt.status}) after ${finished} of ${hunt.jobKeys.length}.`;
  }
}

/* Wiring */

function init() {
  Sky.starfield($('#starfield'));
  Sky.orion($('#orion'));
  $('#code').value = store.get('code', '');
  $('#code').addEventListener('change', () => store.set('code', $('#code').value));

  const drop = $('#drop');
  $('#resume').addEventListener('change', event => useResume(event.target.files[0]));
  drop.addEventListener('dragover', event => { event.preventDefault(); drop.classList.add('over'); });
  drop.addEventListener('dragleave', () => drop.classList.remove('over'));
  drop.addEventListener('drop', event => { event.preventDefault(); drop.classList.remove('over'); useResume(event.dataTransfer.files[0]); });

  $('#save-profile').addEventListener('click', () => { saveProfile(); $('#profile-status').textContent = 'Saved.'; });
  $('#search').addEventListener('click', search);
  $('#add-links').addEventListener('click', addLinks);
  $('#start').addEventListener('click', startHunt);
  $('#stop').addEventListener('click', stopHunt);
  $('#select-all').addEventListener('change', event => {
    for (const job of state.jobs) job.unselected = !event.target.checked;
    store.set('jobs', state.jobs);
    renderJobs();
  });
  document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible') poll(); });
  let resizeTimer;
  window.addEventListener('resize', () => { clearTimeout(resizeTimer); resizeTimer = setTimeout(renderSky, 200); });

  if (state.resume) $('#resume-status').textContent = `Using ${state.resume.name}. Drop another to replace it.`;
  if (state.profile) showProfile();
  render();
  poll();

  const saved = store.get('companies', null);
  if (saved) $('#companies').value = saved.join('\n');
  else api('/api/companies').then(r => { $('#companies').value = r.companies.join('\n'); }).catch(() => {});
}

init();
