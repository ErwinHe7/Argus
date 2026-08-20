import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { StrictMode } from "react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import fixtureManifestJson from "../../../../public/fixtures/spy-demo/manifest.json";
import fixtureIndexJson from "../../../../public/fixtures/spy-demo/sessions/index.json";
import fixtureSessionJson from "../../../../public/fixtures/spy-demo/sessions/2026-07-24.json";
import { ArtifactError } from "../artifact/ArtifactError";
import type {
  Manifest,
  SessionArtifact,
  SessionIndexArtifact,
  SessionIndexEntry,
} from "../artifact/generated/contracts";
import type { ReplayLoaders } from "../artifact/loadArtifact";
import { ReplayPage } from "./ReplayPage";

const fixtureManifest = fixtureManifestJson as Manifest;
const fixtureIndex = fixtureIndexJson as SessionIndexArtifact;
const fixtureSession = fixtureSessionJson as SessionArtifact;
const remediationCommand =
  "python -m intraday_quant.demo.cli build --input source/intraday_quant/data/normalized/databento_SPY_ohlcv-1m_2024-07-18_2026-07-25_rth.parquet --output apps/spy-price-demo/public/generated";

const chartSpies = vi.hoisted(() => ({
  dispose: vi.fn(),
  resize: vi.fn(),
  setOption: vi.fn(),
}));

vi.mock("echarts", () => ({
  init: () => chartSpies,
}));

function makeLoaders(overrides: Partial<ReplayLoaders> = {}): ReplayLoaders {
  return {
    loadManifest: async () => fixtureManifest,
    loadSessionIndex: async () => fixtureIndex,
    loadSession: async () => fixtureSession,
    ...overrides,
  };
}

function setLocation(search = ""): void {
  window.history.replaceState(null, "", `/${search}`);
}

function selectSession(date: string, cutoff = 0): void {
  act(() => {
    setLocation(`?session=${date}&cutoff=${cutoff}`);
    window.dispatchEvent(new PopStateEvent("popstate"));
  });
}

beforeEach(() => {
  chartSpies.dispose.mockReset();
  chartSpies.resize.mockReset();
  chartSpies.setOption.mockReset();
  setLocation();
});

afterEach(() => {
  setLocation();
});

describe("ReplayPage", () => {
  it("renders only graph-first chrome after artifacts load", async () => {
    render(<ReplayPage loaders={makeLoaders()} />);

    expect(await screen.findByRole("heading", { name: "SPY" })).toBeInTheDocument();
    expect(
      screen.getByRole("img", { name: /SPY candlestick and volume graph/i }),
    ).toHaveAttribute("data-chart-animation", "false");
    expect(
      screen.getByRole("slider", { name: "Replay cutoff minute" }),
    ).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Reveal +5m" })).toBeInTheDocument();
    expect(screen.getByText("UI_FIXTURE")).toBeInTheDocument();
    expect(screen.queryByText(/performance|evidence|calibration/i)).not.toBeInTheDocument();
  });

  it("hides outcome until reveal and resets it on cutoff change", async () => {
    const user = userEvent.setup();
    render(<ReplayPage loaders={makeLoaders()} />);
    const slider = await screen.findByRole("slider", {
      name: "Replay cutoff minute",
    });

    expect(screen.getByRole("status")).not.toHaveTextContent(/realized/i);
    await user.click(screen.getByRole("button", { name: "Reveal +5m" }));
    expect(screen.getByRole("status")).toHaveTextContent(/realized/i);

    fireEvent.input(slider, { target: { value: "1" } });

    expect(screen.getByRole("status")).not.toHaveTextContent(/realized/i);
    expect(screen.getByRole("button", { name: "Reveal +5m" })).toBeEnabled();
  });

  it("fails closed with the artifact name, safe code, and remediation command", async () => {
    render(
      <ReplayPage
        loaders={makeLoaders({
          loadManifest: async () => {
            throw ArtifactError.invalidSchema("manifest");
          },
        })}
      />,
    );

    expect(await screen.findByText(/manifest artifact is invalid/i)).toBeInTheDocument();
    expect(screen.getByText("INVALID_SCHEMA")).toBeInTheDocument();
    expect(screen.getByText(remediationCommand)).toBeInTheDocument();
    expect(screen.queryByRole("img")).not.toBeInTheDocument();
  });

  it("fails closed when the validated index has no usable sessions", async () => {
    render(
      <ReplayPage
        loaders={makeLoaders({
          loadSessionIndex: async () => ({ ...fixtureIndex, sessions: [] }),
        })}
      />,
    );

    expect(await screen.findByText(/session index artifact is invalid/i)).toBeInTheDocument();
    expect(screen.getByText("INVALID_SCHEMA")).toBeInTheDocument();
    expect(screen.queryByRole("img")).not.toBeInTheDocument();
  });

  it("passes the exact provenance-scoped index entry into the session loader", async () => {
    const exactEntry = fixtureIndex.sessions[0];
    if (exactEntry === undefined) throw new Error("Fixture session entry is required");
    let receivedEntry: SessionIndexEntry | undefined;

    render(
      <ReplayPage
        loaders={makeLoaders({
          loadSession: async (entry) => {
            receivedEntry = entry;
            return fixtureSession;
          },
        })}
      />,
    );

    await screen.findByRole("img");
    expect(receivedEntry).toBe(exactEntry);
  });

  it("aborts the prior session request and never shows its stale graph", async () => {
    const firstEntry: SessionIndexEntry = {
      date: "2026-07-23",
      path: "sessions/2026-07-23.json",
      rows: fixtureSession.rows.length,
      sha256: "first-session",
    };
    const secondEntry = fixtureIndex.sessions[0];
    if (secondEntry === undefined) throw new Error("Fixture session entry is required");
    const index = { ...fixtureIndex, sessions: [firstEntry, secondEntry] };
    let firstSignal: AbortSignal | undefined;
    let resolveFirst: ((value: SessionArtifact) => void) | undefined;
    const firstSession = { ...fixtureSession, session_date: firstEntry.date };

    const loaders = makeLoaders({
      loadSessionIndex: async () => index,
      loadSession: async (entry, signal) => {
        if (entry === firstEntry) {
          firstSignal = signal;
          return new Promise<SessionArtifact>((resolve) => {
            resolveFirst = resolve;
          });
        }
        return fixtureSession;
      },
    });

    setLocation(`?session=${firstEntry.date}&cutoff=0`);
    render(<ReplayPage loaders={loaders} />);
    await waitFor(() => expect(firstSignal).toBeDefined());

    selectSession(secondEntry.date);

    expect(firstSignal?.aborted).toBe(true);
    expect(await screen.findByRole("img")).toHaveAccessibleName(/24 JUL 2026/i);
    resolveFirst?.(firstSession);
    await Promise.resolve();
    expect(screen.getByRole("img")).toHaveAccessibleName(/24 JUL 2026/i);
  });

  it("reuses only a validated cached session when navigating back", async () => {
    const firstEntry: SessionIndexEntry = {
      date: "2026-07-23",
      path: "sessions/2026-07-23.json",
      rows: fixtureSession.rows.length,
      sha256: "first-session",
    };
    const secondEntry = fixtureIndex.sessions[0];
    if (secondEntry === undefined) throw new Error("Fixture session entry is required");
    const index = { ...fixtureIndex, sessions: [firstEntry, secondEntry] };
    const firstSession = { ...fixtureSession, session_date: firstEntry.date };
    const calls = new Map<string, number>();

    setLocation(`?session=${firstEntry.date}&cutoff=0`);
    render(
      <ReplayPage
        loaders={makeLoaders({
          loadSessionIndex: async () => index,
          loadSession: async (entry) => {
            calls.set(entry.date, (calls.get(entry.date) ?? 0) + 1);
            return entry === firstEntry ? firstSession : fixtureSession;
          },
        })}
      />,
    );

    expect(await screen.findByRole("img")).toHaveAccessibleName(/23 JUL 2026/i);
    selectSession(secondEntry.date);
    expect(await screen.findByRole("img")).toHaveAccessibleName(/24 JUL 2026/i);
    selectSession(firstEntry.date);
    expect(await screen.findByRole("img")).toHaveAccessibleName(/23 JUL 2026/i);
    expect(calls.get(firstEntry.date)).toBe(1);
  });

  it("removes the last valid graph immediately when a selected session fails", async () => {
    const firstEntry = fixtureIndex.sessions[0];
    if (firstEntry === undefined) throw new Error("Fixture session entry is required");
    const missingEntry: SessionIndexEntry = {
      date: "2026-07-25",
      path: "sessions/2026-07-25.json",
      rows: 1,
      sha256: "missing-session",
    };
    const index = { ...fixtureIndex, sessions: [firstEntry, missingEntry] };
    let rejectMissing: ((reason: ArtifactError) => void) | undefined;

    render(
      <ReplayPage
        loaders={makeLoaders({
          loadSessionIndex: async () => index,
          loadSession: async (entry) => {
            if (entry === missingEntry) {
              return new Promise<SessionArtifact>((_resolve, reject) => {
                rejectMissing = reject;
              });
            }
            return fixtureSession;
          },
        })}
      />,
    );
    await screen.findByRole("img");

    selectSession(missingEntry.date);
    expect(screen.queryByRole("img")).not.toBeInTheDocument();
    rejectMissing?.(ArtifactError.fromResponse(missingEntry.path, 404));

    expect(await screen.findByText("MISSING_SESSION")).toBeInTheDocument();
    expect(screen.queryByRole("img")).not.toBeInTheDocument();
  });

  it("clamps a URL cutoff to the loaded session row range", async () => {
    const shortSession = { ...fixtureSession, rows: fixtureSession.rows.slice(0, 4) };
    setLocation("?session=2026-07-24&cutoff=10");

    render(
      <ReplayPage loaders={makeLoaders({ loadSession: async () => shortSession })} />,
    );

    expect(await screen.findByRole("slider")).toHaveValue("3");
    await waitFor(() => {
      expect(window.location.search).toBe("?session=2026-07-24&cutoff=3");
    });
  });

  it("retains the newest same-session cutoff when a deferred session resolves", async () => {
    const shortSession = { ...fixtureSession, rows: fixtureSession.rows.slice(0, 4) };
    let loadCount = 0;
    let resolveSession: ((session: SessionArtifact) => void) | undefined;
    setLocation("?session=2026-07-24&cutoff=10");

    render(
      <ReplayPage
        loaders={makeLoaders({
          loadSession: async () => {
            loadCount += 1;
            return new Promise<SessionArtifact>((resolve) => {
              resolveSession = resolve;
            });
          },
        })}
      />,
    );
    await waitFor(() => expect(resolveSession).toBeDefined());

    selectSession("2026-07-24", 2);
    await act(async () => {
      resolveSession?.(shortSession);
      await Promise.resolve();
    });

    expect(await screen.findByRole("slider")).toHaveValue("2");
    expect(loadCount).toBe(1);
    await waitFor(() => {
      expect(window.location.search).toBe("?session=2026-07-24&cutoff=2");
    });
  });

  it("survives StrictMode request cleanup without accepting stale state", async () => {
    render(
      <StrictMode>
        <ReplayPage loaders={makeLoaders()} />
      </StrictMode>,
    );

    expect(await screen.findByRole("img")).toBeInTheDocument();
  });
});
