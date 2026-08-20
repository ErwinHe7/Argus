import type { EChartsOption } from "echarts";
import { describe, expect, it } from "vitest";
import sessionFixture from "../../../../public/fixtures/spy-demo/sessions/2026-07-24.json";
import { validateSession } from "../artifact/validateArtifact";
import { buildReplayChartOption } from "./buildReplayChartOption";
import type { ReplayChartInput } from "./types";
import type {
  ChartBar,
  ReplayRow,
  SessionArtifact,
} from "../artifact/generated/contracts";

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

function categoryLabels(option: EChartsOption): unknown[][] {
  const axes = Array.isArray(option.xAxis) ? option.xAxis : [option.xAxis];
  return axes.map((axis) => {
    if (axis === undefined || !("data" in axis) || !Array.isArray(axis.data)) {
      throw new Error("Expected a category-axis data array");
    }
    return axis.data;
  });
}

function fullSessionRow(barIndex: number): {
  row: ReplayRow;
  session: SessionArtifact;
} {
  const start = Date.parse("2026-07-24T13:30:00Z");
  const bars = Array.from({ length: 390 }, (_, index): ChartBar => {
    const timestamp = new Date(start + index * 60_000).toISOString();
    const availableAt = new Date(start + (index + 1) * 60_000).toISOString();
    const open = 600 + index / 100;
    const close = open + 0.01;
    return {
      timestamp,
      available_at: availableAt,
      open,
      high: close + 0.01,
      low: open - 0.01,
      close,
      volume: 100_000 + index,
      direction: "UP",
      quality_flags: [],
    };
  });
  const cutoffBar = bars[barIndex]!;
  const outcomeIndex = barIndex + 5;
  const outcomeBar = bars[outcomeIndex]!;
  const sourceRow = session.rows[0]!;
  const row: ReplayRow = {
    ...sourceRow,
    bar_index: barIndex,
    timestamp: cutoffBar.timestamp,
    available_at: cutoffBar.available_at,
    open: cutoffBar.open!,
    high: cutoffBar.high!,
    low: cutoffBar.low!,
    close: cutoffBar.close!,
    volume: cutoffBar.volume!,
    outcome: {
      ...sourceRow.outcome,
      bar_index: outcomeIndex,
      timestamp: outcomeBar.timestamp,
      available_at: outcomeBar.available_at,
      close: outcomeBar.close!,
    },
  };
  return {
    row,
    session: { ...session, bars: bars as SessionArtifact["bars"], rows: [row] },
  };
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
    expect(Array.isArray(shownCandles) && shownCandles.at(-1)).not.toBe("-");
    expect(
      Array.isArray(seriesByType(hidden, "candlestick").data) &&
        (seriesByType(hidden, "candlestick").data as unknown[]).at(-1),
    ).toBe("-");
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

  it("disables emphasis for every palette-bearing series", () => {
    const option = buildReplayChartOption(makeReplayInput(false));
    const series = Array.isArray(option.series) ? option.series : [];

    for (const name of ["OHLC", "Forecast", "Interval", "Volume"]) {
      expect(series.find((candidate) => candidate.name === name)).toEqual(
        expect.objectContaining({ emphasis: { disabled: true } }),
      );
    }
  });

  it.each([
    ["early", 0],
    ["middle", 194],
    ["latest", 384],
  ] as const)(
    "bounds the real-size %s x-domain at the explicit outcome endpoint",
    (_position, barIndex) => {
      const { row, session: fullSession } = fullSessionRow(barIndex);
      const option = buildReplayChartOption({
        ...makeReplayInput(false),
        session: fullSession,
        row,
      });
      const expectedLength = row.outcome.bar_index + 1;

      for (const labels of categoryLabels(option)) {
        expect(labels).toHaveLength(expectedLength);
        expect(labels.at(-1)).toBe(row.outcome.timestamp);
        if (expectedLength < fullSession.bars.length) {
          expect(labels).not.toContain(fullSession.bars.at(-1)!.timestamp);
        }
      }
      for (const type of ["candlestick", "line", "bar"]) {
        const data = seriesByType(option, type).data;
        expect(Array.isArray(data) ? data.length : -1).toBe(expectedLength);
      }
      expect(visibleCandleCount(option)).toBe(row.bar_index + 1);
      expect(visibleVolumeCount(option)).toBe(row.bar_index + 1);
    },
  );

  it("formats UTC artifact timestamps as Eastern Time axis labels", () => {
    const option = buildReplayChartOption(makeReplayInput(false));
    const axes = Array.isArray(option.xAxis) ? option.xAxis : [];
    const axisLabel = axes[1]?.axisLabel;
    if (
      axisLabel === undefined ||
      typeof axisLabel !== "object" ||
      !("formatter" in axisLabel) ||
      typeof axisLabel.formatter !== "function"
    ) {
      throw new Error("Expected the lower x-axis label formatter");
    }

    const formatter = axisLabel.formatter as (
      value: string,
      index: number,
      extra: undefined,
    ) => string;
    expect(formatter("2026-07-24T14:30:00Z", 0, undefined)).toBe("10:30 AM");
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

  it("disables HTML tooltip movement and display transitions", () => {
    const option = buildReplayChartOption(makeReplayInput(false));

    expect(option.tooltip).toEqual(
      expect.objectContaining({
        renderMode: "html",
        enterable: true,
        transitionDuration: 0,
        displayTransition: false,
        extraCssText: expect.stringContaining("overflow:auto"),
        axisPointer: expect.objectContaining({
          animation: false,
          animationDurationUpdate: 0,
        }),
      }),
    );
  });
});
