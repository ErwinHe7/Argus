import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const repositoryRoot = new URL('../', import.meta.url);
const source = (relativePath) => readFile(new URL(relativePath, repositoryRoot), 'utf8');

test('research, astrology, plans, and membership routes are connected without dead anchors', async () => {
  const [shell, nav, footer, chat] = await Promise.all([
    source('components/AppShell.tsx'),
    source('components/Nav.tsx'),
    source('components/Footer.tsx'),
    source('components/AxioChat.tsx'),
  ]);

  assert.match(
    shell,
    /const isResearchHome =[\s\S]*pathname === '\/'[\s\S]*pathname === '\/acceptance\/research'/
  );
  for (const route of ['/', '/#research-workspace', '/apps/astrology', '/pricing', '/billing']) {
    assert.ok(nav.includes(`href="${route}"`), `Nav is missing ${route}`);
  }
  assert.match(footer, /\{ href: '\/#research-workspace', label: 'Research workspace' \}/);
  assert.match(footer, /\{ href: '\/apps\/astrology', label: 'Astrology app' \}/);
  assert.match(footer, /\{ href: '\/pricing', label: 'Plans' \}/);
  assert.match(footer, /\{ href: '\/billing', label: 'Membership' \}/);
  assert.doesNotMatch(`${nav}\n${footer}`, /\/#(?:overview|pricing)/);
  assert.match(chat, /href="\/pricing"/);
  assert.match(chat, /href="\/billing"/);
  assert.match(chat, /className=\{styles\.accountIdentity\}/);
  assert.match(chat, /aria-label="Sign in to AXIO7"/);
  assert.doesNotMatch(chat, /aria-label="Sign in with Google"/);
  assert.match(nav, /action="\/auth\/signout\?next=%2F"/);
  assert.match(nav, /method="post"/);
});

test('research chrome retains its shared palette while pricing uses the restrained dark theme', async () => {
  const [globals, chatStyles, chrome] = await Promise.all([
    source('app/globals.css'),
    source('components/AxioChat.module.css'),
    source('components/SiteChrome.module.css'),
  ]);

  for (const token of [
    '--ax-paper',
    '--ax-sidebar',
    '--ax-surface',
    '--ax-line',
    '--ax-ink',
    '--ax-muted',
    '--ax-accent',
  ]) {
    assert.ok(globals.includes(token), `Shared palette is missing ${token}`);
    assert.ok(
      chatStyles.includes(`var(${token})`) || chrome.includes(`var(${token})`),
      `Active UI does not consume ${token}`
    );
  }

  const pricingSurface = globals.slice(globals.lastIndexOf('html:has(.axio-pricing-shell)'));
  assert.match(pricingSurface, /color-scheme:\s*dark/);
  assert.match(pricingSurface, /--price-violet:\s*#a66bff/i);
  assert.match(pricingSurface, /Pricing: restrained dark product page/);
  assert.match(pricingSurface, /background:\s*#050506\s*!important/);
  assert.match(pricingSurface, /\.axio-plan-card--featured/);
  assert.match(chrome, /body:has\(\.axio-pricing-shell\)/);
  assert.doesNotMatch(chrome, /#080a08|#c9ff5e/i);
});

test('localized Paddle prices announce async updates without changing checkout behavior', async () => {
  const pricingClient = await source('app/pricing/PaddlePricingClient.tsx');

  assert.match(pricingClient, /aria-live="polite"/);
  assert.match(pricingClient, /aria-busy=\{previewState === 'loading'\}/);
  assert.match(pricingClient, /item\.formattedTotals\.subtotal/);
  assert.match(pricingClient, /displayMode: 'overlay'/);
  assert.match(pricingClient, /variant: 'one-page'/);
  assert.match(pricingClient, /new URL\('\/welcome', window\.location\.origin\)/);
});

test('missing Paddle runtime configuration never removes membership actions', async () => {
  const pricing = await source('app/pricing/page.tsx');

  assert.match(pricing, /function PaddlePricingFallback/);
  assert.match(pricing, /PADDLE_TIERS\.map/);
  assert.match(pricing, /href=\{`\$\{LIVE_PRICING_URL\}\?plan=\$\{tier\.key\}`\}/);
  assert.match(pricing, /Sign in to subscribe/);
  assert.match(pricing, /Subscribe securely/);
  assert.match(
    pricing,
    /paddlePricing \? \([\s\S]*<PaddlePricingClient[\s\S]*<PaddlePricingFallback authenticated=\{user\.authenticated\} \/>/
  );
});

test('account, welcome, and sign-in pages use accessible light surfaces', async () => {
  const [billing, welcome, signin] = await Promise.all([
    source('app/billing/page.tsx'),
    source('app/welcome/page.tsx'),
    source('app/auth/signin/page.tsx'),
  ]);

  assert.match(billing, /axio-account-card/);
  assert.match(billing, /href="\/"/);
  assert.match(welcome, /axio-account-card/);
  assert.match(welcome, /Open research/);
  assert.match(signin, /axio-auth-card/);
  assert.match(signin, /role="alert"/);
  assert.match(signin, /role="status"/);
  assert.match(signin, /Continue with Google\s*<\/button>/);
});

test('fail-closed research is readable and mobile-safe without hiding the audit reason', async () => {
  const [chat, chatStyles, researchAnswer] = await Promise.all([
    source('components/AxioChat.tsx'),
    source('components/AxioChat.module.css'),
    source('lib/quant/research-answer.ts'),
  ]);

  assert.match(chat, /research\.candidates\.length === 0/);
  assert.match(chat, /research\.data_blockers\.length > 0/);
  assert.match(
    chat,
    /<FailClosedNotice[\s\S]*envelope=\{gatedResearch\}/
  );
  assert.match(
    chat,
    /No live forecast was generated for this request\./
  );
  assert.match(
    chat,
    /No unlicensed, stale, historical-rule, or synthetic substitute was shown\./
  );
  assert.match(chat, /navigator\.clipboard\.writeText\(blockers\.join\('\\n'\)\)/);
  assert.match(
    chat,
    /<code key=\{blocker\}>[\s\S]*humanizeDataBlocker\(blocker, locale\)[\s\S]*Diagnostic code/
  );
  assert.match(chat, /Technical details/);

  const answerRule = chatStyles.slice(chatStyles.indexOf('.answer {'));
  assert.match(answerRule, /overflow-wrap:\s*anywhere/);
  assert.match(answerRule, /word-break:\s*break-word/);

  const technicalRule = chatStyles.slice(
    chatStyles.indexOf('.technicalDetails code')
  );
  assert.match(technicalRule, /overflow-wrap:\s*anywhere/);
  assert.match(technicalRule, /word-break:\s*break-word/);
  assert.match(chatStyles, /@media \(max-width:\s*640px\)[\s\S]*\.gatedNotice/);

  assert.match(
    researchAnswer,
    /尚未配置允许向网站用户展示或再分发的实时市场数据授权/
  );
  assert.match(
    researchAnswer,
    /本次请求没有生成实时预测/
  );
});

test('public copy keeps research boundaries within the unified AXIO7 product', async () => {
  const [
    layout,
    home,
    cosmicHero,
    chat,
    pricing,
    paddleCatalog,
    terms,
    privacy,
    support,
    deletion,
  ] = await Promise.all([
    source('app/layout.tsx'),
    source('app/page.tsx'),
    source('components/home/CosmicHero.tsx'),
    source('components/AxioChat.tsx'),
    source('app/pricing/page.tsx'),
    source('lib/paddle-catalog.ts'),
    source('app/terms/page.tsx'),
    source('app/privacy/page.tsx'),
    source('app/support/page.tsx'),
    source('app/account/delete/page.tsx'),
  ]);

  assert.match(layout, /AXIO7 — Evidence and reflection/);
  assert.match(home, /AXIO7 — Navigate uncertainty/);
  assert.match(cosmicHero, /Navigate[\s\S]*uncertainty\./);
  assert.match(cosmicHero, /Evidence-first Research/);
  assert.match(
    chat,
    /What would you like to predict or research\?/
  );
  assert.match(
    chat,
    /Impersonal research only — not investment advice or order execution/
  );
  assert.match(
    pricing,
    /Research software, not advice or execution/
  );
  assert.match(
    paddleCatalog,
    /Impersonal quantitative research workspace/
  );
  assert.match(
    terms,
    /impersonal quantitative market-research software service/
  );
  assert.match(
    privacy,
    /Research inputs such as prompts, symbols, allow-listed query parameters/
  );
  assert.match(
    support,
    /provides impersonal quantitative market research/
  );
  assert.match(deletion, /research history, saved monitors/);

  const retiredEducationCopy = [
    layout,
    home,
    cosmicHero,
    pricing,
    paddleCatalog,
    terms,
    privacy,
    support,
    deletion,
  ].join('\n');
  assert.doesNotMatch(
    retiredEducationCopy,
    /guided lessons|historical case reviews|learning membership|curriculum content|lesson progress/i
  );
});

test('cosmic homepage and private astrology practice keep their product boundaries', async () => {
  const [hero, heroStyles, astrologyPage, astrology, astrologyStyles, nav, sitemap] =
    await Promise.all([
      source('components/home/CosmicHero.tsx'),
      source('components/home/CosmicHero.module.css'),
      source('app/apps/astrology/page.tsx'),
      source('components/astrology/AstrologyApp.tsx'),
      source('components/astrology/AstrologyApp.module.css'),
      source('components/Nav.tsx'),
      source('app/sitemap.ts'),
    ]);

  assert.match(hero, /href="\/apps\/astrology"/);
  assert.match(hero, /href="#research-workspace"/);
  assert.match(hero, /requestAnimationFrame/);
  assert.match(hero, /prefers-reduced-motion/);
  assert.match(heroStyles, /@media \(prefers-reduced-motion: reduce\)/);

  assert.match(astrologyPage, /Daily Star Map — AXIO7 Astrology/);
  assert.match(astrology, /localStorage\.setItem/);
  assert.match(astrology, /localStorage\.removeItem/);
  assert.match(astrology, /Approximate Western sun sign/);
  assert.match(astrology, /Reflection prompt — not a forecast/);
  assert.match(astrology, /never sent to AXIO7/);
  assert.match(astrology, /Delete birth date/);
  assert.match(astrologyStyles, /@media \(prefers-reduced-motion: reduce\)/);
  assert.match(nav, /href="\/apps\/astrology"/);
  assert.match(sitemap, /path: '\/apps\/astrology'/);

  for (const launchSurface of [hero, astrologyPage, astrology]) {
    assert.doesNotMatch(launchSurface, /[\u3400-\u9fff]/);
  }
});

test('legacy education and overview routes redirect to active research surfaces', async () => {
  const [learn, quant, about, sitemap, robots] = await Promise.all([
    source('app/learn/page.tsx'),
    source('app/quant/page.tsx'),
    source('app/about/page.tsx'),
    source('app/sitemap.ts'),
    source('app/robots.ts'),
  ]);

  assert.match(learn, /redirect\('\/'\)/);
  assert.match(about, /redirect\('\/'\)/);
  assert.match(quant, /redirect\('\/quant\/intraday'\)/);
  assert.doesNotMatch(sitemap, /path: '\/(?:learn|about)'/);
  assert.doesNotMatch(robots, /'\/(?:learn|about)'/);
});
