import { describe, expect, it } from "vitest";
import sessionFixture from "../../../../public/fixtures/spy-demo/sessions/2026-07-24.json";
import { validateSession } from "../artifact/validateArtifact";
import type { ReplayRow } from "../artifact/generated/contracts";
import { formatTooltip } from "./formatTooltip";
import type { TooltipInput } from "./types";

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

function makeTooltipInput(revealed: boolean): TooltipInput {
  return {
    session,
    row: middleFixtureRow,
    barIndex: middleFixtureRow.bar_index,
    revealed,
    theme: {
      background: "#ffffff",
      foreground: "#000000",
      up: "#00a36c",
      down: "#e2382f",
    },
  };
}

describe("formatTooltip", () => {
  it("puts cutoff OHLCV, forecast, provenance, quality, versions, hashes, and caveats in the graph tooltip", () => {
    const input = makeTooltipInput(false);
    const markup = formatTooltip(input);
    const { row, session: currentSession } = input;

    expect(markup).toContain(`$${row.open.toFixed(3)}`);
    expect(markup).toContain(`$${row.high.toFixed(3)}`);
    expect(markup).toContain(`$${row.low.toFixed(3)}`);
    expect(markup).toContain(`$${row.close.toFixed(3)}`);
    expect(markup).toContain(row.volume.toLocaleString("en-US"));
    expect(markup).toContain("P(UP,+5M)");
    expect(markup).toContain(String(row.forecast.probability_up));
    expect(markup).toContain(String(row.forecast.expected_return_bps));
    expect(markup).toContain(String(row.forecast.scenario_price));
    expect(markup).toContain(String(row.forecast.interval_low));
    expect(markup).toContain(String(row.forecast.interval_high));
    expect(markup).toContain(currentSession.provenance.source);
    expect(markup).toContain(
      `<span>SESSION STATUS</span><b style="text-align:right">${currentSession.status}`,
    );
    expect(markup).toContain(
      `<span>CONTRACT</span><b style="text-align:right">${currentSession.contract_version}`,
    );
    expect(markup).toContain(currentSession.provenance.source_cutoff);
    expect(markup).toContain(row.available_at);
    expect(markup).toContain(currentSession.provenance.availability_cutoff);
    expect(markup).toContain(currentSession.provenance.coverage);
    expect(markup).toContain("COMPLETE");
    expect(markup).toContain(currentSession.provenance.feature_version);
    expect(markup).toContain(currentSession.provenance.direction_model_version);
    expect(markup).toContain(currentSession.provenance.return_model_version);
    expect(markup).toContain(
      currentSession.provenance.artifact_sha256.slice(0, 12),
    );
    for (const caveat of currentSession.provenance.caveat_codes) {
      expect(markup).toContain(caveat);
    }
  });

  it("adds the stored realized close and return only after reveal", () => {
    const input = makeTooltipInput(false);
    const hidden = formatTooltip(input);
    const shown = formatTooltip({ ...input, revealed: true });

    expect(hidden).not.toContain("REALIZED CLOSE");
    expect(hidden).not.toContain("REALIZED RETURN");
    expect(shown).toContain("REALIZED CLOSE");
    expect(shown).toContain(String(input.row.outcome.close));
    expect(shown).toContain("REALIZED RETURN");
    expect(shown).toContain(String(input.row.outcome.return_bps));
  });

  it("does not expose a future bar through tooltip formatting before reveal", () => {
    const input = makeTooltipInput(false);
    const outcomeBarIndex = input.row.bar_index + 5;

    expect(
      formatTooltip({ ...input, barIndex: outcomeBarIndex }),
    ).toBe("");
    expect(
      formatTooltip({ ...input, barIndex: outcomeBarIndex, revealed: true }),
    ).toContain("REALIZED CLOSE");
  });

  it("uses no markup colors outside the current monochrome and graph trend palette", () => {
    const input = makeTooltipInput(true);
    const markup = formatTooltip(input);
    const colors = markup.match(/#[0-9a-f]{6}/gi) ?? [];

    const allowedColors: ReadonlySet<string> = new Set([
      input.theme.background,
      input.theme.foreground,
      input.theme.up,
      input.theme.down,
    ]);
    expect(colors.every((color) => allowedColors.has(color))).toBe(true);

    const darkMarkup = formatTooltip({
      ...input,
      theme: {
        background: "#000000",
        foreground: "#ffffff",
        up: "#00a36c",
        down: "#e2382f",
      },
    });
    const darkColors = darkMarkup.match(/#[0-9a-f]{6}/gi) ?? [];

    expect(
      darkColors.every((color) =>
        new Set(["#000000", "#ffffff", "#00a36c", "#e2382f"]).has(
          color,
        ),
      ),
    ).toBe(true);
  });
});
