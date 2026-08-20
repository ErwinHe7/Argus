import { useMemo, type JSX } from "react";
import { formatEasternTimestamp, formatUsd } from "../formatters";
import { buildReplayChartOption } from "./buildReplayChartOption";
import styles from "./ReplayGraph.module.css";
import type { ReplayChartInput } from "./types";
import { useECharts } from "./useECharts";

export function ReplayGraph(input: ReplayChartInput): JSX.Element {
  const option = useMemo(() => buildReplayChartOption(input), [input]);
  const chartRef = useECharts(option);

  return (
    <div className={styles.wrap}>
      <div className={styles.cutoff} aria-hidden="true">
        <strong>{formatUsd(input.row.close, 2)}</strong>
        <span>{formatEasternTimestamp(input.row.available_at)}</span>
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
