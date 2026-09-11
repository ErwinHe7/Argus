/* Opt-in browser integration verification. Provider screenshots are observed presentation,
 * never a claim of real-time entitlement, quote accuracy, or execution suitability. */
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { createRequire } = require('node:module');
const runtimeRequire = createRequire(process.env.LEO_PLAYWRIGHT_PACKAGE || 'C:/Users/Hj/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const { chromium } = runtimeRequire('playwright');
const output = path.resolve(__dirname, '../../../.impeccable/review/tradingview');
const root = process.env.LEO_PREVIEW_URL || 'http://127.0.0.1:3117';
const receipt = { checkedAt: new Date().toISOString(), source: 'Actual hosted TradingView presentation except explicitly injected outage checks; fresh isolated browser contexts; no brokerage actions', checks: [], screenshots: [], providerObservations: [], pageErrors: [], requestFailures: [], failures: [] };

async function check(name, action) {
  try { const detail = await action(); receipt.checks.push({ name, result: 'pass', ...(detail ? { detail } : {}) }); console.log('PASS ' + name); }
  catch (error) { receipt.failures.push({ name, error: error.message }); console.error('FAIL ' + name + ': ' + error.message); }
}
async function provider(page, kind = 'chart', expectedSymbol) {
  await page.locator('.leo-tv--' + kind).waitFor({ state: 'visible' });
  const deadline = Date.now() + 30000;
  let observation;
  while (Date.now() < deadline) {
    const outer = await (await page.locator('.leo-tv--' + kind + ' .leo-tv-frame').elementHandle()).contentFrame();
    const frame = outer?.childFrames().find(item => item.url().includes(kind === 'chart' ? '/advanced-chart/' : kind === 'board' ? '/market-quotes/' : '/ticker-tape/'));
    if (frame) {
      try {
        const title = await frame.locator('body').innerText({ timeout: 1000 });
        const canvases = await frame.locator('canvas').evaluateAll(items => items.map(canvas => {
          const result = { width: canvas.width, height: canvas.height, coloredSamples: 0 };
          try {
            const context = canvas.getContext('2d');
            if (!context || canvas.width < 100 || canvas.height < 100) return result;
            const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data;
            for (let i = 0; i < pixels.length; i += 16) {
              const r = pixels[i], g = pixels[i + 1], b = pixels[i + 2];
              if ((r > 130 && r > g * 1.45 && r > b * 1.2) || (g > 90 && g > r * 1.5 && g > b * 1.05)) result.coloredSamples++;
            }
          } catch { result.pixelReadUnavailable = true; }
          return result;
        }));
        const configuration = JSON.parse(decodeURIComponent(new URL(frame.url()).hash.slice(1)));
        observation = { route: new URL(page.url()).hash || new URL(page.url()).pathname, kind, providerOrigin: new URL(frame.url()).origin, configuredSymbol: configuration.symbol, configuredCandleStyle: configuration.style, canvasCount: canvases.length, coloredSamples: canvases.reduce((sum, item) => sum + item.coloredSamples, 0), contentExcerpt: title.slice(0, 230).replace(/\n/g, ' · ') };
        const rendered = kind === 'chart' ? canvases.length >= 1 && observation.coloredSamples > 20 && /\bVol\b/.test(title) : /SPY|QQQ|Bitcoin|BTC|AVGO/.test(title) && /\d/.test(title);
        if (rendered && (!expectedSymbol || configuration.symbol === expectedSymbol)) {
          receipt.providerObservations.push(observation);
          return { frame, outer, observation };
        }
      } catch { /* The provider frame may navigate while its application starts. */ }
    }
    await page.waitForTimeout(400);
  }
  throw new Error('Provider did not show settled ' + kind + ' within 30 seconds: ' + JSON.stringify(observation));
}
async function capture(page, name) {
  await page.evaluate(async () => { await document.fonts.ready; scrollTo(0, 0); });
  await page.waitForTimeout(350);
  assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'horizontal overflow');
  const target = path.join(output, name + '.png');
  await page.screenshot({ path: target, fullPage: true, animations: 'disabled' });
  receipt.screenshots.push({ path: target, name, viewport: page.viewportSize(), evidence: 'Actual TradingView hosted presentation; no injected quote data' });
}
async function isolatedContext(browser, viewport = { width: 1440, height: 1000 }) {
  const context = await browser.newContext({ viewport, reducedMotion: 'reduce' });
  context.setDefaultTimeout(12000);
  await context.addInitScript(() => {
    if (parent === window && location.origin === 'http://127.0.0.1:3117') {
      localStorage.setItem('leo-test-isolation-local', 'parent-only');
      sessionStorage.setItem('leo-test-isolation-session', 'parent-only');
    }
  });
  context.on('page', page => {
    page.on('pageerror', error => receipt.pageErrors.push(error.message));
    page.on('requestfailed', request => receipt.requestFailures.push({ path: request.url().split('?')[0].split('#')[0], failure: request.failure()?.errorText }));
  });
  return context;
}

(async () => {
  await fs.mkdir(output, { recursive: true });
  const browser = await chromium.launch({ headless: true });
  try {
    const context = await isolatedContext(browser);
    const page = await context.newPage();
    await check('Desktop home renders actual AVGO candlesticks and dated research', async () => {
      await page.goto(root + '/#/home');
      await provider(page, 'chart', 'NASDAQ:AVGO');
      await provider(page, 'tape');
      await page.getByText(/Recorded research · 2026-09-04/).waitFor();
      await capture(page, 'desktop-home');
    });
    await check('Home AVGO to DXYZ replaces the chart without duplication', async () => {
      await page.getByLabel('Choose your market').selectOption('DXYZ');
      await provider(page, 'chart', 'NYSE:DXYZ');
      assert.equal(await page.locator('.leo-tv--chart .leo-tv-frame').count(), 1);
      await page.getByLabel('Choose your market').selectOption('AVGO');
    });
    await check('Desktop stock chart and retained archive replay/layers', async () => {
      await page.goto(root + '/#/structure?symbol=AVGO');
      await provider(page, 'chart', 'NASDAQ:AVGO');
      await capture(page, 'desktop-stock');
      await page.locator('.market-archive > summary').click();
      await page.getByRole('button', { name: 'Replay history', exact: true }).waitFor();
      await page.getByLabel('SMA 50', { exact: true }).check();
      await page.getByLabel('RSI 14', { exact: true }).check();
      await page.getByRole('img', { name: 'RSI 14 historical values' }).waitFor();
      await page.getByLabel('Historical session').fill('10');
      await page.getByRole('button', { name: 'Latest session', exact: true }).click();
      await page.locator('.market-archive > summary').click();
      await page.getByRole('button', { name: 'DXYZ', exact: true }).click();
      await provider(page, 'chart', 'NYSE:DXYZ');
      assert.equal(await page.locator('.leo-tv--chart .leo-tv-frame').count(), 1);
    });
    for (const [route, symbol] of [['playbook', 'AMEX:SPY'], ['tech-playbook', 'NASDAQ:QQQ']]) {
      await check(route + ' ETF proxy renders actual provider chart', async () => {
        await page.goto(root + '/#/' + route);
        await provider(page, 'chart', symbol);
        await page.getByText(/ETF proxy, not the/).waitFor();
      });
    }
    await check('Desktop board renders all ten mapped instruments and dated export', async () => {
      await page.goto(root + '/#/board');
      const { frame } = await provider(page, 'board');
      const content = await frame.locator('body').innerText();
      for (const symbol of ['SPY', 'QQQ', 'DXYZ', 'ZM', 'AVGO', 'AMZN', 'GOOGL', 'NVDA', 'BTC-USD', 'ETH-USD']) assert(content.includes(symbol), symbol + ' missing from provider board');
      await capture(page, 'desktop-board');
      await page.locator('.market-archive > summary').click();
      await page.getByRole('button', { name: 'Export observations', exact: true }).waitFor();
      await page.getByRole('columnheader', { name: 'Daily cutoff', exact: true }).waitFor();
    });
    await check('Options lab Charts tab renders provider chart beside dated model inputs', async () => {
      await page.goto(root + '/#/iv?symbol=AVGO');
      await page.getByRole('tab', { name: 'Charts', exact: true }).click();
      await provider(page, 'chart', 'NASDAQ:AVGO');
      await page.getByText('Historical, not live', { exact: true }).waitFor();
      await page.getByText('The indicators below and option scenarios use the dated research snapshot. TradingView supplies the displayed market chart.', { exact: true }).waitFor();
      await capture(page, 'desktop-options');
      await page.locator('.market-archive > summary').click();
      assert.equal(await page.locator('.market-archive[open]').count(), 1);
    });
    await check('Provider frames cannot access parent local/session storage; bootstrap absent from parent', async () => {
      const outerFrames = page.frames().filter(frame => frame.url().startsWith('data:text/html'));
      assert.equal(outerFrames.length, 2);
      for (const frame of outerFrames) {
        const access = await frame.evaluate(() => {
          const result = {};
          for (const storage of ['localStorage', 'sessionStorage']) {
            try { parent[storage].getItem('leo-test-isolation-' + (storage === 'localStorage' ? 'local' : 'session')); result[storage] = 'accessible'; }
            catch (error) { result[storage] = error.name; }
          }
          return result;
        });
        assert.deepEqual(access, { localStorage: 'SecurityError', sessionStorage: 'SecurityError' });
      }
      const scripts = await page.locator('script[src]').evaluateAll(items => items.map(item => item.src));
      assert(!scripts.some(src => /tradingview/.test(src)), 'TradingView script loaded in parent origin');
      return { isolatedFrames: outerFrames.length, parentScripts: scripts.map(src => new URL(src).pathname) };
    });
    await page.setViewportSize({ width: 390, height: 844 });
    await check('Mobile home settled provider chart without horizontal overflow', async () => {
      await page.goto(root + '/#/home');
      await provider(page, 'chart', 'NASDAQ:AVGO');
      await capture(page, 'mobile-home');
    });
    await check('Mobile crypto renders BTC then ETH with one chart', async () => {
      await page.goto(root + '/#/crypto');
      await provider(page, 'chart', 'COINBASE:BTCUSD');
      await capture(page, 'mobile-crypto');
      await page.getByRole('button', { name: 'Ethereum · ETH', exact: true }).click();
      await provider(page, 'chart', 'COINBASE:ETHUSD');
      assert.equal(await page.locator('.leo-tv--chart .leo-tv-frame').count(), 1);
    });
    await check('Mobile stock chart settled without horizontal overflow', async () => {
      await page.goto(root + '/#/structure?symbol=AVGO');
      await provider(page, 'chart', 'NASDAQ:AVGO');
      await capture(page, 'mobile-stock');
    });
    await context.close();

    const failedContext = await isolatedContext(browser);
    const failed = await failedContext.newPage();
    await check('Injected provider bootstrap failure exposes retry and outbound fallback; retry recovers', async () => {
      const block = route => route.abort('blockedbyclient');
      await failed.route('https://s3.tradingview.com/external-embedding/**', block);
      await failed.goto(root + '/#/structure?symbol=AVGO');
      const chart = failed.locator('.leo-tv--chart');
      await chart.getByText('TradingView did not finish loading.', { exact: false }).waitFor();
      await chart.getByRole('link', { name: 'Open TradingView', exact: true }).waitFor();
      assert.equal(await chart.getByRole('link', { name: 'Open TradingView', exact: true }).getAttribute('href'), 'https://www.tradingview.com/chart/?symbol=NASDAQ%3AAVGO');
      await failed.unroute('https://s3.tradingview.com/external-embedding/**', block);
      await chart.getByRole('button', { name: 'Retry', exact: true }).click();
      await provider(failed, 'chart', 'NASDAQ:AVGO');
      return 'Injected blocked bootstrap only; recovery used the actual hosted provider';
    });
    await failedContext.close();

    const outageContext = await isolatedContext(browser);
    const outage = await outageContext.newPage();
    await outage.route('**/app/research-desk/data/**', route => route.fulfill({ status: 503, body: 'Injected archive outage' }));
    for (const [route, kind, symbol] of [['structure?symbol=AVGO', 'chart', 'NASDAQ:AVGO'], ['playbook', 'chart', 'AMEX:SPY'], ['tech-playbook', 'chart', 'NASDAQ:QQQ'], ['crypto', 'chart', 'COINBASE:BTCUSD'], ['board', 'board']]) {
      await check('Archive JSON 503 leaves ' + route + ' provider independent', async () => {
        await outage.goto(root + '/#/' + route);
        await provider(outage, kind, symbol);
      });
    }
    for (const route of ['/#/strategies', '/strategy-auth/callback']) {
      await check(route + ' never creates a TradingView frame or bootstrap request', async () => {
        const requests = [];
        const requestHandler = request => { if (/tradingview/.test(request.url())) requests.push(request.url()); };
        outage.on('request', requestHandler);
        await outage.goto(root + route);
        await outage.getByRole('heading', { name: 'Choose strategy', exact: true }).waitFor();
        assert.equal(await outage.locator('.leo-tv-frame').count(), 0);
        assert.equal(requests.length, 0);
        outage.off('request', requestHandler);
      });
    }
    await outageContext.close();
  } finally {
    await browser.close();
    receipt.requestFailures = [...new Map(receipt.requestFailures.map(item => [item.path + item.failure, item])).values()];
    receipt.limitation = 'Hosted canvas and provider text prove presentation only. Some U.S. widget quotes explicitly show delayed D/Cboe One; no assertion of consolidated real-time data or accuracy. Injected failures are not provider outages. No order API or brokerage connection is exercised.';
    await fs.writeFile(path.join(output, 'browser-checks.json'), JSON.stringify(receipt, null, 2) + '\n');
    console.log(JSON.stringify({ passed: receipt.checks.length, failed: receipt.failures.length, screenshots: receipt.screenshots.length, pageErrors: receipt.pageErrors.length, receipt: path.join(output, 'browser-checks.json') }));
    if (receipt.failures.length || receipt.pageErrors.length) process.exitCode = 1;
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
