import { expect, test } from "@playwright/test";

import {
  DEMO_ORIGIN,
  installLocalProductionSurface,
  LANDING_ORIGIN,
  WAITLIST_ORIGIN,
} from "./support.ts";

test("effective landing and demo headers enforce the exact pairwise frame policy", async ({ page }) => {
  await installLocalProductionSurface(page);
  const demoResponse = page.waitForResponse((response) =>
    response.request().resourceType() === "document" && response.url().startsWith(DEMO_ORIGIN),
  );
  const landing = await page.goto(LANDING_ORIGIN);
  const demo = await demoResponse;

  expect(landing).not.toBeNull();
  const landingCsp = landing!.headers()["content-security-policy"] ?? "";
  expect(landingCsp).toContain("frame-ancestors 'none'");
  expect(landingCsp).toContain(`frame-src ${DEMO_ORIGIN.slice(0, -1)} https://challenges.cloudflare.com`);
  expect(landingCsp).toContain("base-uri 'none'");
  expect(landingCsp).toContain(`form-action ${WAITLIST_ORIGIN.slice(0, -1)}`);
  expect(landingCsp).toContain(`connect-src 'self' https://challenges.cloudflare.com ${WAITLIST_ORIGIN.slice(0, -1)}`);
  expect(landingCsp).not.toMatch(/(?:^|\s)\*(?:\s|;|$)|(?<!wasm-)unsafe-eval|unsafe-inline/);
  expect(landing!.headers()["x-frame-options"]).toBe("DENY");
  expect(landing!.headers()["permissions-policy"]).toContain("payment=()");

  const demoCsp = demo.headers()["content-security-policy"] ?? "";
  expect(demoCsp).toContain(`frame-ancestors ${LANDING_ORIGIN.slice(0, -1)}`);
  expect(demoCsp).toContain("connect-src 'self'");
  expect(demoCsp.match(/unsafe-inline/g)).toHaveLength(1);
  expect(demo.headers()["x-frame-options"]).toBeUndefined();
  expect(demo.headers()["x-robots-tag"]).toContain("noindex");
  expect(await page.context().cookies()).toEqual([]);
});

test("hostile and stale frame messages cannot advance the current demo", async ({ page }) => {
  await installLocalProductionSurface(page, { demo: "mock-silent" });
  await page.goto(LANDING_ORIGIN);
  const status = page.locator("[data-demo-status]");
  const frame = page.frames().find((candidate) => candidate.url().startsWith(DEMO_ORIGIN));
  expect(frame).toBeDefined();

  await page.evaluate(() => window.postMessage({
    source: "ritual-investing-demo",
    type: "ritual-demo-ready",
    protocolVersion: 2,
    environment: "production",
    attemptId: "hostile",
  }, "*"));
  await expect(status).toHaveAttribute("data-state", "loading");

  await frame!.evaluate(() => parent.postMessage({
    source: "ritual-investing-demo",
    type: "ritual-demo-ready",
    protocolVersion: 2,
    environment: "production",
    attemptId: "stale-attempt",
  }, "https://just-build-this.app"));
  await expect(status).toHaveAttribute("data-state", "loading");

  const currentAttempt = new URL(frame!.url()).searchParams.get("attempt");
  await frame!.evaluate((attemptId) => parent.postMessage({
    source: "ritual-investing-demo",
    type: "ritual-demo-ready",
    protocolVersion: 1,
    environment: "production",
    attemptId,
  }, "https://just-build-this.app"), currentAttempt);
  await expect(status).toHaveAttribute("data-state", "ready");
});

test("keyboard and mobile sizing keep the embedded demo bounded without trapping the page", async ({ page }) => {
  await installLocalProductionSurface(page);
  await page.goto(LANDING_ORIGIN);
  await expect(page.locator("[data-demo-status]")).toHaveAttribute("data-state", "ready");

  await page.keyboard.press("Tab");
  await expect(page.locator(".skip-link")).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(page.locator("#main")).toBeInViewport();

  await page.evaluate(() => document.fonts.ready);
  const geometry = await page.evaluate(() => {
    const stage = document.querySelector(".phone-stage")?.getBoundingClientRect();
    const frame = document.querySelector("iframe.demo-frame")?.getBoundingClientRect();
    if (stage === undefined || frame === undefined) return null;
    return {
      stage: { x: stage.x, y: stage.y, width: stage.width, height: stage.height },
      frame: { x: frame.x, y: frame.y, width: frame.width, height: frame.height },
    };
  });
  expect(geometry).not.toBeNull();
  expect(geometry!.frame.width).toBeLessThanOrEqual(geometry!.stage.width);
  expect(geometry!.frame.height).toBeLessThanOrEqual(geometry!.stage.height);
  expect(geometry!.frame.x).toBeGreaterThanOrEqual(geometry!.stage.x);
  expect(geometry!.frame.y).toBeGreaterThanOrEqual(geometry!.stage.y);

  const openDemo = page.getByRole("link", { name: /Open Demo in a new tab/ });
  await openDemo.focus();
  await page.keyboard.press("Tab");
  await expect(page.locator("iframe.demo-frame")).toBeFocused();
  await page.keyboard.press("Shift+Tab");
  await page.keyboard.press("Shift+Tab");
  expect(await page.evaluate(() => document.activeElement !== document.querySelector("iframe.demo-frame"))).toBe(true);
});
