import type { ChartBar } from "../artifact/generated/contracts";
import {
  formatEasternTimestamp,
  formatProbability,
  formatSignedBasisPoints,
  formatUsd,
  formatVolume,
} from "../formatters";
import type { ChartTheme, TooltipInput } from "./types";

const ARTIFACT_HASH_PREFIX_LENGTH = 12;

function escapeHtml(value: string | number): string {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function formatPrice(value: number | null): string {
  return value === null ? "UNAVAILABLE" : formatUsd(value);
}

function directionColor(
  direction: "UP" | "DOWN" | "FLAT",
  theme: ChartTheme,
): string {
  if (direction === "UP") {
    return theme.up;
  }
  if (direction === "DOWN") {
    return theme.down;
  }
  return theme.foreground;
}

function row(label: string, value: string, valueColor?: string): string {
  const color = valueColor === undefined ? "" : `;color:${valueColor}`;
  return `<div style="display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1.35fr);align-items:start;gap:8px 12px"><span style="min-width:0">${escapeHtml(label)}</span><b style="min-width:0;text-align:right;overflow-wrap:anywhere${color}">${escapeHtml(value)}</b></div>`;
}

function section(content: string, foreground: string): string {
  return `<div style="border-top:1px solid ${foreground};margin-top:8px;padding-top:8px">${content}</div>`;
}

function formatQuality(bar: ChartBar, isCutoff: boolean, input: TooltipInput): string {
  const flags = isCutoff ? input.row.quality_flags : bar.quality_flags;
  return flags.length === 0 ? "COMPLETE" : flags.join(", ");
}

export function formatTooltip(input: TooltipInput): string {
  const { row: replayRow, session, theme } = input;
  const lastVisibleIndex = input.revealed
    ? replayRow.outcome.bar_index
    : replayRow.bar_index;
  const bar = session.bars[input.barIndex];

  if (bar === undefined || input.barIndex > lastVisibleIndex) {
    return "";
  }

  const isCutoff = input.barIndex === replayRow.bar_index;
  const isOutcome = input.barIndex === replayRow.outcome.bar_index;
  const trendColor = directionColor(replayRow.forecast.direction, theme);
  const marketRows = [
    row("OPEN", formatPrice(bar.open)),
    row("HIGH", formatPrice(bar.high)),
    row("LOW", formatPrice(bar.low)),
    row("CLOSE", formatPrice(bar.close)),
    row("VOLUME", bar.volume === null ? "UNAVAILABLE" : formatVolume(bar.volume)),
    row("DIRECTION", bar.direction, directionColor(bar.direction, theme)),
    row("QUALITY FLAGS", formatQuality(bar, isCutoff, input)),
  ].join("");

  const forecastRows = isCutoff
    ? section(
        [
          row(
            "FORECAST DIRECTION",
            replayRow.forecast.direction,
            trendColor,
          ),
          row(
            "P(UP,+5M)",
            `${formatProbability(replayRow.forecast.probability_up)} · ${replayRow.forecast.probability_status}`,
          ),
          row(
            "EXPECTED RETURN",
            formatSignedBasisPoints(replayRow.forecast.expected_return_bps),
          ),
          row("SCENARIO", formatUsd(replayRow.forecast.scenario_price)),
          row(
            "INTERVAL",
            `${formatUsd(replayRow.forecast.interval_low)}—${formatUsd(replayRow.forecast.interval_high)}`,
          ),
          row("INTERVAL STATUS", replayRow.forecast.interval_status),
        ].join(""),
        theme.foreground,
      )
    : "";

  const provenanceRows = isCutoff
    ? section(
        [
          row("SESSION STATUS", session.status),
          row("CONTRACT", session.contract_version),
          row("SOURCE", session.provenance.source),
          row("DATASET", session.provenance.dataset),
          row(
            "SOURCE CUTOFF",
            formatEasternTimestamp(session.provenance.source_cutoff),
          ),
          row("AVAILABLE", formatEasternTimestamp(replayRow.available_at)),
          row(
            "AVAILABILITY CUTOFF",
            formatEasternTimestamp(session.provenance.availability_cutoff),
          ),
          row("COVERAGE", session.provenance.coverage),
          row("CALENDAR", session.provenance.calendar_version),
          row("FEATURE VERSION", session.provenance.feature_version),
          row(
            "DIRECTION MODEL",
            session.provenance.direction_model_version,
          ),
          row("RETURN MODEL", session.provenance.return_model_version),
          row(
            "ARTIFACT",
            session.provenance.artifact_sha256.slice(
              0,
              ARTIFACT_HASH_PREFIX_LENGTH,
            ),
          ),
          row(
            "DATASET HASH",
            session.provenance.dataset_sha256.slice(
              0,
              ARTIFACT_HASH_PREFIX_LENGTH,
            ),
          ),
          row("CAVEATS", session.provenance.caveat_codes.join(", ")),
        ].join(""),
        theme.foreground,
      )
    : "";

  const outcomeRows =
    input.revealed && (isCutoff || isOutcome)
      ? section(
          [
            row("REALIZED AT", formatEasternTimestamp(replayRow.outcome.timestamp)),
            row(
              "REALIZED AVAILABLE",
              formatEasternTimestamp(replayRow.outcome.available_at),
            ),
            row("REALIZED CLOSE", formatUsd(replayRow.outcome.close)),
            row(
              "REALIZED RETURN",
              formatSignedBasisPoints(replayRow.outcome.return_bps),
            ),
          ].join(""),
          theme.foreground,
        )
      : "";

  return `<div data-spy-tooltip="true" role="tooltip" tabindex="0" style="width:420px;max-width:100%;min-width:0;padding:10px 11px;color:${theme.foreground};background:${theme.background};overflow-wrap:anywhere;font:11px/1.55 Helvetica,Arial,sans-serif"><div style="display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:8px 12px;font-weight:500"><span style="min-width:0">${escapeHtml(session.symbol)} · ${escapeHtml(session.session_date)}</span><span style="min-width:0;text-align:right">${escapeHtml(formatEasternTimestamp(bar.timestamp))}</span></div>${section(marketRows, theme.foreground)}${forecastRows}${provenanceRows}${outcomeRows}</div>`;
}
