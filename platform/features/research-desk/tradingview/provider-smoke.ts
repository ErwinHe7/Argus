/** Opt-in network smoke check. It verifies hosted presentation, never data freshness. */
import { createServer } from 'node:http';
import { createRequire } from 'node:module';
import { once } from 'node:events';
import { chartConfig, boardConfig, tapeConfig, widgetDataUrl, WIDGET_SANDBOX } from './embed';
import { TRADINGVIEW_MARKETS, resolveTradingViewSymbol } from './symbols';

async function main() {
  const require = createRequire(import.meta.url);
  const { chromium } = require(process.env.LEO_PLAYWRIGHT_MODULE || 'playwright');
  const examples = [
    ['chart', chartConfig(resolveTradingViewSymbol('NVDA')!), 'NVDA chart'],
    ['tape', tapeConfig(TRADINGVIEW_MARKETS), 'Market ticker'],
    ['board', boardConfig(TRADINGVIEW_MARKETS), 'Market board'],
  ] as const;
  const html = `<!doctype html><html><body><script>window.presentation=[];localStorage.setItem('isolation-probe','parent-only');addEventListener('message',e=>window.presentation.push({origin:e.origin,...e.data}));</script>${examples.map(([kind, config, title]) => `<iframe title="${title}" sandbox="${WIDGET_SANDBOX}" referrerpolicy="no-referrer" src="${widgetDataUrl(kind, config, title, 'https://www.tradingview.com/', kind)}" style="width:1100px;height:600px"></iframe>`).join('')}</body></html>`;
  const server = createServer((_req, res) => { res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' }); res.end(html); });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const address = server.address();
  if (!address || typeof address === 'string') throw new Error('Missing test server address');
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
  const failed: string[] = [];
  page.on('requestfailed', (request: { url(): string }) => failed.push(request.url().split('?')[0]!));
  try {
    await page.goto(`http://127.0.0.1:${address.port}/`);
    await page.waitForFunction(() => (window as unknown as { presentation: { state: string }[] }).presentation.filter(message => message.state === 'embedded').length >= 3, { timeout: 30000 }).catch(() => undefined);
    const outerFrames = page.frames().filter((frame: { url(): string }) => frame.url().startsWith('data:text/html'));
    const isolation = await Promise.all(outerFrames.map((frame: { evaluate(callback: () => unknown): Promise<unknown> }) => frame.evaluate(() => { try { return { blocked: false, value: parent.localStorage.getItem('isolation-probe') }; } catch (error) { return { blocked: error instanceof DOMException && error.name === 'SecurityError' }; } })));
    const presentation = await page.evaluate(() => (window as unknown as { presentation: unknown[] }).presentation);
    await page.waitForTimeout(6000);
    const providerFrames = page.frames().filter((frame: { url(): string }) => /^https:\/\/[^/]*tradingview(?:-widget)?\.com\//.test(frame.url()));
    const providerRendering = await Promise.all(providerFrames.map(async (frame: { url(): string; locator(selector: string): { count(): Promise<number> } }) => ({ path: new URL(frame.url()).origin + new URL(frame.url()).pathname, canvases: await frame.locator('canvas').count() })));
    const result = { checkedAt: new Date().toISOString(), presentation, isolation, providerFrameCount: providerFrames.length, providerRendering, failedRequests: [...new Set(failed)], proves: 'Hosted frame creation and parent-storage isolation only; not quote availability, latency, completeness, or trading suitability.' };
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
    if (outerFrames.length !== 3 || providerFrames.length < 3 || isolation.some((item: { blocked?: boolean }) => !item.blocked) || !examples.every(([kind]) => (presentation as { attempt: string; state: string }[]).some(item => item.attempt === kind && item.state === 'embedded'))) process.exitCode = 1;
  } finally {
    await browser.close();
    server.close();
  }
}

main().catch(error => { process.stderr.write(`${error}\n`); process.exitCode = 1; });
