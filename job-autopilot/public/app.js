'use strict';

const $ = selector => document.querySelector(selector);
const store = {
  get(key, fallback) {
    try {
      const value = localStorage.getItem('autopilot:' + key);
      return value === null ? fallback : JSON.parse(value);
    } catch {
      return fallback;
    }
  },
  set(key, value) {
    try {
      localStorage.setItem('autopilot:' + key, JSON.stringify(value));
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
  running: false,
  stop: false,
};

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

function showProfile() {
  for (const el of document.querySelectorAll('[data-p]')) {
    const value = state.profile?.[el.dataset.p] ?? '';
    el.value = Array.isArray(value) ? value.join(', ') : value;
  }
  for (const el of document.querySelectorAll('[data-f]')) el.value = state.facts[el.dataset.f] ?? '';
  $('#profile-section').hidden = false;
  $('#search-section').hidden = false;
  if (!$('#titles').value) $('#titles').value = (state.profile?.targetTitles ?? []).join(', ');
}

function saveProfile() {
  const profile = { ...(state.profile ?? {}) };
  for (const el of document.querySelectorAll('[data-p]')) profile[el.dataset.p] = 'list' in el.dataset ? list(el.value) : el.value.trim();
  const facts = {};
  for (const el of document.querySelectorAll('[data-f]')) facts[el.dataset.f] = el.value.trim();
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

async function onResume(event) {
  const file = event.target.files[0];
  const status = $('#resume-status');
  if (!file) return;
  if (file.type !== 'application/pdf' || file.size > 5_000_000) {
    status.textContent = 'Please choose a PDF under 5 MB.';
    return;
  }
  status.textContent = 'Reading your resume…';
  try {
    const base64 = await readFile(file);
    state.resume = { name: file.name, base64 };
    const kept = store.set('resume', state.resume);
    const { profile } = await api('/api/profile', { resume: base64 });
    state.profile = profile;
    store.set('profile', profile);
    $('#titles').value = '';
    showProfile();
    status.textContent = `Loaded ${file.name}.` + (kept ? '' : ' It is too large to remember, so upload it again after reloading the page.');
  } catch (error) {
    status.textContent = error.message;
  }
}

function mergeJobs(jobs) {
  const known = new Set(state.jobs.map(j => j.key));
  const added = jobs.filter(j => !known.has(j.key));
  state.jobs = [...state.jobs, ...added];
  store.set('jobs', state.jobs);
  renderJobs();
  return added.length;
}

async function search() {
  saveProfile();
  const status = $('#search-status');
  status.textContent = 'Searching job boards…';
  try {
    const companies = list($('#companies').value);
    store.set('companies', companies);
    const result = await api('/api/jobs', {
      titles: list($('#titles').value), locations: list($('#locations').value), exclude: list($('#exclude').value), companies,
    });
    const added = mergeJobs(result.jobs);
    status.textContent = `Searched ${result.searched} companies: ${result.jobs.length} matches, ${added} new.`
      + (result.skipped.length ? ` Skipped (board not found): ${result.skipped.join(', ')}.` : '');
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

const LABELS = { submitted: 'Submitted', dry_run: 'Dry run', needs_you: 'Needs you', failed: 'Failed', working: 'Working…' };

function el(tag, props = {}, ...children) {
  const node = Object.assign(document.createElement(tag), props);
  node.append(...children.filter(c => c != null));
  return node;
}

const safeHref = url => (/^https:\/\//.test(url) ? url : null);

function renderJobs() {
  const ul = $('#jobs');
  ul.replaceChildren();
  for (const job of state.jobs) {
    const done = state.history[job.key];
    const box = el('input', { type: 'checkbox', checked: !job.unselected && done?.status !== 'submitted' });
    box.addEventListener('change', () => { job.unselected = !box.checked; store.set('jobs', state.jobs); countSelected(); });
    box.dataset.key = job.key;
    const title = job.title || 'Job from link';
    const href = safeHref(job.url) || safeHref(job.applyUrl);
    const where = [job.company, job.location].filter(Boolean).join(' · ');
    const details = el('div', { className: 'result' });
    if (done) {
      details.append(el('span', { className: `badge ${done.status}`, textContent: LABELS[done.status] ?? done.status }), ' ', done.message);
      if (done.missing?.length) {
        details.append(el('ul', {}, ...done.missing.map(m => el('li', { textContent: `${m.label} — ${m.note}` }))));
      }
      if (done.screenshot) {
        const view = el('button', { type: 'button', className: 'link', textContent: 'View screenshot' });
        view.addEventListener('click', () => { $('#shot img').src = done.screenshot; $('#shot').showModal(); });
        details.append(' ', view);
      }
      if (done.status !== 'submitted' && safeHref(job.applyUrl)) {
        details.append(' ', el('a', { href: job.applyUrl, target: '_blank', rel: 'noopener', textContent: 'Open the form' }));
      }
    }
    ul.append(el('li', {}, el('label', { className: 'inline' }, box,
      el('span', {}, href ? el('a', { href, target: '_blank', rel: 'noopener', textContent: title }) : title, el('span', { className: 'muted', textContent: ` ${where}` }))),
    details));
  }
  $('#jobs-section').hidden = state.jobs.length === 0;
  countSelected();
}

function selectedJobs() {
  const keys = new Set(Array.from(document.querySelectorAll('#jobs input[type=checkbox]:checked')).map(b => b.dataset.key));
  return state.jobs.filter(j => keys.has(j.key) && state.history[j.key]?.status !== 'submitted');
}

function countSelected() {
  $('#selected-count').textContent = `${selectedJobs().length} selected`;
}

async function start() {
  saveProfile();
  const status = $('#run-status');
  if (!$('#consent').checked) { status.textContent = 'Tick the authorization box first.'; return; }
  if (!state.resume) { status.textContent = 'Upload your resume first.'; return; }
  const jobs = selectedJobs();
  const submit = $('#real').checked;
  state.running = true;
  state.stop = false;
  $('#start').disabled = true;
  $('#stop').disabled = false;
  let done = 0;
  for (const job of jobs) {
    if (state.stop) break;
    status.textContent = `Applying ${done + 1} of ${jobs.length}: ${job.title || job.applyUrl}`;
    state.history[job.key] = { status: 'working', message: '' };
    renderJobs();
    let result;
    try {
      result = await api('/api/apply', { job, profile: state.profile, facts: state.facts, resume: state.resume, submit });
    } catch (error) {
      result = { status: 'failed', message: error.message, missing: [], screenshot: null };
    }
    state.history[job.key] = { ...result, at: new Date().toISOString() };
    // Screenshots are large; keep them for this session only.
    store.set('history', Object.fromEntries(Object.entries(state.history).map(([k, v]) => [k, { ...v, screenshot: null }])));
    done++;
    renderJobs();
  }
  const counts = jobs.reduce((acc, j) => ({ ...acc, [state.history[j.key]?.status]: (acc[state.history[j.key]?.status] ?? 0) + 1 }), {});
  status.textContent = `Done ${done} of ${jobs.length}. ` + Object.entries(counts).map(([k, v]) => `${LABELS[k] ?? k}: ${v}`).join(', ');
  state.running = false;
  $('#start').disabled = false;
  $('#stop').disabled = true;
}

async function init() {
  $('#code').value = store.get('code', '');
  $('#code').addEventListener('change', () => store.set('code', $('#code').value));
  $('#resume').addEventListener('change', onResume);
  $('#save-profile').addEventListener('click', () => { saveProfile(); $('#resume-status').textContent = 'Profile saved.'; });
  $('#search').addEventListener('click', search);
  $('#add-links').addEventListener('click', addLinks);
  $('#start').addEventListener('click', start);
  $('#stop').addEventListener('click', () => { state.stop = true; $('#run-status').textContent = 'Stopping after the current application…'; });
  $('#select-all').addEventListener('change', event => {
    for (const job of state.jobs) job.unselected = !event.target.checked;
    store.set('jobs', state.jobs);
    renderJobs();
  });
  if (state.resume) $('#resume-status').textContent = `Using ${state.resume.name}.`;
  if (state.profile) showProfile();
  renderJobs();
  const saved = store.get('companies', null);
  if (saved) $('#companies').value = saved.join('\n');
  else api('/api/companies').then(r => { $('#companies').value = r.companies.join('\n'); }).catch(() => {});
}

init();
