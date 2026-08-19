import fixtureManifest from "../../../../public/fixtures/spy-demo/manifest.json";
import fixtureModelCard from "../../../../public/fixtures/spy-demo/model-card.json";
import fixtureSession from "../../../../public/fixtures/spy-demo/sessions/2026-07-24.json";
import fixtureSessionIndex from "../../../../public/fixtures/spy-demo/sessions/index.json";
import fixtureSummary from "../../../../public/fixtures/spy-demo/summary.json";
import { ArtifactError } from "./ArtifactError";
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
});
