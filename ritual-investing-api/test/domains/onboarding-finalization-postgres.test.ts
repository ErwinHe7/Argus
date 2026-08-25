import { randomUUID } from "node:crypto";

import pg from "pg";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

import type { OnboardingFinalizeRequest } from "../../src/domains/accounts/schemas.ts";
import { deterministicAstrologyProfileCode } from "../../src/domains/accounts/repository.ts";
import {
  createPostgresSessionRepository,
  OnboardingCompletedError,
  OnboardingIdempotencyConflictError,
  OnboardingVersionConflictError,
} from "../../src/domains/session/repository.ts";
import { applyReviewedMigrations } from "../../scripts/migrate.ts";
import { pgPoolFactory } from "../helpers/simulation-postgres.ts";

const databaseUrl = process.env.TEST_DATABASE_URL;

function questionnaire(
  expectedOnboardingVersion: number,
): OnboardingFinalizeRequest {
  return {
    schema_version: 2,
    expected_onboarding_version: expectedOnboardingVersion,
    investing: {
      experience: "new",
      goal_type: "long_term_growth",
      time_horizon: "long",
      risk_comfort: "moderate",
      contribution_rhythm: "monthly",
    },
    ritual: {
      familiarity: "new",
      language_preference: "practical",
      interests: ["practical_research"],
    },
    astrology: { enabled: false },
    consents: {
      terms: { policy_version: "2026-08", decision: "accepted" },
      privacy: { policy_version: "2026-08", decision: "accepted" },
      demo_disclosure: {
        policy_version: "2026-08",
        decision: "accepted",
      },
      astrology: { policy_version: "2026-08", decision: "declined" },
    },
  };
}

describe.skipIf(databaseUrl === undefined)(
  "onboarding finalization PostgreSQL transaction",
  () => {
    let owner: pg.Client;

    beforeAll(async () => {
      await applyReviewedMigrations(databaseUrl!);
      owner = new pg.Client({ connectionString: databaseUrl });
      await owner.connect();
    });

    afterAll(async () => {
      await owner?.end();
    });

    it("replays one atomic result and rejects command or completion conflicts", async () => {
      const repository = createPostgresSessionRepository(
        databaseUrl!,
        pgPoolFactory,
      );
      const subject = `auth0|onboarding-${randomUUID()}`;
      const initial = await repository.bootstrap(subject);
      const commandKey = `onboarding-${randomUUID()}`;
      const input = questionnaire(initial.onboarding.version);

      const first = await repository.finalizeOnboarding!(
        subject,
        input,
        commandKey,
      );
      const replay = await repository.finalizeOnboarding!(
        subject,
        input,
        commandKey,
      );

      expect(replay).toEqual(first);
      expect(first).toMatchObject({
        investor_profile: {
          experience: "new",
          risk_comfort: "moderate",
          contribution_rhythm: "monthly",
        },
        astrology_profile: null,
        onboarding: {
          current_step: "complete",
          schema_version: 2,
          cohort: "member_v2",
        },
      });

      await expect(
        repository.finalizeOnboarding!(
          subject,
          {
            ...input,
            investing: { ...input.investing, risk_comfort: "high" },
          },
          commandKey,
        ),
      ).rejects.toBeInstanceOf(OnboardingIdempotencyConflictError);
      await expect(
        repository.finalizeOnboarding!(
          subject,
          input,
          `onboarding-${randomUUID()}`,
        ),
      ).rejects.toBeInstanceOf(OnboardingCompletedError);

      const effects = await owner.query<{
        astrology_profiles: string;
        commands: string;
        consents: string;
        investor_profiles: string;
      }>(
        `select
           (select count(*) from investor_profiles investor
             where investor.tenant_id=account.tenant_id)::text investor_profiles,
           (select count(*) from astrology_profiles astrology
             where astrology.tenant_id=account.tenant_id)::text astrology_profiles,
           (select count(*) from consent_records consent
             where consent.tenant_id=account.tenant_id)::text consents,
           (select count(*) from onboarding_finalization_commands command
             where command.tenant_id=account.tenant_id)::text commands
         from accounts account where account.auth0_subject=$1`,
        [subject],
      );
      expect(effects.rows[0]).toEqual({
        investor_profiles: "1",
        astrology_profiles: "0",
        consents: "4",
        commands: "1",
      });
    });

    it("rolls back every personalization write for a stale version", async () => {
      const repository = createPostgresSessionRepository(
        databaseUrl!,
        pgPoolFactory,
      );
      const subject = `auth0|onboarding-stale-${randomUUID()}`;
      const initial = await repository.bootstrap(subject);

      await expect(
        repository.finalizeOnboarding!(
          subject,
          questionnaire(initial.onboarding.version + 1),
          `onboarding-${randomUUID()}`,
        ),
      ).rejects.toBeInstanceOf(OnboardingVersionConflictError);

      const effects = await owner.query<{
        commands: string;
        consents: string;
        current_step: string;
        investor_profiles: string;
        ritual_familiarity: string | null;
      }>(
        `select onboarding.current_step,preference.ritual_familiarity,
           (select count(*) from investor_profiles investor
             where investor.tenant_id=account.tenant_id)::text investor_profiles,
           (select count(*) from consent_records consent
             where consent.tenant_id=account.tenant_id)::text consents,
           (select count(*) from onboarding_finalization_commands command
             where command.tenant_id=account.tenant_id)::text commands
         from accounts account
         join onboarding_states onboarding on onboarding.tenant_id=account.tenant_id
         join preferences preference on preference.tenant_id=account.tenant_id
         where account.auth0_subject=$1`,
        [subject],
      );
      expect(effects.rows[0]).toEqual({
        current_step: "welcome",
        ritual_familiarity: null,
        investor_profiles: "0",
        consents: "0",
        commands: "0",
      });
    });

    it("derives opted-in astrology on the server from birth date only", async () => {
      const repository = createPostgresSessionRepository(
        databaseUrl!,
        pgPoolFactory,
      );
      const subject = `auth0|onboarding-astrology-${randomUUID()}`;
      const initial = await repository.bootstrap(subject);
      const birthDate = "1990-02-03";
      const base = questionnaire(initial.onboarding.version);
      const result = await repository.finalizeOnboarding!(
        subject,
        {
          ...base,
          astrology: { enabled: true, birth_date: birthDate },
          consents: {
            ...base.consents,
            astrology: {
              policy_version: "2026-08",
              decision: "accepted",
            },
          },
        },
        `onboarding-${randomUUID()}`,
      );

      expect(result.astrology_profile).toMatchObject({
        birth_date: birthDate,
        derived_profile_code: deterministicAstrologyProfileCode(birthDate),
        algorithm_version: "v1",
      });
    });
  },
);
