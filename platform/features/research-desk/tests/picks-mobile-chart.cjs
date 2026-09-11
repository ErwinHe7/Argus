/* Targeted default-NVDA mobile viewport/retry evidence only. No injections. */
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { chromium } = require(process.env.LEO_PLAYWRIGHT_MODULE || 'C:/Users/Hj/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root = process.env.LEO_PREVIEW_URL || 'http://127.0.0.1:3117';
const output = path.resolve(__dirname, '../../../.impeccable/review/picks');
const result = { checkedAt: new Date().toISOString(), scope: 'Default mobile NVDA provider visibility, Retry chart recreation, and one full-page recapture. The fourteen functional checks are not rerun.', viewport: { width: 390, height: 844 }, injectedData: false, substitutedTicker: false, observations: [], errors: [], failures: [] };

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: result.viewport, reducedMotion: 'reduce', serviceWorkers: 'block' });
  const page = await context.newPage();
  page.on('pageerror', error => result.errors.push({ pageUrl: page.url(), message: error.message, stack: error.stack || null }));
  const stage = page.locator('.pick-detail .leo-tv-stage');
  const host = page.locator('.pick-detail .leo-tv-frame');
  async function observation(label) {
    const outer = await (await host.elementHandle())?.contentFrame();
    const frame = outer?.childFrames().find(frame => frame.url().includes('/advanced-chart/'));
    const bounds = await stage.boundingBox();
    const body = frame ? await frame.locator('body').innerText().catch(() => '') : '';
    const item = { label, at: new Date().toISOString(), stage: bounds, inViewport: !!bounds && bounds.y < 844 && bounds.y + bounds.height > 0, providerSymbol: frame ? JSON.parse(decodeURIComponent(new URL(frame.url()).hash.slice(1))).symbol : null, canvases: frame ? await frame.locator('canvas').count() : 0, visibleProviderText: body.slice(0, 650), hasVolumeLabel: /Vol/.test(body), hasEmptyOhlc: /∅/.test(body) };
    result.observations.push(item);
    return item;
  }
  async function waitVisibleState(label) {
    const deadline = Date.now() + 18000;
    while (Date.now() < deadline) {
      const outer = await (await host.elementHandle())?.contentFrame();
      const frame = outer?.childFrames().find(frame => frame.url().includes('/advanced-chart/'));
      if (frame) {
        const text = await frame.locator('body').innerText().catch(() => '');
        if ((/Vol/.test(text) && !/∅/.test(text)) || /no data|unavailable|only available on TradingView/i.test(text)) break;
      }
      await page.waitForTimeout(300);
    }
    return observation(label);
  }
  try {
    await page.goto(root + '/#/home');
    await page.getByRole('button', { name: 'Review NVDA, rank 1', exact: true }).waitFor();
    await page.locator('.pick-detail .leo-tv[data-widget-state="embedded"]').waitFor({ timeout: 22000 });
    await page.waitForTimeout(800);
    const before = await observation('default chart below the fold before scrolling');
    await stage.evaluate(element => element.scrollIntoView({ block: 'center', behavior: 'instant' }));
    const visible = await waitVisibleState('same default chart brought into view, before Retry');
    const previousUrl = await host.getAttribute('src');
    await page.getByRole('button', { name: 'Retry chart', exact: true }).click();
    await page.waitForFunction(previous => document.querySelector('.pick-detail .leo-tv-frame')?.getAttribute('src') !== previous, previousUrl);
    result.retry = { clickedOnce: true, providerHostRecreated: true, changedHostUrl: (await host.getAttribute('src')) !== previousUrl };
    await page.locator('.pick-detail .leo-tv[data-widget-state="embedded"]').waitFor({ timeout: 22000 });
    const retried = await waitVisibleState('default NVDA after one visible Retry chart');
    assert.equal(retried.providerSymbol, 'NASDAQ:NVDA');
    assert(retried.inViewport, 'retried chart is outside the viewport');
    await page.evaluate(() => document.fonts.ready);
    const detailPath = path.join(output, 'mobile-home-chart-viewport.png');
    await page.screenshot({ path: detailPath, fullPage: false, animations: 'disabled' });
    await page.evaluate(() => scrollTo(0, 0));
    await page.waitForTimeout(300);
    const after = await observation('default chart after returning to page top for full-page capture');
    assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'horizontal overflow');
    const finalPath = path.join(output, 'mobile-home.png');
    await page.screenshot({ path: finalPath, fullPage: true, animations: 'disabled' });
    result.captures = { preserved: path.join(output, 'mobile-home-first-confirmation.png'), viewport: detailPath, fullPage: finalPath };
    result.explanation = !before.inViewport && before.hasEmptyOhlc && visible.hasVolumeLabel && !visible.hasEmptyOhlc
      ? 'The same NVDA frame changed from empty OHLC below the fold to populated OHLC and Volume when scrolled into view, before Retry or ticker change. This supports viewport-dependent provider initialization/painting as the cause of the earlier blank capture, not a demonstrated missing-data entitlement. Internal provider causation is not observable.'
      : 'The before/after observation does not establish viewport-dependent initialization as the cause. Exact provider state is retained without treating empty OHLC as price evidence.';
    result.finalProviderState = after.hasVolumeLabel && !after.hasEmptyOhlc ? 'Populated OHLC and Volume visible in provider presentation; quote accuracy and freshness are not verified.' : 'Provider still has incomplete or unavailable displayed data; exact text is recorded above, with no local price fallback.';
  } catch (error) { result.failures.push(error.message); process.exitCode = 1; }
  finally { await context.close(); await browser.close(); await fs.writeFile(path.join(output, 'mobile-chart-recapture.json'), JSON.stringify(result, null, 2) + '\n'); }
  console.log(JSON.stringify(result, null, 2));
  if (result.errors.length || result.failures.length) process.exitCode = 1;
})().catch(error => { console.error(error); process.exitCode = 1; });
