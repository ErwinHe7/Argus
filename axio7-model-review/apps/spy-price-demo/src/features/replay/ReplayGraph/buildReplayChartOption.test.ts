import type { EChartsOption } from "echarts";
import { describe, expect, it } from "vitest";
import sessionFixture from "../../../../public/fixtures/spy-demo/sessions/2026-07-24.json";
import { validateSession } from "../artifact/validateArtifact";
import { buildReplayChartOption } from "./buildReplayChartOption";
import type { ReplayChartInput } from "./types";
import type { ReplayRow } from "../artifact/generated/contracts";

const session = validateSession(sessionFixture);

function requireMiddleFixtureRow(): ReplayRow {
  const row = session.rows[5];
  if (row === undefined) {
    throw new Error(
      "The committed session fixture must contain its middle replay row",
    );
  }
  return row;
}

const middleFixtureRow = requireMiddleFixtureRow();

function makeReplayInput(revealed: boolean): ReplayChartInput {
  return {
    session,
    row: middleFixtureRow,
    revealed,
    theme: {
      background: "#ffffff",
      foreground: "#000000",
      up: "#00a36c",
      down: "#e2382f",
    },
    accessibleSummary: `SPY cutoff ${middleFixtureRow.timestamp}`,
  };
}

function seriesByType(
  option: EChartsOption,
  type: string,
): Record<string, unknown> {
  const series = Array.isArray(option.series) ? option.series : [option.series];
  const match = series.find((candidate) => {
    return (
      candidate !== undefined &&
      candidate !== null &&
      typeof candidate === "object" &&
      "type" in candidate &&
      candidate.type === type
    );
  });

  if (match === undefined || match === null || typeof match !== "object") {
    throw new Error(`Expected ${type} series`);
  }

  return match as Record<string, unknown>;
}

function visibleCandleCount(option: EChartsOption): number {
  const candleSeries = seriesByType(option, "candlestick");
  const data = candleSeries.data;

  if (!Array.isArray(data)) {
    throw new Error("Expected candlestick data array");
  }

  return data.filter((entry) => entry !== "-").length;
}

function visibleVolumeCount(option: EChartsOption): number {
  const volumeSeries = seriesByType(option, "bar");
  const data = volumeSeries.data;

  if (!Array.isArray(data)) {
    throw new Error("Expected volume data array");
  }

  return data.filter((entry) => entry !== "-").length;
}

describe("buildReplayChartOption", () => {
  it("disables every animation path", () => {
    const option = buildReplayChartOption(makeReplayInput(false));

    expect(option.animation).toBe(false);
    expect(option.animationDuration).toBe(0);
    expect(option.animationDurationUpdate).toBe(0);
  });

  it("uses the ordered artifact scenario and interval values without recomputing them", () => {
    const input = makeReplayInput(false);
    const option = buildReplayChartOption(input);
    const series = Array.isArray(option.series) ? option.series : [option.series];
    const forecast = series.find(
      (candidate) => candidate !== undefined && candidate?.name === "Forecast",
    );
    const interval = series.find(
      (candidate) => candidate !== undefined && candidate?.name === "Interval",
    );

    expect(forecast?.data).toContain(input.row.forecast.scenario_price);
    expect(interval?.data).toEqual([
      [
        input.row.bar_index + 5,
        input.row.forecast.interval_low,
        input.row.forecast.interval_high,
      ],
    ]);
  });

  it("does not expose future candles before reveal and reveals exactly the next five", () => {
    const input = makeReplayInput(false);
    const hidden = buildReplayChartOption(input);
    const shown = buildReplayChartOption({ ...input, revealed: true });

    expect(visibleCandleCount(hidden)).toBe(input.row.bar_index + 1);
    expect(visibleCandleCount(shown)).toBe(input.row.bar_index + 6);
    expect(visibleVolumeCount(hidden)).toBe(input.row.bar_index + 1);
    expect(visibleVolumeCount(shown)).toBe(input.row.bar_index + 6);

    const shownCandles = seriesByType(shown, "candlestick").data;
    expect(Array.isArray(shownCandles) && shownCandles.at(-1)).toBe("-");
  });

  it("preserves an ordered one-sided interval outside its stored scenario", () => {
    const input = makeReplayInput(false);
    const oneSidedRow: ReplayRow = {
      ...input.row,
      forecast: {
        ...input.row.forecast,
        scenario_price: 638,
        interval_low: 639,
        interval_high: 640,
      },
    };
    const option = buildReplayChartOption({ ...input, row: oneSidedRow });
    const series = Array.isArray(option.series) ? option.series : [];

    expect(series.find((candidate) => candidate.name === "Forecast")?.data).toContain(
      638,
    );
    expect(series.find((candidate) => candidate.name === "Interval")?.data).toEqual([
      [oneSidedRow.bar_index + 5, 639, 640],
    ]);
  });

  it("does not mutate the validated session artifact", () => {
    const input = makeReplayInput(true);
    const originalSession = structuredClone(input.session);

    buildReplayChartOption(input);

    expect(input.session).toEqual(originalSession);
  });

  it("uses artifact directions for candle, volume, and forecast trend colors", () => {
    const input = makeReplayInput(false);
    const option = buildReplayChartOption(input);
    const candles = seriesByType(option, "candlestick").data;
    const volumes = seriesByType(option, "bar").data;
    const forecast = (Array.isArray(option.series) ? option.series : []).find(
      (candidate) => candidate.name === "Forecast",
    );
    const forecastRecord = forecast as Record<string, unknown> | undefined;

    expect(candles).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          itemStyle: expect.objectContaining({ color: input.theme.up }),
        }),
        expect.objectContaining({
          itemStyle: expect.objectContaining({ color: input.theme.down }),
        }),
      ]),
    );
    expect(volumes).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          itemStyle: expect.objectContaining({ color: input.theme.up }),
        }),
        expect.objectContaining({
          itemStyle: expect.objectContaining({ color: input.theme.down }),
        }),
      ]),
    );
    expect(forecastRecord?.lineStyle).toEqual(
      expect.objectContaining({
        color: input.theme.up,
        type: "dashed",
      }),
    );

    const flatOption = buildReplayChartOption({
      ...input,
      row: {
        ...input.row,
        forecast: { ...input.row.forecast, direction: "FLAT" },
      },
    });
    const flatForecast = (
      Array.isArray(flatOption.series) ? flatOption.series : []
    ).find((candidate) => candidate.name === "Forecast") as
      | Record<string, unknown>
      | undefined;

    expect(flatForecast?.lineStyle).toEqual(
      expect.objectContaining({ color: input.theme.foreground }),
    );
  });

  it("links monochrome crosshairs and exposes the supplied accessible summary", () => {
    const input = makeReplayInput(false);
    const option = buildReplayChartOption(input);

    expect(option.aria).toEqual(
      expect.objectContaining({
        enabled: true,
        description: input.accessibleSummary,
      }),
    );
    expect(option.axisPointer).toEqual(
      expect.objectContaining({ link: [{ xAxisIndex: "all" }] }),
    );
    expect(option.tooltip).toEqual(
      expect.objectContaining({
        confine: true,
        renderMode: "html",
        backgroundColor: input.theme.background,
        borderColor: input.theme.foreground,
      }),
    );
  });
});
