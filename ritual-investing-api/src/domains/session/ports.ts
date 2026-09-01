import type { MemberBranchCapabilities } from "./schemas.ts";
import type { SupabaseSessionSnapshot } from "./supabase-schemas.ts";

export type SessionRepositorySnapshot = SupabaseSessionSnapshot;

export interface MemberBranchCapabilityEvaluator {
  evaluate(serverTime: string): Promise<MemberBranchCapabilities>;
}

export interface SessionRepository {
  bootstrap(): Promise<SessionRepositorySnapshot>;
  finalizeBirthdayOnboarding(
    input: Readonly<{
      expectedOnboardingVersion: number;
      birthDate: string;
      consents: Readonly<
        Record<
          string,
          Readonly<{
            policyVersion: string;
            decision: "accepted";
          }>
        >
      >;
    }>,
    idempotencyKey: string,
  ): Promise<SessionRepositorySnapshot>;
  finalizeOnboarding(
    input: Readonly<{
      expectedOnboardingVersion: number;
      investing: Readonly<{
        goalType: "calm_fund" | "long_term_growth" | "income" | "exploration";
        timeHorizon: "short" | "medium" | "long";
        riskComfort: "low" | "moderate" | "high";
      }>;
      astrology: Readonly<{ enabled: boolean; birthDate?: string }>;
      consents: Readonly<
        Record<
          string,
          Readonly<{
            policyVersion: string;
            decision: "accepted" | "declined";
          }>
        >
      >;
    }>,
    idempotencyKey: string,
  ): Promise<SessionRepositorySnapshot>;
}
