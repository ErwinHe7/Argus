'use strict';

// The art: a background starfield, the Orion constellation, and the hunt sky
// where every job is a star.
const Sky = (() => {
  const NS = 'http://www.w3.org/2000/svg';
  const node = (tag, attrs = {}, parent) => {
    const el = document.createElementNS(NS, tag);
    for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, v);
    if (parent) parent.appendChild(el);
    return el;
  };

  function hash(text) {
    let h = 2166136261;
    for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 16777619);
    return (h >>> 0) / 4294967296;
  }

  function random(seed) {
    return () => {
      seed = (seed + 0x6d2b79f5) | 0;
      let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function starfield(svg) {
    svg.setAttribute('viewBox', '0 0 1600 1000');
    const rand = random(7);
    for (let i = 0; i < 170; i++) {
      const star = node('circle', {
        cx: (rand() * 1600).toFixed(1), cy: (rand() * 1000).toFixed(1),
        r: (0.4 + rand() * rand() * 1.4).toFixed(2), opacity: (0.12 + rand() * 0.5).toFixed(2),
      }, svg);
      if (i % 7 === 0) {
        star.setAttribute('class', 'twinkle');
        star.style.animationDelay = `${(rand() * 4.5).toFixed(2)}s`;
      }
    }
  }

  // Approximate shape of Orion, drawn in a 400 x 440 box.
  const ORION = {
    meissa: [205, 78], betelgeuse: [138, 136], bellatrix: [270, 150],
    alnitak: [180, 262], alnilam: [204, 254], mintaka: [228, 245],
    saiph: [158, 384], rigel: [286, 368],
    club1: [116, 96], club2: [102, 56], club3: [120, 24], club4: [146, 30],
    arm: [304, 156], shield1: [326, 96], shield2: [340, 130], shield3: [344, 168], shield4: [336, 206], shield5: [320, 238],
    sword1: [198, 296], sword2: [203, 318], sword3: [206, 340],
  };
  const LINKS = [
    ['meissa', 'betelgeuse'], ['meissa', 'bellatrix'], ['betelgeuse', 'alnitak'], ['bellatrix', 'mintaka'],
    ['alnitak', 'alnilam'], ['alnilam', 'mintaka'], ['alnitak', 'saiph'], ['mintaka', 'rigel'],
    ['betelgeuse', 'club1'], ['club1', 'club2'], ['club2', 'club3'], ['club3', 'club4'],
    ['bellatrix', 'arm'], ['arm', 'shield3'], ['shield1', 'shield2'], ['shield2', 'shield3'], ['shield3', 'shield4'], ['shield4', 'shield5'],
    ['alnilam', 'sword1'], ['sword1', 'sword2'], ['sword2', 'sword3'],
  ];
  const BRIGHT = { betelgeuse: [6, 'warm'], rigel: [6, 'cool'], bellatrix: [4.2], alnilam: [4], alnitak: [3.8], mintaka: [3.6], saiph: [3.8], meissa: [3] };

  function orion(svg) {
    const defs = node('defs', {}, svg);
    const nebula = node('radialGradient', { id: 'nebula' }, defs);
    node('stop', { offset: '0%', 'stop-color': '#d78bd0', 'stop-opacity': '.55' }, nebula);
    node('stop', { offset: '100%', 'stop-color': '#6c6ad8', 'stop-opacity': '0' }, nebula);
    node('ellipse', { class: 'nebula', cx: 203, cy: 318, rx: 34, ry: 24 }, svg);

    LINKS.forEach(([a, b], i) => {
      const line = node('line', { class: 'link', x1: ORION[a][0], y1: ORION[a][1], x2: ORION[b][0], y2: ORION[b][1] }, svg);
      line.style.animationDelay = `${(i * 0.07).toFixed(2)}s`;
    });
    const rand = random(11);
    for (const [name, [x, y]] of Object.entries(ORION)) {
      const [r = 2, tone = ''] = BRIGHT[name] ?? [];
      if (r > 5) node('circle', { class: 'halo', cx: x, cy: y, r: r * 3 }, svg);
      const star = node('circle', { class: `star ${tone} twinkle`, cx: x, cy: y, r }, svg);
      star.style.animationDelay = `${(rand() * 4.5).toFixed(2)}s`;
    }
    node('text', { class: 'name', x: 60, y: 150 }, svg).textContent = 'Betelgeuse';
    node('text', { class: 'name', x: 300, y: 398 }, svg).textContent = 'Rigel';
    node('text', { class: 'name', x: 242, y: 274 }, svg).textContent = 'the belt';
  }

  function sparkle(x, y, s) {
    return `M${x} ${y - s}Q${x} ${y} ${x + s} ${y}Q${x} ${y} ${x} ${y + s}Q${x} ${y} ${x - s} ${y}Q${x} ${y} ${x} ${y - s}Z`;
  }

  /**
   * items: [{ key, label, status, at }]. Submitted stars are tied to their
   * nearest earlier submitted star, so the hunt draws its own constellations.
   */
  function huntSky(svg, items, onPick) {
    svg.replaceChildren();
    // A taller sky on narrow screens keeps the stars large enough to read.
    const [W, H] = svg.clientWidth && svg.clientWidth < 600 ? [400, 340] : [800, 280];
    const PAD = 18;
    svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
    if (!items.length) {
      node('text', { class: 'empty', x: W / 2, y: H / 2 }, svg).textContent = 'Your sky fills in once you pick some jobs.';
      return;
    }
    const pos = item => [PAD + hash(item.key) * (W - 2 * PAD), PAD + hash(`${item.key}#`) * (H - 2 * PAD)];
    const lit = items.filter(i => i.status === 'submitted').sort((a, b) => (a.at ?? '').localeCompare(b.at ?? ''));
    const ties = node('g', {}, svg);
    lit.forEach((item, i) => {
      if (!i) return;
      const [x, y] = pos(item);
      let best = null;
      let bestD = Infinity;
      for (const prev of lit.slice(0, i)) {
        const [px, py] = pos(prev);
        const d = (px - x) ** 2 + (py - y) ** 2;
        if (d < bestD) { bestD = d; best = [px, py]; }
      }
      if (best && bestD < 160 ** 2) node('line', { class: 'tie', x1: x, y1: y, x2: best[0], y2: best[1] }, ties);
    });
    for (const item of items) {
      const [x, y] = pos(item);
      const g = node('g', {}, svg);
      switch (item.status) {
        case 'submitted':
          node('circle', { class: 's-glow', cx: x, cy: y, r: 10 }, g);
          node('path', { class: 's-submitted', d: sparkle(x, y, 7) }, g);
          break;
        case 'needs_you': node('circle', { class: 's-needs_you', cx: x, cy: y, r: 4.5 }, g); break;
        case 'failed': node('path', { class: 's-failed', d: `M${x - 3.5} ${y - 3.5}L${x + 3.5} ${y + 3.5}M${x + 3.5} ${y - 3.5}L${x - 3.5} ${y + 3.5}` }, g); break;
        case 'dry_run': node('circle', { class: 's-dry_run', cx: x, cy: y, r: 4.5 }, g); break;
        case 'working': node('circle', { class: 's-working', cx: x, cy: y, r: 3 }, g); break;
        default: node('circle', { class: 's-queued', cx: x, cy: y, r: 2.2 }, g);
      }
      const hit = node('circle', { class: 'hit', cx: x, cy: y, r: 11, tabindex: '-1' }, g);
      node('title', {}, hit).textContent = item.label;
      hit.addEventListener('click', () => onPick(item.key));
    }
  }

  return { starfield, orion, huntSky };
})();
