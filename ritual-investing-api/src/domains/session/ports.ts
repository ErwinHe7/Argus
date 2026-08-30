export type SessionRepositorySnapshot = Readonly<
  Record<string, unknown> & { server_time: string }
>;

export interface SessionRepository {
  bootstrap(): Promise<SessionRepositorySnapshot>;
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
