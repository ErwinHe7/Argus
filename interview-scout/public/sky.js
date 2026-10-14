'use strict';

// The art: a background starfield, the Big Dipper pointing to the North Star,
// and the hunt sky where every job is a star.
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

  // The Big Dipper in a 400 x 440 box. Its pointer stars, Merak and Dubhe,
  // line up with Polaris, the North Star scouts steer by.
  const DIPPER = {
    alkaid: [44, 286], mizar: [96, 246], alcor: [103, 233], alioth: [146, 232],
    megrez: [196, 244], phecda: [206, 314], merak: [288, 322], dubhe: [298, 238],
  };
  const POLARIS = [318, 78];
  const LINKS = [
    ['alkaid', 'mizar'], ['mizar', 'alioth'], ['alioth', 'megrez'],
    ['megrez', 'dubhe'], ['dubhe', 'merak'], ['merak', 'phecda'], ['phecda', 'megrez'],
  ];
  const SIZE = { alkaid: 4, mizar: 4, alcor: 1.6, alioth: 4.4, megrez: 3, phecda: 3.8, merak: 4, dubhe: 4.6 };

  function northStar(svg) {
    LINKS.forEach(([a, b], i) => {
      const line = node('line', { class: 'link', x1: DIPPER[a][0], y1: DIPPER[a][1], x2: DIPPER[b][0], y2: DIPPER[b][1] }, svg);
      line.style.animationDelay = `${(i * 0.12).toFixed(2)}s`;
    });
    node('line', { class: 'guide', x1: DIPPER.dubhe[0], y1: DIPPER.dubhe[1] - 10, x2: POLARIS[0], y2: POLARIS[1] + 16 }, svg);
    const rand = random(11);
    for (const [name, [x, y]] of Object.entries(DIPPER)) {
      const star = node('circle', { class: 'star twinkle', cx: x, cy: y, r: SIZE[name] }, svg);
      star.style.animationDelay = `${(rand() * 4.5).toFixed(2)}s`;
    }
    const [px, py] = POLARIS;
    const glow = node('radialGradient', { id: 'polaris-glow' }, node('defs', {}, svg));
    node('stop', { class: 'glow-core', offset: '0%' }, glow);
    node('stop', { class: 'glow-edge', offset: '100%' }, glow);
    node('circle', { class: 'goal-halo', cx: px, cy: py, r: 34 }, svg);
    node('path', { class: 'goal', d: sparkle(px, py, 13) }, svg);
    node('text', { class: 'name goal-name', x: px + 20, y: py - 14 }, svg).textContent = 'Polaris';
    node('text', { class: 'name', x: 304, y: 288 }, svg).textContent = 'the pointer stars';
    node('text', { class: 'name', x: 56, y: 330 }, svg).textContent = 'the Big Dipper';
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

  return { starfield, northStar, huntSky };
})();
