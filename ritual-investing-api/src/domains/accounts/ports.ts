import type { JsonObject } from "../../db/repository-support.ts";

export interface AccountRepository {
  get(): Promise<JsonObject>;
  updatePreferences(
    patch: Readonly<{
      themeMode?: "system" | "light" | "dark";
      ritualMode?: "tarot" | "astrology";
      timezone?: string;
      locale?: string;
    }>,
    expectedVersion: number,
  ): Promise<JsonObject>;
  recordConsent(
    input: Readonly<{
      policyCode: string;
      policyVersion: string;
      decision: "accepted" | "declined" | "withdrawn";
    }>,
  ): Promise<JsonObject>;
  updateInvestor(
    input: Readonly<{
      goalType: "calm_fund" | "long_term_growth" | "income" | "exploration";
      timeHorizon: "short" | "medium" | "long";
      riskComfort: "low" | "moderate" | "high";
    }>,
    expectedVersion?: number,
  ): Promise<JsonObject>;
  updateAstrology(
    birthDate: string,
    expectedVersion?: number,
  ): Promise<JsonObject>;
  deleteAstrology(expectedVersion: number): Promise<{ removed: boolean }>;
}
