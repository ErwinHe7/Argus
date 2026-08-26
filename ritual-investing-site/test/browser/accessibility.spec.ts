import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "@playwright/test";

import { DEMO_ORIGIN, installLocalProductionSurface, LANDING_ORIGIN } from "./support.ts";

async function expectNoSeriousAccessibilityViolations(page: Page): Promise<void> {
  const result = await new AxeBuilder({ page }).analyze();
  const seriousViolations = result.violations.filter(
    (violation) => violation.impact === "serious" || violation.impact === "critical",
  );
  expect(seriousViolations).toEqual([]);
}

test("landing, embedded demo, and privacy notice have no serious automated violations", async ({ page }) => {
  test.setTimeout(120_000);
  await installLocalProductionSurface(page, { demo: "real" });
  await page.goto(LANDING_ORIGIN);
  await expect(page.locator("[data-demo-status]")).toHaveAttribute("data-state", "ready", { timeout: 60_000 });
  await expectNoSeriousAccessibilityViolations(page);

  await page.goto(DEMO_ORIGIN);
  await expect(page.locator("flt-semantics-host")).toBeAttached({ timeout: 60_000 });
  await expect(page.getByText("YOUR DAILY SIGNAL", { exact: true })).toBeVisible();
  await expectNoSeriousAccessibilityViolations(page);

  await page.goto(`${LANDING_ORIGIN}privacy/waitlist/`);
  await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
  await expectNoSeriousAccessibilityViolations(page);
});

test("validation and retry feedback are announced without losing the entered value", async ({ page }) => {
  await installLocalProductionSurface(page, {
    waitlist: { status: 503, body: { code: "dependency_unavailable", retryable: true } },
  });
  await page.goto(`${LANDING_ORIGIN}#waitlist`);

  const email = page.locator("[data-waitlist-email]");
  const feedback = page.locator("[data-waitlist-feedback]");
  await email.fill("invalid-address");
  await page.locator("[data-waitlist-form]").evaluate((form) => {
    form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
  });
  await expect(email).toHaveAttribute("aria-invalid", "true");
  await expect(feedback).toHaveAttribute("role", "status");
  await expect(feedback).toContainText("Enter a valid email");

  await email.fill("accessible-browser@example.invalid");
  await page.locator("[data-waitlist-consent]").check();
  await page.getByRole("button", { name: "Request a place" }).click();

  await expect(feedback).toHaveAttribute("data-state", "retryable");
  await expect(email).toHaveValue("accessible-browser@example.invalid");
  await expectNoSeriousAccessibilityViolations(page);
});
