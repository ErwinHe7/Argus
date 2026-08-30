import { useCallback, useEffect, useMemo, useReducer } from "react";
import type {
  SessionIndexArtifact,
  SessionIndexEntry,
} from "../artifact/generated/contracts";
import {
  replayReducer,
  type ReplayAction,
  type ReplayState,
} from "./replayReducer";

export interface ReplayUrlState {
  state: ReplayState;
  setSession(sessionDate: string): void;
  setCutoff(cutoffIndex: number): void;
  reveal(): void;
}

function usableSessions(
  sessionIndex: SessionIndexArtifact,
): readonly SessionIndexEntry[] {
  return sessionIndex.sessions.filter(
    (session) => Number.isInteger(session.rows) && session.rows > 0,
  );
}

function findSession(
  sessions: readonly SessionIndexEntry[],
  sessionDate: string,
): SessionIndexEntry | undefined {
  return sessions.find((session) => session.date === sessionDate);
}

function isValidCutoff(cutoffIndex: number, session: SessionIndexEntry): boolean {
  return Number.isInteger(cutoffIndex) && cutoffIndex >= 0 && cutoffIndex < session.rows;
}

function parseCutoff(value: string | null): number | undefined {
  if (value === null || value.trim() === "") return undefined;

  const cutoffIndex = Number(value);
  return Number.isInteger(cutoffIndex) ? cutoffIndex : undefined;
}

function fallbackSession(sessions: readonly SessionIndexEntry[]): SessionIndexEntry {
  const firstSession = sessions[0];
  if (firstSession === undefined) {
    throw new Error("A replay URL requires at least one session with replay rows.");
  }
  return firstSession;
}

function stateFromSearch(
  sessions: readonly SessionIndexEntry[],
  search: string,
): ReplayState {
  const parameters = new URLSearchParams(search);
  const fallback = fallbackSession(sessions);
  const selected = findSession(sessions, parameters.get("session") ?? "") ?? fallback;
  const cutoffParameter = parameters.get("cutoff");
  const cutoffIndex = parseCutoff(cutoffParameter);

  return {
    sessionDate: selected.date,
    cutoffIndex:
      cutoffParameter === null
        ? selected.rows - 1
        : cutoffIndex !== undefined && isValidCutoff(cutoffIndex, selected)
        ? cutoffIndex
        : 0,
    revealed: false,
  };
}

function replaceReplayUrl(state: ReplayState): void {
  const url = new URL(window.location.href);
  url.searchParams.set("session", state.sessionDate);
  url.searchParams.set("cutoff", String(state.cutoffIndex));
  window.history.replaceState(window.history.state, "", `${url.pathname}${url.search}${url.hash}`);
}

export function useReplayUrl(sessionIndex: SessionIndexArtifact): ReplayUrlState {
  const sessions = useMemo(() => usableSessions(sessionIndex), [sessionIndex]);
  const sessionKey = sessions
    .map((session) => `${session.date}:${session.rows}`)
    .join("|");
  const [state, dispatch] = useReducer(
    replayReducer,
    sessions,
    (availableSessions) => stateFromSearch(availableSessions, window.location.search),
  );

  useEffect(() => {
    const nextState = stateFromSearch(sessions, window.location.search);
    if (state.sessionDate !== nextState.sessionDate) {
      dispatch({ type: "setSession", sessionDate: nextState.sessionDate });
      if (nextState.cutoffIndex !== 0) {
        dispatch({ type: "setCutoff", cutoffIndex: nextState.cutoffIndex });
      }
      return;
    }

    if (state.cutoffIndex !== nextState.cutoffIndex) {
      dispatch({ type: "setCutoff", cutoffIndex: nextState.cutoffIndex });
    }
  }, [sessionKey]);

  useEffect(() => {
    const handlePopState = (): void => {
      const nextState = stateFromSearch(sessions, window.location.search);
      dispatch({ type: "setSession", sessionDate: nextState.sessionDate });
      if (nextState.cutoffIndex !== 0) {
        dispatch({ type: "setCutoff", cutoffIndex: nextState.cutoffIndex });
      }
    };

    window.addEventListener("popstate", handlePopState);
    return () => window.removeEventListener("popstate", handlePopState);
  }, [sessionKey, sessions]);

  useEffect(() => {
    replaceReplayUrl(state);
  }, [state.cutoffIndex, state.sessionDate]);

  const dispatchValidated = useCallback(
    (action: ReplayAction): void => {
      if (action.type === "setSession") {
        if (findSession(sessions, action.sessionDate) !== undefined) dispatch(action);
        return;
      }

      if (action.type === "setCutoff") {
        const selectedSession = findSession(sessions, state.sessionDate);
        if (
          selectedSession !== undefined &&
          isValidCutoff(action.cutoffIndex, selectedSession)
        ) {
          dispatch(action);
        }
        return;
      }

      dispatch(action);
    },
    [sessions, state.sessionDate],
  );

  return {
    state,
    setSession: (sessionDate) => dispatchValidated({ type: "setSession", sessionDate }),
    setCutoff: (cutoffIndex) => dispatchValidated({ type: "setCutoff", cutoffIndex }),
    reveal: () => dispatchValidated({ type: "reveal" }),
  };
}
