// Runs inside the application page. Kept as plain JavaScript source because
// bundler-inserted helpers would break functions serialized into the browser.
// Installing it is idempotent; after a navigation it must be installed again.
export const PAGE_SCRIPT = String.raw`(() => {
  if (window.__ap) return;
  const clean = t => (t || '').replace(/[\s ]+/g, ' ').trim();
  const textOf = el => clean(el ? el.innerText || el.textContent : '');
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  const visible = el => {
    if (!el) return false;
    const s = getComputedStyle(el);
    if (s.display === 'none' || s.visibility === 'hidden') return false;
    const r = el.getBoundingClientRect();
    return r.width > 0 && r.height > 0;
  };
  let seq = 0;
  const byId = id => document.querySelector('[data-ap-id="' + id + '"]');
  const labelEl = el => (el.id && document.querySelector('label[for="' + CSS.escape(el.id) + '"]')) || el.closest('label');

  function labelText(el) {
    const by = el.getAttribute('aria-labelledby');
    if (by) {
      const t = clean(by.split(/\s+/).map(id => textOf(document.getElementById(id))).join(' '));
      if (t) return t;
    }
    const l = labelEl(el);
    if (l && textOf(l)) return textOf(l);
    if (el.getAttribute('aria-label')) return clean(el.getAttribute('aria-label'));
    let node = el.parentElement;
    for (let depth = 0; node && depth < 4; depth++, node = node.parentElement) {
      const cand = node.querySelector('label, legend, [class*="label" i], [class*="question" i]');
      if (cand && !cand.contains(el) && textOf(cand)) return textOf(cand);
    }
    return clean(el.getAttribute('placeholder') || el.name || '');
  }

  const optionLabel = el => textOf(labelEl(el)) || clean(el.getAttribute('aria-label') || el.value);

  function groupLabel(inputs, options) {
    const fieldset = inputs[0].closest('fieldset');
    const legend = fieldset && fieldset.querySelector('legend');
    if (legend && textOf(legend)) return textOf(legend);
    let node = inputs[0].parentElement;
    while (node && !inputs.every(i => node.contains(i))) node = node.parentElement;
    for (let depth = 0; node && depth < 4; depth++, node = node.parentElement) {
      for (const c of node.querySelectorAll('label, legend, [class*="label" i], [class*="question" i], p, span, div')) {
        if (inputs.some(i => c.contains(i))) continue;
        const t = textOf(c);
        if (t && t.length < 500 && !options.includes(t)) return t;
      }
    }
    return clean(inputs[0].name);
  }

  const isRequired = (els, label) =>
    els.some(e => e.required || e.getAttribute('aria-required') === 'true') || /[*✱]|\(required\)/i.test(label);

  function extract() {
    const fields = [];
    const seen = new Set();
    const controls = Array.from(document.querySelectorAll('input, textarea, select'));
    for (const el of controls) {
      const tag = el.tagName.toLowerCase();
      let type = tag === 'select' ? 'select' : tag === 'textarea' ? 'textarea' : (el.getAttribute('type') || 'text').toLowerCase();
      if (['hidden', 'submit', 'button', 'reset', 'image', 'password', 'search'].includes(type) || el.disabled) continue;
      if (type === 'radio' || type === 'checkbox') {
        const group = el.name ? controls.filter(c => c.type === type && c.name === el.name && c.form === el.form) : [el];
        if (type === 'radio' || group.length > 1) {
          if (seen.has(group[0])) continue;
          seen.add(group[0]);
          if (!group.some(g => visible(g) || visible(labelEl(g)))) continue;
          const id = 'g' + seq++;
          const options = group.map(g => { g.dataset.apGroup = id; return optionLabel(g); });
          const label = groupLabel(group, options);
          fields.push({ id, type: type === 'radio' ? 'radio' : 'checkbox-group', label, required: isRequired(group, label), options });
          continue;
        }
        if (!visible(el) && !visible(labelEl(el))) continue;
      } else if (type !== 'file' && !visible(el)) {
        continue;
      }
      if (!['text', 'email', 'tel', 'url', 'number', 'date', 'textarea', 'select', 'checkbox', 'file'].includes(type)) type = 'text';
      if (el.getAttribute('role') === 'combobox' || el.getAttribute('aria-autocomplete') === 'list') type = 'combobox';
      const id = 'f' + seq++;
      el.dataset.apId = id;
      const label = type === 'file' ? fileLabel(el) : labelText(el);
      const options = tag === 'select'
        ? Array.from(el.options).filter(o => o.value !== '' && !o.disabled).map(o => clean(o.text)).slice(0, 300)
        : [];
      fields.push({ id, type, label, required: isRequired([el], label), options });
    }
    return fields;
  }

  function fileLabel(el) {
    let node = el.parentElement;
    for (let depth = 0; node && depth < 5; depth++, node = node.parentElement) {
      const t = textOf(node);
      if (t) return t.slice(0, 200);
    }
    return labelText(el);
  }

  const listbox = el => {
    const owned = el.getAttribute('aria-controls') || el.getAttribute('aria-owns');
    return (owned && document.getElementById(owned)) || document;
  };
  const visibleOptions = el => Array.from(listbox(el).querySelectorAll('[role="option"]')).filter(visible);

  async function comboOptions(id) {
    const el = byId(id);
    if (!el) return [];
    const control = el.closest('[class*="control" i]') || el;
    control.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
    el.focus();
    el.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }));
    await sleep(300);
    const options = visibleOptions(el).map(textOf).filter(Boolean).slice(0, 300);
    el.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
    el.blur();
    await sleep(50);
    return options;
  }

  function pick(id, value) {
    const el = byId(id);
    if (!el) return null;
    const want = clean(value).toLowerCase();
    const options = visibleOptions(el);
    const best = options.find(o => textOf(o).toLowerCase() === want)
      || options.find(o => textOf(o).toLowerCase().startsWith(want))
      || options.find(o => textOf(o).toLowerCase().includes(want));
    if (!best) return null;
    for (const type of ['mousedown', 'mouseup', 'click']) best.dispatchEvent(new MouseEvent(type, { bubbles: true }));
    return textOf(best);
  }

  function setValue(el, value) {
    const proto = el instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype
      : el instanceof HTMLSelectElement ? HTMLSelectElement.prototype : HTMLInputElement.prototype;
    el.focus();
    Object.getOwnPropertyDescriptor(proto, 'value').set.call(el, value);
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
    el.blur();
  }

  function fill(plan) {
    const failed = [];
    for (const f of plan) {
      try {
        if (f.type === 'combobox') continue;
        if (f.type === 'radio' || f.type === 'checkbox-group') {
          const inputs = Array.from(document.querySelectorAll('[data-ap-group="' + f.id + '"]'));
          for (const input of inputs) {
            const want = f.values.includes(optionLabel(input));
            if (want !== input.checked && (want || f.type === 'checkbox-group')) input.click();
          }
        } else if (f.type === 'checkbox') {
          const el = byId(f.id);
          if (el.checked !== (f.values.length > 0)) el.click();
        } else if (f.type === 'select') {
          const el = byId(f.id);
          const option = Array.from(el.options).find(o => clean(o.text) === f.values[0]);
          if (!option) throw new Error('option not found');
          setValue(el, option.value);
        } else {
          setValue(byId(f.id), f.values[0]);
        }
      } catch (error) {
        failed.push(f.id);
      }
    }
    return failed;
  }

  function attach(id, name, base64) {
    const el = byId(id);
    const binary = atob(base64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    const transfer = new DataTransfer();
    transfer.items.add(new File([bytes], name, { type: 'application/pdf' }));
    el.files = transfer.files;
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
    return el.files.length === 1;
  }

  function markSubmit() {
    const score = b => {
      const t = clean(b.innerText || b.value || b.getAttribute('aria-label'));
      return /submit/i.test(t) ? 3 : b.type === 'submit' ? 2 : /^apply\b/i.test(t) ? 1 : 0;
    };
    const candidates = Array.from(document.querySelectorAll('button, input[type="submit"]')).filter(visible);
    const best = candidates.map(b => [score(b), b]).filter(([s]) => s > 0).sort((a, b) => b[0] - a[0])[0];
    if (!best) return false;
    best[1].setAttribute('data-ap-submit', '1');
    return true;
  }

  function captcha() {
    return Array.from(document.querySelectorAll('iframe')).some(f => {
      const src = (f.getAttribute('src') || '') + ' ' + (f.getAttribute('title') || '');
      const r = f.getBoundingClientRect();
      return /recaptcha|hcaptcha|turnstile|challenges\.cloudflare|arkoselabs|funcaptcha/i.test(src)
        && !/size=invisible/i.test(src) && visible(f) && r.width >= 100 && r.height >= 50;
    });
  }

  function outcome() {
    const text = textOf(document.body);
    const errors = Array.from(document.querySelectorAll('[aria-invalid="true"], [class*="error" i], [role="alert"]'))
      .filter(visible).map(textOf).filter(t => t && t.length < 300);
    return {
      confirmed: /thank(s| you)[^.]{0,40}(appl|interest|submi)|application (was |has been )?(successfully )?(submitted|received)|we('ve| have) received your application|successfully submitted/i.test(text),
      formGone: !document.querySelector('[data-ap-submit]'),
      captcha: captcha(),
      errors: Array.from(new Set(errors)).slice(0, 5),
    };
  }

  window.__ap = { extract, comboOptions, pick, fill, attach, markSubmit, captcha, outcome,
    pageText: () => textOf(document.body).slice(0, 4000) };
})()`;
