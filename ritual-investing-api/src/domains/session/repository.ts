import type { DatabaseTransaction } from "../../db/database-port.ts";
import {
  first,
  type JsonObject,
  RepositoryRevisionConflictError,
} from "../../db/repository-support.ts";
import { sha256TextHex } from "../../security/sha256.ts";
import { supabaseSessionSnapshotSchema } from "./supabase-schemas.ts";

export function createSupabaseSessionRepository(
  database: DatabaseTransaction,
  verifiedSubject: string,
) {
  const selectSnapshot = async (
    database: DatabaseTransaction,
    access: "member" | "runtime" = "member",
  ) => {
    const profileAndPreferencesProjection = access === "member"
      ? `'profile', to_jsonb(profile),
         'preferences', to_jsonb(preferences),`
      : `'profile', null::jsonb,
         'preferences', null::jsonb,`;
    const profileAndPreferencesJoins = access === "member"
      ? `left join argus_app.profiles profile on profile.user_id = member.user_id
       left join argus_app.preferences preferences on preferences.user_id = member.user_id`
      : "";
    const result = await database.query<JsonObject>(
      `select jsonb_build_object(
         'member', to_jsonb(member),
         ${profileAndPreferencesProjection}
         'onboarding', to_jsonb(onboarding),
         'investor_profile', to_jsonb(investor),
         'astrology_profile', to_jsonb(astrology),
         'server_time', clock_timestamp()
       ) as snapshot
       from argus_app.members member
       ${profileAndPreferencesJoins}
       left join argus_app.onboarding_states onboarding on onboarding.user_id = member.user_id
       left join argus_app.investor_profiles investor on investor.user_id = member.user_id
       left join argus_app.astrology_profiles astrology on astrology.user_id = member.user_id
       where member.user_id = argus_private.trusted_request_user_id() and member.status = 'active'`,
    );
    return supabaseSessionSnapshotSchema.parse(first(result.rows).snapshot);
  };
  return Object.freeze({
    bootstrap: async () => selectSnapshot(database),
    finalizeOnboarding: async (
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
    ) => {
      const operation = "onboarding.finalize";
      const requestHash = await sha256TextHex(JSON.stringify(input));
      await database.query(
        "select pg_advisory_xact_lock(hashtextextended($1,0))",
        [JSON.stringify([verifiedSubject, operation, idempotencyKey])],
      );
      const existing = await database.query<{
        request_hash: string;
        response_status: number | null;
      }>(
        `select request_hash,response_status
             from argus_private.member_idempotency_records
            where user_id=argus_private.request_user_id()
              and operation=$1 and idempotency_key=$2`,
        [operation, idempotencyKey],
      );
      if (existing.rows[0] !== undefined) {
        if (existing.rows[0].request_hash !== requestHash) {
          throw new RepositoryRevisionConflictError();
        }
        return selectSnapshot(database, "runtime");
      }
      const current = await database.query<
        { version: number; completed_at: string | null }
      >(
        `select version,completed_at from argus_app.onboarding_states
            where user_id=argus_private.request_user_id() for update`,
      );
      const onboarding = first(current.rows);
      if (
        onboarding.completed_at !== null ||
        onboarding.version !== input.expectedOnboardingVersion
      ) {
        throw new RepositoryRevisionConflictError();
      }
      await database.query(
        `insert into argus_app.investor_profiles(
             user_id,deletion_epoch,goal_type,time_horizon,risk_comfort
           ) select member.user_id,member.deletion_epoch,$1,$2,$3
               from argus_app.members member
              where member.user_id=argus_private.request_user_id()
           on conflict (user_id) do update
             set goal_type=excluded.goal_type,
                 time_horizon=excluded.time_horizon,
                 risk_comfort=excluded.risk_comfort,
                 version=argus_app.investor_profiles.version+1`,
        [
          input.investing.goalType,
          input.investing.timeHorizon,
          input.investing.riskComfort,
        ],
      );
      if (input.astrology.enabled) {
        await database.query(
          `insert into argus_app.astrology_profiles(
               user_id,deletion_epoch,birth_date,derived_profile_code
             ) select member.user_id,member.deletion_epoch,$1,
                      case extract(month from $1::date)::int % 3
                        when 0 then 'lunar_patient'
                        when 1 then 'solar_builder'
                        else 'rising_explorer'
                      end
                 from argus_app.members member
                where member.user_id=argus_private.request_user_id()
             on conflict (user_id) do update
               set birth_date=excluded.birth_date,
                   derived_profile_code=excluded.derived_profile_code,
                   algorithm_version='v1',enabled_at=clock_timestamp()`,
          [input.astrology.birthDate ?? null],
        );
      } else {
        await database.query(
          "delete from argus_app.astrology_profiles where user_id=argus_private.request_user_id()",
        );
      }
      for (const [policyCode, consent] of Object.entries(input.consents)) {
        await database.query(
          `insert into argus_app.consent_records(
               user_id,deletion_epoch,policy_code,policy_version,decision
             ) select member.user_id,member.deletion_epoch,$1,$2,$3
                 from argus_app.members member
                where member.user_id=argus_private.request_user_id()
             on conflict (user_id,policy_code,policy_version,decision) do nothing`,
          [policyCode, consent.policyVersion, consent.decision],
        );
      }
      await database.query(
        `update argus_app.onboarding_states
              set current_step='complete',
                  completed_steps='["investing","ritual","astrology","consents"]'::jsonb,
                  completed_at=clock_timestamp(),version=version+1
            where user_id=argus_private.request_user_id()`,
      );
      await database.query(
        `insert into argus_private.member_idempotency_records(
             user_id,deletion_epoch,operation,idempotency_key,request_hash,response_status
           ) select member.user_id,member.deletion_epoch,$1,$2,$3,200
               from argus_app.members member
              where member.user_id=argus_private.request_user_id()`,
        [operation, idempotencyKey, requestHash],
      );
      return selectSnapshot(database, "runtime");
    },
  });
}
