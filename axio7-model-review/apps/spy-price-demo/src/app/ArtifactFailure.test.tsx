import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { ArtifactError } from "../features/replay/artifact/ArtifactError";
import { ArtifactFailure, artifactRemediationCommand } from "./ArtifactFailure";

describe("ArtifactFailure", () => {
  it.each([
    ["MISSING_MANIFEST", "manifest.json"],
    ["MISSING_SESSION_INDEX", "sessions/index.json"],
    ["MISSING_SESSION", "sessions/2026-07-24.json"],
  ] as const)("shows the sanitized path for %s", (code, path) => {
    render(
      <ArtifactFailure
        error={new ArtifactError(code, "A required artifact is unavailable.", { path })}
      />,
    );

    expect(screen.getByText(code)).toBeInTheDocument();
    expect(screen.getByText(path)).toBeInTheDocument();
    expect(screen.getByText(artifactRemediationCommand)).toBeInTheDocument();
  });

  it("does not render an arbitrary URL carried by an error", () => {
    const unsafePath = "https://example.invalid/private?token=do-not-render";

    render(
      <ArtifactFailure
        error={
          new ArtifactError(
            "MISSING_SESSION",
            "A requested session artifact is unavailable.",
            { path: unsafePath },
          )
        }
      />,
    );

    expect(screen.queryByText(unsafePath)).not.toBeInTheDocument();
    expect(document.body).not.toHaveTextContent("do-not-render");
    expect(screen.getByText(artifactRemediationCommand)).toBeInTheDocument();
  });
});
