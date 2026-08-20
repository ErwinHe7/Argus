import { useMemo, type JSX } from "react";
import { buildReplayChartOption } from "./buildReplayChartOption";
import styles from "./ReplayGraph.module.css";
import type { ReplayChartInput } from "./types";
import { useECharts } from "./useECharts";

function formatPrice(value: number): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(value);
}

function formatTime(timestamp: string): string {
  return new Intl.DateTimeFormat("en-US", {
    hour: "numeric",
    minute: "2-digit",
    timeZone: "America/New_York",
  }).format(new Date(timestamp));
}

export function ReplayGraph(input: ReplayChartInput): JSX.Element {
  const option = useMemo(() => buildReplayChartOption(input), [input]);
  const chartRef = useECharts(option);

  return (
    <div className={styles.wrap}>
      <div className={styles.cutoff} aria-hidden="true">
        <strong>{formatPrice(input.row.close)}</strong>
        <span>{formatTime(input.row.timestamp)} ET</span>
      </div>
      <div
        ref={chartRef}
        className={styles.chart}
        role="img"
        aria-label={input.accessibleSummary}
        data-chart-animation="false"
      />
    </div>
  );
}
