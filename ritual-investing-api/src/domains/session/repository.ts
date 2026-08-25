import { Pool } from "@neondatabase/serverless";

import type { DatabasePoolFactory } from "../../db/client.ts";
import type { OnboardingFinalizeRequest } from "../accounts/schemas.ts";
import { sha256TextHex } from "../../security/sha256.ts";
import { sessionBootstrapDataSchema, type SessionBootstrapData } from "./schemas.ts";

export interface SessionRepository {
  bootstrap(verifiedSubject: string): Promise<SessionBootstrapData>;
  finalizeOnboarding?(
    verifiedSubject: string,
    input: OnboardingFinalizeRequest,
    idempotencyKey: string,
  ): Promise<SessionBootstrapData>;
}

export class InactiveBootstrapPrincipalError extends Error {
  constructor() {
    super("inactive_bootstrap_principal");
    this.name = "InactiveBootstrapPrincipalError";
  }
}

export class OnboardingCompletedError extends Error {
  constructor() {
    super("onboarding_completed");
    this.name = "OnboardingCompletedError";
  }
}

export class OnboardingVersionConflictError extends Error {
  constructor() {
    super("onboarding_version_conflict");
    this.name = "OnboardingVersionConflictError";
  }
}

export class OnboardingIdempotencyConflictError extends Error {
  constructor() {
    super("onboarding_idempotency_conflict");
    this.name = "OnboardingIdempotencyConflictError";
  }
}

type BootstrapRow = {
  account_id: string;
  account_status: "active";
  display_name: string;
  locale: string;
  theme_mode: "system" | "light" | "dark";
  ritual_mode: "tarot" | "astrology";
  ritual_familiarity:
    | "new"
    | "curious"
    | "familiar"
    | "practiced"
    | "prefer_not_to_say"
    | null;
  ritual_language:
    | "practical"
    | "balanced"
    | "mystical"
    | "prefer_not_to_say"
    | null;
  ritual_interests: string[] | null;
  timezone: string;
  preferences_version: number;
  current_step: string;
  completed_steps: string[];
  completed_at: Date | string | null;
  onboarding_schema_version: number;
  onboarding_cohort:
    | "legacy_complete_v1"
    | "legacy_incomplete_v1"
    | "member_v2";
  onboarding_version: number;
  plan_code: string;
  entitlement_status: "active";
  portfolio_id: string;
  portfolio_name: string;
  portfolio_currency: "USD";
  portfolio_status: "active";
  portfolio_version: number;
  reset_generation: number;
  investor_goal_type: "calm_fund" | "long_term_growth" | "income" | "exploration" | null;
  investor_time_horizon: "short" | "medium" | "long" | null;
  investor_risk_comfort: "low" | "moderate" | "high" | null;
  investing_experience: "new" | "some_experience" | "experienced" | null;
  contribution_rhythm: "weekly" | "biweekly" | "monthly" | "irregular" | "not_sure" | null;
  investor_version: number | null;
  astrology_birth_date: Date | string | null;
  derived_profile_code: "lunar_patient" | "solar_builder" | "rising_explorer" | null;
  astrology_algorithm_version: "v1" | null;
  astrology_enabled_at: Date | string | null;
  astrology_version: number | null;
  server_time: Date | string;
};

function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value !== null && typeof value === "object") {
    const entries = Object.entries(value as Record<string, unknown>)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, nested]) => `${JSON.stringify(key)}:${canonical(nested)}`);
    return `{${entries.join(",")}}`;
  }
  return JSON.stringify(value);
}

export function onboardingPayloadHash(
  input: OnboardingFinalizeRequest,
): Promise<string> {
  return sha256TextHex(canonical(input));
}

function snapshotFromRow(row: BootstrapRow): SessionBootstrapData {
  return sessionBootstrapDataSchema.parse({
    account: { id: row.account_id, status: row.account_status },
    profile: { display_name: row.display_name, locale: row.locale },
    preferences: {
      theme_mode: row.theme_mode,
      ritual_mode: row.ritual_mode,
      ritual_familiarity: row.ritual_familiarity,
      ritual_language: row.ritual_language,
      ritual_interests: row.ritual_interests,
      timezone: row.timezone,
      locale: row.locale,
      version: Number(row.preferences_version),
    },
    investor_profile:
      row.investor_goal_type === null ||
      row.investor_time_horizon === null ||
      row.investor_risk_comfort === null ||
      row.investing_experience === null ||
      row.contribution_rhythm === null ||
      row.investor_version === null
        ? null
        : {
            experience: row.investing_experience,
            goal_type: row.investor_goal_type,
            time_horizon: row.investor_time_horizon,
            risk_comfort: row.investor_risk_comfort,
            contribution_rhythm: row.contribution_rhythm,
            version: Number(row.investor_version),
            is_demo: true,
          },
    astrology_profile:
      row.astrology_birth_date === null ||
      row.derived_profile_code === null ||
      row.astrology_algorithm_version === null ||
      row.astrology_enabled_at === null ||
      row.astrology_version === null
        ? null
        : {
            birth_date: String(row.astrology_birth_date),
            derived_profile_code: row.derived_profile_code,
            algorithm_version: row.astrology_algorithm_version,
            enabled_at: new Date(row.astrology_enabled_at).toISOString(),
            version: Number(row.astrology_version),
          },
    onboarding: {
      current_step: row.current_step,
      completed_steps: row.completed_steps,
      completed_at:
        row.completed_at === null
          ? null
          : new Date(row.completed_at).toISOString(),
      schema_version: Number(row.onboarding_schema_version),
      cohort: row.onboarding_cohort,
      version: Number(row.onboarding_version),
    },
    entitlement: { plan_code: row.plan_code, status: row.entitlement_status },
    default_portfolio: {
      id: row.portfolio_id,
      name: row.portfolio_name,
      currency: row.portfolio_currency,
      status: row.portfolio_status,
      version: Number(row.portfolio_version),
    },
    reset_generation: Number(row.reset_generation),
    server_time: new Date(row.server_time).toISOString(),
    contract_version: "1.0.0",
  });
}

function translateRepositoryError(error: unknown): never {
  const message = error instanceof Error ? error.message : "";
  if (
    ["subject_not_eligible", "subject_previously_deleted"].some((code) =>
      message.includes(code),
    )
  ) {
    throw new InactiveBootstrapPrincipalError();
  }
  if (message.includes("onboarding_completed")) {
    throw new OnboardingCompletedError();
  }
  if (message.includes("onboarding_version_conflict")) {
    throw new OnboardingVersionConflictError();
  }
  if (message.includes("onboarding_idempotency_conflict")) {
    throw new OnboardingIdempotencyConflictError();
  }
  throw error;
}

const neonSessionPoolFactory: DatabasePoolFactory = (databaseUrl) =>
  new Pool({ connectionString: databaseUrl, max: 1 });

export function createPostgresSessionRepository(
  databaseUrl: string,
  poolFactory: DatabasePoolFactory = neonSessionPoolFactory,
): SessionRepository {
  return {
    async bootstrap(verifiedSubject) {
      const pool = poolFactory(databaseUrl);
      let client;
      try {
        client = await pool.connect();
        await client.query("begin");
        await client.query("set local role ritual_bootstrap");
        const result = await client.query<BootstrapRow>(
          "select * from ritual_private.bootstrap_member_account_v2($1)",
          [verifiedSubject],
        );
        const row = result.rows[0];
        if (result.rows.length !== 1 || row === undefined) {
          throw new Error("invalid_bootstrap_result");
        }
        const snapshot = snapshotFromRow(row);
        await client.query("commit");
        return snapshot;
      } catch (error) {
        await client?.query("rollback").catch(() => undefined);
        translateRepositoryError(error);
      } finally {
        client?.release();
        await pool.end();
      }
    },
    async finalizeOnboarding(verifiedSubject, input, idempotencyKey) {
      const pool = poolFactory(databaseUrl);
      let client;
      try {
        client = await pool.connect();
        await client.query("begin");
        await client.query("set local role ritual_bootstrap");
        const requestHash = await onboardingPayloadHash(input);
        const result = await client.query<{ snapshot: unknown }>(
          "select ritual_private.finalize_member_onboarding($1,$2,$3,$4::jsonb) as snapshot",
          [verifiedSubject, idempotencyKey, requestHash, JSON.stringify(input)],
        );
        if (result.rows.length !== 1 || result.rows[0] === undefined) {
          throw new Error("invalid_onboarding_result");
        }
        const snapshot = sessionBootstrapDataSchema.parse(
          result.rows[0].snapshot,
        );
        await client.query("commit");
        return snapshot;
      } catch (error) {
        await client?.query("rollback").catch(() => undefined);
        translateRepositoryError(error);
      } finally {
        client?.release();
        await pool.end();
      }
    },
  };
}
