import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import fixtureManifestJson from "../../public/fixtures/spy-demo/manifest.json";
import fixtureIndexJson from "../../public/fixtures/spy-demo/sessions/index.json";
import fixtureSessionJson from "../../public/fixtures/spy-demo/sessions/2026-07-24.json";
import type {
  Manifest,
  SessionArtifact,
  SessionIndexArtifact,
} from "../features/replay/artifact/generated/contracts";
import type { ReplayLoaders } from "../features/replay/artifact/loadArtifact";
import { App } from "./App";

const chartSpies = vi.hoisted(() => ({
  dispose: vi.fn(),
  resize: vi.fn(),
  setOption: vi.fn(),
}));

vi.mock("echarts", () => ({
  init: () => chartSpies,
}));

const fixtureLoaders: ReplayLoaders = {
  loadManifest: async () => fixtureManifestJson as Manifest,
  loadSessionIndex: async () => fixtureIndexJson as SessionIndexArtifact,
  loadSession: async () => fixtureSessionJson as SessionArtifact,
};

describe("App", () => {
  it("composes the replay page as its named main surface", async () => {
    render(<App loaders={fixtureLoaders} />);

    expect(screen.getByRole("main", { name: "SPY five-minute replay" })).toBeInTheDocument();
    expect(await screen.findByRole("heading", { name: "SPY" })).toBeInTheDocument();
  });
});
