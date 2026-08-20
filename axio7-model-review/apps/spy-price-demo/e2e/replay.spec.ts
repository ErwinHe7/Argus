import { expect, test, type Locator, type Page } from "@playwright/test";

const widths = [360, 736, 1024] as const;

function replayFrame(page: Page): Locator {
  return page.getByRole("region", {
    name: "SPY five-minute historical forecast replay",
  });
}

async function expectNoHorizontalOverflow(page: Page): Promise<void> {
  const hasHorizontalOverflow = await page.evaluate(
    () => document.documentElement.scrollWidth > document.documentElement.clientWidth,
  );
  expect(hasHorizontalOverflow).toBe(false);
}

async function expectNoCssMotion(page: Page): Promise<void> {
  const movingElements = await page.locator("#root, #root *").evaluateAll((elements) => {
    return elements.flatMap((element) => {
      const style = getComputedStyle(element);
      const hasDuration = (value: string): boolean =>
        value.split(",").some((duration) => duration.trim() !== "0s");
      return hasDuration(style.animationDuration) || hasDuration(style.transitionDuration)
        ? [element.tagName]
        : [];
    });
  });
  expect(movingElements).toEqual([]);
}

async function hoverSelectedCandle(page: Page): Promise<void> {
  const graph = page.getByRole("img", {
    name: /candlestick and volume graph/i,
  });
  const box = await graph.boundingBox();
  expect(box).not.toBeNull();
  if (box === null) return;

  const plotWidth = box.width - 58 - 18;
  const selectedCandleCenter = 58 + (plotWidth / 16) * 10.5;
  await page.mouse.move(
    box.x + selectedCandleCenter,
    box.y + Math.min(220, box.height * 0.45),
  );
}

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => window.localStorage.clear());
});

for (const width of widths) {
  test(`graph-first replay at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 800 });
    await page.goto("/");

    await expect(page.getByRole("heading", { name: "SPY" })).toBeVisible();
    const frame = replayFrame(page);
    const graph = page.getByRole("img", {
      name: /candlestick and volume graph/i,
    });
    await expect(graph).toBeVisible();
    await expect(page.getByText("UI_FIXTURE", { exact: true })).toBeVisible();
    await expect(frame).toHaveAttribute("data-theme", "light");
    await expect(graph).toHaveAttribute("data-chart-animation", "false");
    await expectNoHorizontalOverflow(page);
    await expectNoCssMotion(page);

    await page.getByRole("button", { name: "Switch to dark mode" }).click();
    await expect(frame).toHaveAttribute("data-theme", "dark");
    await expect(page.getByRole("button", { name: "Switch to light mode" })).toBeVisible();
    await expectNoHorizontalOverflow(page);
    await expectNoCssMotion(page);

    const slider = page.getByRole("slider", { name: "Replay cutoff minute" });
    await expect(slider).toHaveValue("10");
    const cutoffMarker = graph.locator('svg path[stroke-dasharray="4,2"]');
    await expect(cutoffMarker).toHaveCount(1);
    const cutoffMarkerBefore = await cutoffMarker.getAttribute("d");
    await slider.press("ArrowLeft");
    await expect(slider).toHaveValue("9");
    await expect(page).toHaveURL(/(?:\?|&)cutoff=9(?:&|$)/);
    await expect(page.getByRole("status")).toContainText("Selected cutoff 10:39 AM ET");
    const cutoffMarkerAfter = await cutoffMarker.getAttribute("d");
    expect(cutoffMarkerAfter).not.toBe(cutoffMarkerBefore);
    await page.waitForTimeout(100);
    expect(await cutoffMarker.getAttribute("d")).toBe(cutoffMarkerAfter);
    await expect(graph).toHaveAttribute("data-chart-animation", "false");

    await page.getByRole("button", { name: "Reveal +5m" }).click();
    await expect(page.getByRole("status")).toContainText("Realized");
    await expect(page.getByRole("button", { name: "Revealed" })).toBeDisabled();

    await page.getByRole("button", { name: "Switch to light mode" }).click();
    await expect(frame).toHaveAttribute("data-theme", "light");
    await expect(page.getByRole("button", { name: "Switch to dark mode" })).toBeVisible();
    await expectNoHorizontalOverflow(page);
  });
}

test("selected-candle tooltip exposes market, forecast, and evidence fields", async ({
  page,
}) => {
  await page.setViewportSize({ width: 736, height: 800 });
  await page.goto("/");
  await expect(page.getByRole("img", { name: /candlestick and volume graph/i })).toBeVisible();

  await hoverSelectedCandle(page);

  for (const label of [
    "OPEN",
    "HIGH",
    "LOW",
    "CLOSE",
    "VOLUME",
    "FORECAST DIRECTION",
    "P(UP,+5M)",
    "EXPECTED RETURN",
    "SCENARIO",
    "INTERVAL",
    "SOURCE",
    "DATASET",
    "DIRECTION MODEL",
    "RETURN MODEL",
    "QUALITY FLAGS",
    "CAVEATS",
  ]) {
    await expect(page.getByText(label, { exact: true })).toBeVisible();
  }
  await expect(page.getByText("EMBEDDED_UI_FIXTURE", { exact: true })).toBeVisible();
  for (const artifactValue of [
    "$638.720",
    "$638.780",
    "$638.600",
    "$638.660",
    "195,000",
    "0.58 · RAW_EXPERIMENTAL_PROBABILITY",
    "4.5 BPS",
    "$638.947397",
    "$638.436469—$639.5221909999999",
    "spy-demo-ui-fixture-v1",
  ]) {
    await expect(page.getByText(artifactValue, { exact: true })).toBeVisible();
  }
  await expect(page.getByText("sklearn-logistic-regression-v1", { exact: true })).toBeVisible();
  await expect(page.getByText("sklearn-ridge-v1", { exact: true })).toBeVisible();
  await expect(page.getByText("COMPLETE", { exact: true })).toBeVisible();
  await expect(
    page.getByText("UI_FIXTURE, EMBEDDED_SAMPLE_DATA, NOT_A_TRADING_SIGNAL", {
      exact: true,
    }),
  ).toBeVisible();
});

test("malformed manifest fails closed without a graph", async ({ page }) => {
  await page.route("**/fixtures/spy-demo/manifest.json", async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ contract_version: "1.0.0" }),
    });
  });

  await page.goto("/");

  await expect(page.getByRole("heading", { name: "Artifact failure" })).toBeVisible();
  await expect(page.getByText("INVALID_SCHEMA", { exact: true })).toBeVisible();
  await expect(
    page.getByRole("img", { name: /candlestick and volume graph/i }),
  ).toHaveCount(0);
});
