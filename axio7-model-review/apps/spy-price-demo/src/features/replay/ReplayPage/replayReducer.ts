export interface ReplayState {
  sessionDate: string;
  cutoffIndex: number;
  revealed: boolean;
}

export type ReplayAction =
  | { type: "setSession"; sessionDate: string }
  | { type: "setCutoff"; cutoffIndex: number }
  | { type: "reveal" };

export function replayReducer(
  state: ReplayState,
  action: ReplayAction,
): ReplayState {
  if (action.type === "setSession") {
    return { sessionDate: action.sessionDate, cutoffIndex: 0, revealed: false };
  }

  if (action.type === "setCutoff") {
    return { ...state, cutoffIndex: action.cutoffIndex, revealed: false };
  }

  return { ...state, revealed: true };
}
