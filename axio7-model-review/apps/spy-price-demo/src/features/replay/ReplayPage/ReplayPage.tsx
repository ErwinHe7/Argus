import { useEffect, useMemo, useRef, useState, type JSX } from "react";
import { ArtifactFailure } from "../../../app/ArtifactFailure";
import { ThemeToggle } from "../../theme/ThemeToggle/ThemeToggle";
import { useTheme } from "../../theme/ThemeToggle/useTheme";
import { OutcomeReveal } from "../OutcomeReveal/OutcomeReveal";
import { ReplayControls } from "../ReplayControls/ReplayControls";
import { ReplayGraph } from "../ReplayGraph/ReplayGraph";
import type { ChartTheme } from "../ReplayGraph/types";
import { ArtifactError } from "../artifact/ArtifactError";
import type {
  Manifest,
  ReplayRow,
  SessionArtifact,
  SessionIndexArtifact,
  SessionIndexEntry,
} from "../artifact/generated/contracts";
import {
  defaultReplayLoaders,
  type ReplayLoaders,
} from "../artifact/loadArtifact";
import { validateSession } from "../artifact/validateArtifact";
import { useReplayUrl } from "./useReplayUrl";
import styles from "./ReplayPage.module.css";

interface ReplayPageProps {
  loaders?: ReplayLoaders;
}

type BootstrapState =
  | { status: "loading" }
  | { status: "failed"; error: ArtifactError }
  | {
      status: "ready";
      manifest: Manifest;
      sessionIndex: SessionIndexArtifact;
    };

type SessionState =
  | { status: "loading" }
  | { status: "failed"; error: ArtifactError }
  | { status: "ready"; date: string; session: SessionArtifact };

function isAbortError(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "name" in error &&
    error.name === "AbortError"
  );
}

function safeArtifactError(error: unknown): ArtifactError {
  return error instanceof ArtifactError
    ? error
    : ArtifactError.network("artifact", error);
}

function usableEntry(
  index: SessionIndexArtifact,
  date: string,
): SessionIndexEntry | undefined {
  return index.sessions.find(
    (entry) => entry.date === date && Number.isInteger(entry.rows) && entry.rows > 0,
  );
}

function hasUsableSession(index: SessionIndexArtifact): boolean {
  return index.sessions.some(
    (entry) => Number.isInteger(entry.rows) && entry.rows > 0,
  );
}

function formatDate(date: string): string {
  const [year, month, day] = date.split("-");
  const monthNames = [
    "JAN",
    "FEB",
    "MAR",
    "APR",
    "MAY",
    "JUN",
    "JUL",
    "AUG",
    "SEP",
    "OCT",
    "NOV",
    "DEC",
  ];
  const monthName = month === undefined ? undefined : monthNames[Number(month) - 1];
  return day !== undefined && monthName !== undefined && year !== undefined
    ? `${day} ${monthName} ${year}`
    : date;
}

function formatTime(timestamp: string): string {
  return new Intl.DateTimeFormat("en-US", {
    hour: "numeric",
    minute: "2-digit",
    timeZone: "America/New_York",
  }).format(new Date(timestamp));
}

function qualitySummary(row: ReplayRow): string {
  return row.quality_flags.length === 0
    ? "complete"
    : `flagged ${row.quality_flags.join(", ")}`;
}

function accessibleSummary(session: SessionArtifact, row: ReplayRow): string {
  return `SPY candlestick and volume graph for ${formatDate(session.session_date)} at ${formatTime(row.timestamp)} ET. Forecast ${row.forecast.direction}; quality ${qualitySummary(row)}.`;
}

function liveSummary(row: ReplayRow, revealed: boolean): string {
  const selected = `Selected cutoff ${formatTime(row.timestamp)} ET. Forecast ${row.forecast.direction}, probability up ${row.forecast.probability_up}, expected return ${row.forecast.expected_return_bps} basis points. Quality ${qualitySummary(row)}.`;
  return revealed
    ? `${selected} Realized +5 minute return ${row.outcome.return_bps} basis points.`
    : selected;
}

function chartTheme(theme: "light" | "dark"): ChartTheme {
  return theme === "dark"
    ? {
        background: "#000000",
        foreground: "#ffffff",
        up: "#00a36c",
        down: "#e2382f",
      }
    : {
        background: "#ffffff",
        foreground: "#000000",
        up: "#00a36c",
        down: "#e2382f",
      };
}

interface LoadedReplayPageProps {
  loaders: ReplayLoaders;
  manifest: Manifest;
  sessionIndex: SessionIndexArtifact;
}

function LoadedReplayPage({
  loaders,
  manifest,
  sessionIndex,
}: LoadedReplayPageProps): JSX.Element {
  const { state, setCutoff, reveal } = useReplayUrl(sessionIndex);
  const { theme, toggleTheme } = useTheme();
  const cache = useRef(new Map<string, SessionArtifact>());
  const requestSequence = useRef(0);
  const [sessionState, setSessionState] = useState<SessionState>({
    status: "loading",
  });

  useEffect(() => {
    const entry = usableEntry(sessionIndex, state.sessionDate);
    if (entry === undefined) {
      setSessionState({
        status: "failed",
        error: ArtifactError.invalidSchema("session index"),
      });
      return;
    }

    const requestId = ++requestSequence.current;
    const controller = new AbortController();
    setSessionState({ status: "loading" });

    const acceptSession = (session: SessionArtifact): void => {
      if (controller.signal.aborted || requestId !== requestSequence.current) return;
      const maximumCutoff = session.rows.length - 1;
      if (maximumCutoff < 0) {
        setSessionState({
          status: "failed",
          error: ArtifactError.invalidSchema("session"),
        });
        return;
      }
      if (state.cutoffIndex > maximumCutoff) setCutoff(maximumCutoff);
      setSessionState({ status: "ready", date: entry.date, session });
    };

    const cached = cache.current.get(entry.date);
    if (cached !== undefined) {
      acceptSession(cached);
      return () => controller.abort();
    }

    void loaders
      .loadSession(entry, controller.signal)
      .then((loadedSession) => {
        const session = validateSession(loadedSession);
        if (session.session_date !== entry.date) {
          throw ArtifactError.invalidSchema("session");
        }
        if (controller.signal.aborted || requestId !== requestSequence.current) return;
        cache.current.set(entry.date, session);
        acceptSession(session);
      })
      .catch((error: unknown) => {
        if (
          controller.signal.aborted ||
          requestId !== requestSequence.current ||
          isAbortError(error)
        ) {
          return;
        }
        setSessionState({ status: "failed", error: safeArtifactError(error) });
      });

    return () => controller.abort();
  }, [loaders, sessionIndex, state.sessionDate]);

  if (sessionState.status === "failed") {
    return <ArtifactFailure className={styles.failure} error={sessionState.error} />;
  }

  if (
    sessionState.status !== "ready" ||
    sessionState.date !== state.sessionDate
  ) {
    return <div aria-hidden="true" />;
  }

  const { session } = sessionState;
  const maximumCutoff = session.rows.length - 1;
  const cutoffIndex = Math.min(Math.max(state.cutoffIndex, 0), maximumCutoff);
  const row = session.rows[cutoffIndex];
  if (row === undefined) {
    return (
      <ArtifactFailure
        className={styles.failure}
        error={ArtifactError.invalidSchema("session")}
      />
    );
  }

  const summary = accessibleSummary(session, row);
  const statusLabel = manifest.status === "UI_FIXTURE" ? "UI_FIXTURE" : "OOS";

  return (
    <section
      className={styles.frame}
      aria-label="SPY five-minute historical forecast replay"
    >
      <header className={styles.header}>
        <h1 className={styles.symbol}>SPY</h1>
        <div className={styles.headerTools}>
          <div className={styles.metadata} aria-label="Replay metadata">
            <span>{formatDate(session.session_date)}</span>
            <span>1M → 5M</span>
            <span>{statusLabel}</span>
          </div>
          <ThemeToggle theme={theme} toggleTheme={toggleTheme} />
        </div>
      </header>
      <ReplayGraph
        session={session}
        row={row}
        revealed={state.revealed}
        theme={chartTheme(theme)}
        accessibleSummary={summary}
      />
      <div className={styles.controls}>
        <ReplayControls
          cutoffIndex={cutoffIndex}
          cutoffLabel={`Cutoff ${formatTime(row.timestamp)} ET`}
          maximumCutoff={maximumCutoff}
          setCutoff={setCutoff}
        />
        <OutcomeReveal
          className={styles.reveal}
          revealed={state.revealed}
          reveal={reveal}
        />
      </div>
      <div className={styles.srOnly} role="status" aria-live="polite">
        {liveSummary(row, state.revealed)}
      </div>
    </section>
  );
}

export function ReplayPage({
  loaders = defaultReplayLoaders,
}: ReplayPageProps): JSX.Element {
  const [bootstrap, setBootstrap] = useState<BootstrapState>({
    status: "loading",
  });

  useEffect(() => {
    const controller = new AbortController();
    let current = true;
    setBootstrap({ status: "loading" });

    void loaders
      .loadManifest(controller.signal)
      .then(async (manifest) => {
        const sessionIndex = await loaders.loadSessionIndex(
          manifest,
          controller.signal,
        );
        if (!hasUsableSession(sessionIndex)) {
          throw ArtifactError.invalidSchema("session index");
        }
        if (current && !controller.signal.aborted) {
          setBootstrap({ status: "ready", manifest, sessionIndex });
        }
      })
      .catch((error: unknown) => {
        if (!current || controller.signal.aborted || isAbortError(error)) return;
        setBootstrap({ status: "failed", error: safeArtifactError(error) });
      });

    return () => {
      current = false;
      controller.abort();
    };
  }, [loaders]);

  const content = useMemo(() => {
    if (bootstrap.status === "failed") {
      return <ArtifactFailure className={styles.failure} error={bootstrap.error} />;
    }
    if (bootstrap.status === "ready") {
      return (
        <LoadedReplayPage
          loaders={loaders}
          manifest={bootstrap.manifest}
          sessionIndex={bootstrap.sessionIndex}
        />
      );
    }
    return <div aria-hidden="true" />;
  }, [bootstrap, loaders]);

  return (
    <main
      className={styles.page}
      aria-label="SPY five-minute replay"
      aria-busy={bootstrap.status === "loading"}
    >
      {content}
    </main>
  );
}
