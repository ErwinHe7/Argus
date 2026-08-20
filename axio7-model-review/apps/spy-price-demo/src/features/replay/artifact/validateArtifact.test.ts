import fixtureManifest from "../../../../public/fixtures/spy-demo/manifest.json";
import fixtureModelCard from "../../../../public/fixtures/spy-demo/model-card.json";
import fixtureSession from "../../../../public/fixtures/spy-demo/sessions/2026-07-24.json";
import fixtureSessionIndex from "../../../../public/fixtures/spy-demo/sessions/index.json";
import fixtureSummary from "../../../../public/fixtures/spy-demo/summary.json";
import { ArtifactError } from "./ArtifactError";
import type {
  SessionArtifact,
  SessionIndexArtifact,
} from "./generated/contracts";
import {
  validateManifest,
  validateModelCard,
  validateSession,
  validateSessionIndex,
  validateSummary,
} from "./validateArtifact";

function captureArtifactError(operation: () => unknown): ArtifactError {
  try {
    operation();
  } catch (error) {
    expect(error).toBeInstanceOf(ArtifactError);
    if (error instanceof ArtifactError) return error;
    throw error;
  }

  throw new Error("Expected an ArtifactError");
}

function sessionClone(): SessionArtifact {
  return structuredClone(fixtureSession) as SessionArtifact;
}

function indexClone(): SessionIndexArtifact {
  return structuredClone(fixtureSessionIndex) as SessionIndexArtifact;
}

describe("artifact validators", () => {
  it("accepts all committed fixture artifacts", () => {
    expect(validateManifest(fixtureManifest).status).toBe("UI_FIXTURE");
    expect(validateSessionIndex(fixtureSessionIndex).sessions).toHaveLength(1);
    expect(validateSession(fixtureSession).session_date).toBe("2026-07-24");
    expect(validateSummary(fixtureSummary).contract_version).toBe("1.0.0");
    expect(validateModelCard(fixtureModelCard).horizon_minutes).toBe(5);
  });

  it("rejects unsupported contract versions distinctly", () => {
    const invalid = { ...fixtureManifest, contract_version: "2.0.0" };

    const error = captureArtifactError(() => validateManifest(invalid));

    expect(error.code).toBe("UNSUPPORTED_VERSION");
    expect(error.message).not.toContain("2.0.0");
  });

  it("rejects unknown fields without exposing validator details in the message", () => {
    const invalid = { ...fixtureManifest, invented: true };

    const error = captureArtifactError(() => validateManifest(invalid));

    expect(error.code).toBe("INVALID_SCHEMA");
    expect(error.details).toBeDefined();
    expect(error.message).not.toContain("invented");
  });

  it("rejects a reversed forecast interval with the semantic validator", () => {
    const invalid = sessionClone();
    invalid.rows[0]!.forecast.interval_low = 640;
    invalid.rows[0]!.forecast.interval_high = 639;

    expect(() => validateSession(invalid)).toThrowError(ArtifactError);
  });

  it("accepts an ordered one-sided interval that does not contain the scenario", () => {
    const valid = sessionClone();
    valid.rows[0]!.forecast.scenario_price =
      valid.rows[0]!.forecast.interval_high + 1;

    expect(validateSession(valid).rows[0]!.forecast.scenario_price).toBe(
      valid.rows[0]!.forecast.scenario_price,
    );
  });

  it.each([
    {
      name: "a null bar without the unresolved-gap flag",
      change(session: SessionArtifact): void {
        session.bars[0]!.open = null;
        session.bars[0]!.high = null;
        session.bars[0]!.low = null;
        session.bars[0]!.close = null;
        session.bars[0]!.volume = null;
      },
    },
    {
      name: "a partially null unresolved-gap bar",
      change(session: SessionArtifact): void {
        session.bars[0]!.close = null;
        session.bars[0]!.quality_flags = ["UNRESOLVED_GAP"];
      },
    },
    {
      name: "inconsistent OHLC values",
      change(session: SessionArtifact): void {
        session.bars[0]!.high = session.bars[0]!.open! - 1;
      },
    },
    {
      name: "bar availability at bar start",
      change(session: SessionArtifact): void {
        session.bars[0]!.available_at = session.bars[0]!.timestamp;
      },
    },
  ])("rejects $name", ({ change }) => {
    const invalid = sessionClone();
    change(invalid);

    expect(() => validateSession(invalid)).toThrowError(ArtifactError);
  });

  it.each([
    {
      name: "rows ordered by timestamp",
      change(session: SessionArtifact): void {
        session.rows = [...session.rows].reverse() as SessionArtifact["rows"];
      },
    },
    {
      name: "a row aligned to its indexed chart bar",
      change(session: SessionArtifact): void {
        session.rows[0]!.close += 1;
      },
    },
    {
      name: "the explicit five-minute outcome index",
      change(session: SessionArtifact): void {
        session.rows[0]!.outcome.bar_index -= 1;
      },
    },
    {
      name: "outcome availability aligned to its future bar",
      change(session: SessionArtifact): void {
        session.rows[0]!.outcome.available_at = session.rows[0]!.outcome.timestamp;
      },
    },
    {
      name: "outcome close aligned to its future bar",
      change(session: SessionArtifact): void {
        session.rows[0]!.outcome.close += 1;
      },
    },
  ])("rejects a session without $name", ({ change }) => {
    const invalid = sessionClone();
    change(invalid);

    expect(() => validateSession(invalid)).toThrowError(ArtifactError);
  });

  it("rejects a session-index path whose embedded date differs from its date", () => {
    const invalid = indexClone();
    invalid.sessions[0]!.path = "sessions/2026-07-23.json";

    expect(() => validateSessionIndex(invalid)).toThrowError(ArtifactError);
  });
});
