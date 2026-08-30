import type {
  ReplayRow,
  SessionArtifact,
} from "../artifact/generated/contracts";

export interface ChartTheme {
  background: "#ffffff" | "#000000";
  foreground: "#000000" | "#ffffff";
  up: "#00a36c";
  down: "#e2382f";
}

export interface ReplayChartInput {
  session: SessionArtifact;
  row: ReplayRow;
  revealed: boolean;
  theme: ChartTheme;
  accessibleSummary: string;
}

export interface TooltipInput {
  session: SessionArtifact;
  row: ReplayRow;
  barIndex: number;
  revealed: boolean;
  theme: ChartTheme;
}
