import { expect, test } from "@playwright/test";

import {
  DEMO_ORIGIN,
  installLocalProductionSurface,
  LANDING_ORIGIN,
  WAITLIST_ENDPOINT,
} from "./support.ts";

test("the packaged demo reaches ready with static-only traffic and empty browser state", async ({ page }) => {
  test.setTimeout(120_000);
  const surface = await installLocalProductionSurface(page, { demo: "real" });
  await page.goto(LANDING_ORIGIN);
  await expect(page.locator("[data-demo-status]")).toHaveAttribute("data-state", "ready", { timeout: 60_000 });

  expect(page.frames().some((frame) => frame.url().startsWith(DEMO_ORIGIN))).toBe(true);

  await page.goto(DEMO_ORIGIN);
  await expect(page.getByText("YOUR DAILY SIGNAL", { exact: true })).toBeVisible({ timeout: 60_000 });
  await page.getByRole("tab", { name: "Discover" }).press("Enter");
  const grimoire = page.getByRole("button", { name: /Quiet Power Grimoire/ }).last();
  await expect(grimoire).toBeVisible();
  await grimoire.press("Enter");
  await page.getByRole("button", { name: "Save Grimoire" }).press("Enter");
  await expect(page.getByText("Saved", { exact: true })).toBeVisible();

  await page.getByRole("tab", { name: "Coven" }).press("Enter");
  await expect(page.getByText("Founders’ Coven", { exact: true })).toBeVisible();
  await page.getByRole("tab", { name: "You" }).press("Enter");
  await expect(page.getByText("Your saved answers, active personalization, and Webull connection.")).toBeVisible();
  await page.getByRole("tab", { name: "Ritual" }).press("Enter");
  await expect(page.getByText("YOUR DAILY SIGNAL", { exact: true })).toBeVisible();

  const state = await page.evaluate(async () => ({
    cookie: document.cookie,
    localStorage: Object.keys(localStorage),
    sessionStorage: Object.keys(sessionStorage),
    indexedDb: typeof indexedDB.databases === "function"
      ? (await indexedDB.databases()).map((database) => database.name ?? "unnamed")
      : [],
    caches: "caches" in globalThis ? await caches.keys() : [],
    serviceWorkers: "serviceWorker" in navigator
      ? (await navigator.serviceWorker.getRegistrations()).map((registration) => registration.scope)
      : [],
  }));
  expect(state).toEqual({
    cookie: "",
    localStorage: [],
    sessionStorage: [],
    indexedDb: [],
    caches: [],
    serviceWorkers: [],
  });
  expect(await page.context().cookies()).toEqual([]);

  const observed = [...new Set(surface.requests)];
  expect(observed.some((url) => url.startsWith(DEMO_ORIGIN) && url.includes("main.dart.js"))).toBe(true);
  for (const request of observed) {
    const url = new URL(request);
    if (url.protocol === "about:") {
      expect(url.href).toBe("about:blank");
      continue;
    }
    if (url.protocol === "blob:") {
      expect(url.origin).toBe(DEMO_ORIGIN.slice(0, -1));
      expect(request).not.toMatch(/auth0|api(?:-beta)?\.just-build-this\.app|\/v1\/session\/bootstrap|neon|postgres|analytics/i);
      continue;
    }
    expect(url.protocol).toBe("https:");
    expect([
      "just-build-this.app",
      "demo.just-build-this.app",
      "challenges.cloudflare.com",
    ]).toContain(url.hostname);
    expect(request).not.toMatch(/auth0|api(?:-beta)?\.just-build-this\.app|\/v1\/session\/bootstrap|neon|postgres|analytics|webull/i);
    if (url.hostname === "demo.just-build-this.app") expect(url.pathname).not.toMatch(/^\/api\//);
  }
  expect(observed).not.toContain(WAITLIST_ENDPOINT);
});

test("reload and BFCache history restoration create a fresh frame without restoration state", async ({ page }) => {
  test.setTimeout(120_000);
  await installLocalProductionSurface(page, { demo: "real" });
  await page.goto(LANDING_ORIGIN);
  const status = page.locator("[data-demo-status]");
  await expect(status).toHaveAttribute("data-state", "ready", { timeout: 60_000 });
  const initialAttempt = await page.locator("iframe.demo-frame").getAttribute("src");

  await page.reload();
  await expect(status).toHaveAttribute("data-state", "ready", { timeout: 60_000 });
  const reloadAttempt = await page.locator("iframe.demo-frame").getAttribute("src");
  expect(reloadAttempt).not.toBe(initialAttempt);

  await page.goto(`${LANDING_ORIGIN}privacy/waitlist/`);
  await page.goBack();
  await expect(status).toHaveAttribute("data-state", "ready", { timeout: 60_000 });
  const historyAttempt = await page.locator("iframe.demo-frame").getAttribute("src");
  expect(historyAttempt).not.toBe(reloadAttempt);
  expect(await page.context().cookies()).toEqual([]);
});

test("unknown landing routes are static 404s and never invoke backend compute", async ({ page }) => {
  const surface = await installLocalProductionSurface(page, {
    waitlistEnabled: false,
  });
  const response = await page.goto(`${LANDING_ORIGIN}missing-static-route`);
  expect(response?.status()).toBe(404);
  expect(surface.requests).toEqual([`${LANDING_ORIGIN}missing-static-route`]);
});
