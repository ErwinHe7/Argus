import { expect, test } from "@playwright/test";

import { installLocalProductionSurface, LANDING_ORIGIN } from "./support.ts";

test("landing accepts a ready demo and Reset creates a fresh frame attempt", async ({ page }) => {
  await installLocalProductionSurface(page, { demo: "mock-ready" });
  await page.goto(LANDING_ORIGIN);

  const status = page.locator("[data-demo-status]");
  await expect(status).toHaveAttribute("data-state", "ready");
  const firstAttempt = await page.locator("iframe.demo-frame").getAttribute("src");

  await page.getByRole("button", { name: "Reset Demo" }).click();
  await expect(status).toHaveAttribute("data-state", "ready");
  const secondAttempt = await page.locator("iframe.demo-frame").getAttribute("src");

  expect(firstAttempt).not.toBe(secondAttempt);
});

test("waitlist validation never reaches the API for invalid local fields", async ({ page }) => {
  const surface = await installLocalProductionSurface(page);
  await page.goto(`${LANDING_ORIGIN}#waitlist`);

  await page.locator("[data-waitlist-email]").fill("not-an-email");
  await page.locator("[data-waitlist-form]").evaluate((form) => {
    form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
  });

  await expect(page.locator("[data-waitlist-feedback]")).toContainText("Enter a valid email");
  await expect(page.locator("[data-waitlist-email]")).toHaveAttribute("aria-invalid", "true");
  expect(surface.waitlistBodies).toHaveLength(0);
});

test("waitlist success stays generic and sends the rendered consent contract", async ({ page }) => {
  const surface = await installLocalProductionSurface(page, {
    waitlist: { status: 202, body: { code: "accepted" } },
  });
  await page.goto(`${LANDING_ORIGIN}#waitlist`);

  await expect(page.locator("[data-turnstile-mount]")).toHaveAttribute("data-state", "verified");
  await page.locator("[data-waitlist-email]").fill("browser-fixture@example.invalid");
  await page.locator("[data-waitlist-consent]").check();
  await page.getByRole("button", { name: "Request a place" }).click();

  const feedback = page.locator("[data-waitlist-feedback]");
  await expect(feedback).toHaveAttribute("data-state", "success");
  await expect(feedback).toContainText("not verified");
  await expect(feedback).toContainText("no message has been sent");
  expect(surface.waitlistBodies).toEqual([{
    email: "browser-fixture@example.invalid",
    consent: true,
    noticeVersion: "waitlist-v1-2026-08-25",
    turnstileToken: "synthetic-browser-token",
  }]);
});

test("retryable waitlist failure preserves the local email and clears the one-time challenge", async ({ page }) => {
  await installLocalProductionSurface(page, {
    waitlist: { status: 503, body: { code: "dependency_unavailable", retryable: true } },
  });
  await page.goto(`${LANDING_ORIGIN}#waitlist`);

  const email = page.locator("[data-waitlist-email]");
  await expect(page.locator("[data-turnstile-mount]")).toHaveAttribute("data-state", "verified");
  await email.fill("browser-fixture@example.invalid");
  await page.locator("[data-waitlist-consent]").check();
  await page.getByRole("button", { name: "Request a place" }).click();

  await expect(page.locator("[data-waitlist-feedback]")).toHaveAttribute("data-state", "retryable");
  await expect(page.locator("[data-waitlist-feedback]")).toContainText("Your email is still here");
  await expect(email).toHaveValue("browser-fixture@example.invalid");
  await expect(page.locator("[data-turnstile-mount]")).toHaveAttribute("data-state", "verification-required");
});

test("a preview/default artifact keeps waitlist submission disabled without provider traffic", async ({ page }) => {
  const surface = await installLocalProductionSurface(page, {
    waitlistEnabled: false,
  });
  await page.goto(`${LANDING_ORIGIN}#waitlist`);

  await expect(page.getByRole("button", { name: "Request a place" })).toBeDisabled();
  await expect(page.locator("[data-waitlist-feedback]")).toContainText(
    "unavailable in this preview",
  );
  expect(surface.waitlistBodies).toEqual([]);
  expect(surface.requests.some((url) => url.includes("challenges.cloudflare.com"))).toBe(false);
});
