import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import type { JSX } from "react";
import { afterEach, describe, expect, it } from "vitest";
import type { SessionIndexArtifact } from "../artifact/generated/contracts";
import { useReplayUrl } from "./useReplayUrl";

const sessionIndex: SessionIndexArtifact = {
  artifact_sha256: "test-artifact",
  contract_version: "1.0.0",
  sessions: [
    {
      date: "2026-07-23",
      path: "sessions/2026-07-23.json",
      rows: 2,
      sha256: "first-session",
    },
    {
      date: "2026-07-24",
      path: "sessions/2026-07-24.json",
      rows: 21,
      sha256: "second-session",
    },
  ],
};

function ReplayUrlHarness(): JSX.Element {
  const { state, setCutoff } = useReplayUrl(sessionIndex);

  return (
    <>
      <output>{`${state.sessionDate}:${state.cutoffIndex}`}</output>
      <button type="button" onClick={() => setCutoff(19)}>
        Set cutoff
      </button>
    </>
  );
}

function setLocation(search: string): void {
  window.history.replaceState(null, "", `/${search}`);
}

afterEach(() => {
  setLocation("");
});

describe("useReplayUrl", () => {
  it("initializes from a valid session and cutoff query", () => {
    setLocation("?session=2026-07-24&cutoff=20");

    render(<ReplayUrlHarness />);

    expect(screen.getByRole("status")).toHaveTextContent("2026-07-24:20");
  });

  it("falls back to the first validated session and cutoff zero for invalid query values", () => {
    setLocation("?session=not-a-session&cutoff=99");

    render(<ReplayUrlHarness />);

    expect(screen.getByRole("status")).toHaveTextContent("2026-07-23:0");
  });

  it("writes a validated cutoff with replaceState", async () => {
    const user = userEvent.setup();
    setLocation("?session=2026-07-24&cutoff=20");
    render(<ReplayUrlHarness />);

    await user.click(screen.getByRole("button", { name: "Set cutoff" }));

    expect(window.location.search).toBe("?session=2026-07-24&cutoff=19");
  });
});
