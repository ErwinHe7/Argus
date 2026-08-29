import type { DatabaseTransaction } from "../../db/database-port.ts";
import {
  first,
  type JsonObject,
  RepositoryRevisionConflictError,
} from "../../db/repository-support.ts";

export function createSupabaseAccountRepository(
  database: DatabaseTransaction,
) {
  return Object.freeze({
    get: async () => {
      const result = await database.query<JsonObject>(
        `select member.status, member.deletion_epoch,
                  to_jsonb(profile) as profile,
                  to_jsonb(preferences) as preferences,
                  to_jsonb(onboarding) as onboarding,
                  to_jsonb(investor) as investor_profile,
                  case when astrology.user_id is null then null
                       else to_jsonb(astrology) || jsonb_build_object('version',1)
                  end as astrology_profile
             from argus_app.members member
             left join argus_app.profiles profile on profile.user_id = member.user_id
             left join argus_app.preferences preferences on preferences.user_id = member.user_id
             left join argus_app.onboarding_states onboarding on onboarding.user_id = member.user_id
             left join argus_app.investor_profiles investor on investor.user_id = member.user_id
             left join argus_app.astrology_profiles astrology on astrology.user_id = member.user_id
            where member.user_id = argus_private.trusted_request_user_id()`,
      );
      return first(result.rows);
    },
    updatePreferences: async (
      patch: Readonly<{
        themeMode?: "system" | "light" | "dark";
        ritualMode?: "tarot" | "astrology";
        timezone?: string;
        locale?: string;
      }>,
      expectedVersion: number,
    ) => {
      const result = await database.query<JsonObject>(
        `update argus_app.preferences
              set theme_mode = coalesce($1, theme_mode),
                  ritual_mode = coalesce($2, ritual_mode),
                  timezone = coalesce($3, timezone),
                  locale = coalesce($4, locale),
                  version = version + 1
            where user_id = argus_private.trusted_request_user_id() and version = $5
          returning *`,
        [
          patch.themeMode ?? null,
          patch.ritualMode ?? null,
          patch.timezone ?? null,
          patch.locale ?? null,
          expectedVersion,
        ],
      );
      if (result.rows.length !== 1) {
        throw new RepositoryRevisionConflictError();
      }
      return result.rows[0]!;
    },
    recordConsent: async (
      input: Readonly<{
        policyCode: string;
        policyVersion: string;
        decision: "accepted" | "declined" | "withdrawn";
      }>,
    ) => {
      const result = await database.query<JsonObject>(
        `insert into argus_app.consent_records(
             user_id, deletion_epoch, policy_code, policy_version, decision
           )
           select argus_private.trusted_request_user_id(), member.deletion_epoch, $1, $2, $3
             from argus_app.members member
            where member.user_id = argus_private.trusted_request_user_id() and member.status = 'active'
          returning *`,
        [input.policyCode, input.policyVersion, input.decision],
      );
      return first(result.rows);
    },
    updateInvestor: async (
      input: Readonly<{
        goalType: "calm_fund" | "long_term_growth" | "income" | "exploration";
        timeHorizon: "short" | "medium" | "long";
        riskComfort: "low" | "moderate" | "high";
      }>,
      expectedVersion?: number,
    ) => {
      const current = await database.query<{ version: number }>(
        `select version from argus_app.investor_profiles
          where user_id=argus_private.trusted_request_user_id() for update`,
      );
      if (current.rows[0] === undefined) {
        if (expectedVersion !== undefined) {
          throw new RepositoryRevisionConflictError();
        }
        const inserted = await database.query<JsonObject>(
          `insert into argus_app.investor_profiles(
             user_id,deletion_epoch,goal_type,time_horizon,risk_comfort
           ) select member.user_id,member.deletion_epoch,$1,$2,$3
               from argus_app.members member
              where member.user_id=argus_private.trusted_request_user_id() and member.status='active'
          returning *`,
          [input.goalType, input.timeHorizon, input.riskComfort],
        );
        return first(inserted.rows);
      }
      if (expectedVersion !== current.rows[0].version) {
        throw new RepositoryRevisionConflictError();
      }
      const updated = await database.query<JsonObject>(
        `update argus_app.investor_profiles
            set goal_type=$1,time_horizon=$2,risk_comfort=$3,version=version+1
          where user_id=argus_private.trusted_request_user_id()
        returning *`,
        [input.goalType, input.timeHorizon, input.riskComfort],
      );
      return first(updated.rows);
    },
    updateAstrology: async (birthDate: string, expectedVersion?: number) => {
      const current = await database.query<{ present: boolean }>(
        `select true as present from argus_app.astrology_profiles
            where user_id=argus_private.trusted_request_user_id() for update`,
      );
      if (current.rows[0] === undefined && expectedVersion !== undefined) {
        throw new RepositoryRevisionConflictError();
      }
      if (current.rows[0] !== undefined && expectedVersion !== 1) {
        throw new RepositoryRevisionConflictError();
      }
      const result = await database.query<JsonObject>(
        `insert into argus_app.astrology_profiles(
             user_id,deletion_epoch,birth_date,derived_profile_code
           ) select member.user_id,member.deletion_epoch,$1,
                    case extract(month from $1::date)::int % 3
                      when 0 then 'lunar_patient'
                      when 1 then 'solar_builder'
                      else 'rising_explorer'
                    end
               from argus_app.members member
              where member.user_id=argus_private.trusted_request_user_id() and member.status='active'
           on conflict (user_id) do update
             set birth_date=excluded.birth_date,
                 derived_profile_code=excluded.derived_profile_code,
                 algorithm_version='v1',enabled_at=clock_timestamp()
          returning *,1 as version`,
        [birthDate],
      );
      return first(result.rows);
    },
    deleteAstrology: async (expectedVersion: number) => {
      if (expectedVersion !== 1) throw new RepositoryRevisionConflictError();
      await database.query(
        `delete from argus_app.astrology_profiles
            where user_id=argus_private.trusted_request_user_id()`,
      );
      return { removed: true };
    },
  });
}
