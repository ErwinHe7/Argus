import type { CustomSeriesRenderItem, EChartsOption } from "echarts";
import type { ChartBar } from "../artifact/generated/contracts";
import { formatTooltip } from "./formatTooltip";
import type { ChartTheme, ReplayChartInput } from "./types";

type VisibleCandle = {
  value: [number, number, number, number];
  itemStyle: {
    color: string;
    color0: string;
    borderColor: string;
    borderColor0: string;
    opacity: number;
  };
};

type VisibleVolume = {
  value: number;
  itemStyle: {
    color: string;
    opacity: number;
  };
};

function directionColor(bar: ChartBar, theme: ChartTheme): string {
  if (bar.direction === "UP") {
    return theme.up;
  }
  if (bar.direction === "DOWN") {
    return theme.down;
  }
  return theme.foreground;
}

function forecastColor(input: ReplayChartInput): string {
  if (input.row.forecast.direction === "UP") {
    return input.theme.up;
  }
  if (input.row.forecast.direction === "DOWN") {
    return input.theme.down;
  }
  return input.theme.foreground;
}

function qualityOpacity(bar: ChartBar): number {
  return bar.quality_flags.length === 0 ? 1 : 0.65;
}

function candleData(bar: ChartBar, theme: ChartTheme): VisibleCandle | "-" {
  if (
    bar.open === null ||
    bar.close === null ||
    bar.low === null ||
    bar.high === null
  ) {
    return "-";
  }

  const color = directionColor(bar, theme);
  return {
    value: [bar.open, bar.close, bar.low, bar.high],
    itemStyle: {
      color,
      color0: color,
      borderColor: color,
      borderColor0: color,
      opacity: qualityOpacity(bar),
    },
  };
}

function volumeData(bar: ChartBar, theme: ChartTheme): VisibleVolume | "-" {
  if (bar.volume === null) {
    return "-";
  }

  return {
    value: bar.volume,
    itemStyle: {
      color: directionColor(bar, theme),
      opacity: qualityOpacity(bar),
    },
  };
}

function tooltipBarIndex(params: unknown, fallback: number): number {
  const candidates = Array.isArray(params) ? params : [params];
  for (const candidate of candidates) {
    if (
      candidate !== null &&
      typeof candidate === "object" &&
      "dataIndex" in candidate &&
      typeof candidate.dataIndex === "number"
    ) {
      return candidate.dataIndex;
    }
  }
  return fallback;
}

export function buildReplayChartOption(input: ReplayChartInput): EChartsOption {
  const option: EChartsOption = {
    animation: false,
    animationDuration: 0,
    animationDurationUpdate: 0,
    backgroundColor: input.theme.background,
    aria: {
      enabled: true,
      description: input.accessibleSummary,
    },
  };

  const lastVisibleIndex = input.row.bar_index + (input.revealed ? 5 : 0);
  const outcomeIndex = input.row.bar_index + 5;
  const labels = input.session.bars.map((bar) => bar.timestamp);
  const candles = input.session.bars.map((bar, index) => {
    return index <= lastVisibleIndex ? candleData(bar, input.theme) : "-";
  });
  const volumes = input.session.bars.map((bar, index) => {
    return index <= lastVisibleIndex ? volumeData(bar, input.theme) : "-";
  });
  const forecast = input.session.bars.map<number | null>(() => null);
  forecast[input.row.bar_index] = input.row.close;
  forecast[outcomeIndex] = input.row.forecast.scenario_price;
  const trendColor = forecastColor(input);

  const renderIntervalWhisker: CustomSeriesRenderItem = (_params, api) => {
    const lowerPoint = api.coord([api.value(0), api.value(1)]);
    const upperPoint = api.coord([api.value(0), api.value(2)]);
    const [lowerX, lowerY] = lowerPoint;
    const [upperX, upperY] = upperPoint;

    if (
      lowerX === undefined ||
      lowerY === undefined ||
      upperX === undefined ||
      upperY === undefined
    ) {
      return null;
    }

    return {
      type: "group",
      children: [
        {
          type: "line",
          shape: {
            x1: lowerX,
            y1: lowerY,
            x2: upperX,
            y2: upperY,
          },
          style: { stroke: trendColor, lineWidth: 2 },
        },
        {
          type: "line",
          shape: {
            x1: lowerX - 5,
            y1: lowerY,
            x2: lowerX + 5,
            y2: lowerY,
          },
          style: { stroke: trendColor, lineWidth: 2 },
        },
        {
          type: "line",
          shape: {
            x1: upperX - 5,
            y1: upperY,
            x2: upperX + 5,
            y2: upperY,
          },
          style: { stroke: trendColor, lineWidth: 2 },
        },
      ],
    };
  };

  Object.assign(option, {
    axisPointer: {
      link: [{ xAxisIndex: "all" }],
      label: {
        backgroundColor: input.theme.foreground,
        color: input.theme.background,
        borderColor: input.theme.foreground,
      },
    },
    grid: [
      { left: 58, right: 18, top: 34, height: "66%" },
      { left: 58, right: 18, top: "81%", height: "11%" },
    ],
    xAxis: [
      {
        type: "category",
        data: labels,
        boundaryGap: true,
        axisLine: { lineStyle: { color: input.theme.foreground } },
        axisTick: { show: false },
        axisLabel: { show: false, color: input.theme.foreground },
        splitLine: { show: false },
      },
      {
        type: "category",
        gridIndex: 1,
        data: labels,
        boundaryGap: true,
        axisLine: { lineStyle: { color: input.theme.foreground } },
        axisTick: { show: false },
        axisLabel: {
          color: input.theme.foreground,
          fontSize: 11,
          formatter: (timestamp: string) => timestamp.slice(11, 16),
        },
        splitLine: { show: false },
      },
    ],
    yAxis: [
      {
        scale: true,
        axisLine: {
          show: true,
          lineStyle: { color: input.theme.foreground },
        },
        axisTick: { show: false },
        axisLabel: { color: input.theme.foreground, fontSize: 11 },
        splitLine: {
          lineStyle: { color: input.theme.foreground, opacity: 0.18 },
        },
      },
      {
        gridIndex: 1,
        axisLine: {
          show: true,
          lineStyle: { color: input.theme.foreground },
        },
        axisTick: { show: false },
        axisLabel: { show: false, color: input.theme.foreground },
        splitLine: { show: false },
      },
    ],
    tooltip: {
      trigger: "axis",
      triggerOn: "mousemove|click",
      confine: true,
      renderMode: "html",
      transitionDuration: 0,
      displayTransition: false,
      backgroundColor: input.theme.background,
      borderColor: input.theme.foreground,
      borderWidth: 1,
      padding: 0,
      extraCssText: "box-shadow:none;border-radius:0;",
      textStyle: { color: input.theme.foreground },
      axisPointer: {
        type: "cross",
        lineStyle: { color: input.theme.foreground, width: 1 },
        crossStyle: { color: input.theme.foreground },
      },
      formatter: (params: unknown) => {
        return formatTooltip({
          session: input.session,
          row: input.row,
          barIndex: tooltipBarIndex(params, input.row.bar_index),
          revealed: input.revealed,
          theme: input.theme,
        });
      },
    },
    series: [
      {
        name: "OHLC",
        type: "candlestick",
        data: candles,
        markLine: {
          silent: true,
          symbol: ["none", "none"],
          label: { show: false, color: input.theme.foreground },
          lineStyle: {
            color: input.theme.foreground,
            type: "dashed",
            width: 1,
          },
          data: [{ xAxis: labels[input.row.bar_index] }],
        },
      },
      {
        name: "Forecast",
        type: "line",
        data: forecast,
        connectNulls: true,
        symbol: "diamond",
        symbolSize: 8,
        lineStyle: { color: trendColor, width: 2, type: "dashed" },
        itemStyle: { color: trendColor },
      },
      {
        name: "Interval",
        type: "custom",
        data: [
          [
            outcomeIndex,
            input.row.forecast.interval_low,
            input.row.forecast.interval_high,
          ],
        ],
        renderItem: renderIntervalWhisker,
        encode: { x: 0, y: [1, 2] },
        tooltip: { show: false },
      },
      {
        name: "Volume",
        type: "bar",
        xAxisIndex: 1,
        yAxisIndex: 1,
        data: volumes,
        barMaxWidth: 7,
      },
    ],
  });

  return option;
}
