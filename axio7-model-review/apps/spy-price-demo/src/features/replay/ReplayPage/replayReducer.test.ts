import { describe, expect, it } from "vitest";
import { replayReducer } from "./replayReducer";

describe("replayReducer", () => {
  it("snaps to a new cutoff and hides the prior outcome", () => {
    const state = {
      sessionDate: "2026-07-24",
      cutoffIndex: 20,
      revealed: true,
    } as const;

    expect(replayReducer(state, { type: "setCutoff", cutoffIndex: 21 })).toEqual({
      sessionDate: "2026-07-24",
      cutoffIndex: 21,
      revealed: false,
    });
  });

  it("resets cutoff and reveal when the session changes", () => {
    const state = {
      sessionDate: "2026-07-24",
      cutoffIndex: 20,
      revealed: true,
    } as const;

    expect(
      replayReducer(state, { type: "setSession", sessionDate: "2026-07-23" }),
    ).toEqual({
      sessionDate: "2026-07-23",
      cutoffIndex: 0,
      revealed: false,
    });
  });

  it("reveals the selected outcome without changing its session or cutoff", () => {
    const state = {
      sessionDate: "2026-07-24",
      cutoffIndex: 20,
      revealed: false,
    } as const;

    expect(replayReducer(state, { type: "reveal" })).toEqual({
      sessionDate: "2026-07-24",
      cutoffIndex: 20,
      revealed: true,
    });
  });
});
