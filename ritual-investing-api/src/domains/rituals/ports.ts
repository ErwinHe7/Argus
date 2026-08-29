import type { JsonObject } from "../../db/repository-support.ts";

export interface RitualRepository {
  getDaily(mode?: "tarot" | "astrology"): Promise<JsonObject>;
  get(assignmentId: string): Promise<JsonObject>;
  history(limit: number): Promise<JsonObject[]>;
  evidence(assignmentId: string): Promise<JsonObject[]>;
  transition(
    assignmentId: string,
    from: "assigned" | "revealed",
    to: "revealed" | "completed",
    expectedVersion: number,
  ): Promise<JsonObject>;
  getSchedule(
    localDate: string,
    mode: "tarot" | "astrology",
  ): Promise<JsonObject>;
  getScenario(revisionId: string): Promise<JsonObject>;
}
