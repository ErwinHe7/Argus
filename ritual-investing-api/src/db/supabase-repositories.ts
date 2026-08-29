import type { DatabasePool, DatabaseTransaction } from "./database-port.ts";
import {
  type RequestTransactionConfig,
  StaffAuthorizationError,
  withActiveStaffRequestTransaction,
  withAnonymousRequestTransaction,
  withRequestTransaction,
  withStaffRequestTransaction,
} from "./request-transaction.ts";
import type { VerifiedRequestClaims } from "./request-context.ts";
import { supabaseSessionSnapshotSchema } from "../domains/session/supabase-schemas.ts";
import { sha256TextHex } from "../security/sha256.ts";

export type JsonObject = Record<string, unknown>;

export type PrivacySignedStorage = Readonly<{
  createSignedUrl(bucket: string, path: string, expiresInSeconds: number): Promise<string>;
}>;

export class RepositoryNotFoundError extends Error {
  constructor() {
    super("resource_not_found");
    this.name = "RepositoryNotFoundError";
  }
}

export class RepositoryRevisionConflictError extends Error {
  constructor() {
    super("revision_conflict");
    this.name = "RepositoryRevisionConflictError";
  }
}

export class RepositoryStepUpRequiredError extends Error {
  constructor() {
    super("step_up_required");
    this.name = "RepositoryStepUpRequiredError";
  }
}

/**
 * The exact U2 relations owned by each retained domain. This registry is also
 * the migration/import-boundary contract: accepted repositories may not fall
 * back to an unqualified relation or a legacy database function.
 */
export const RETAINED_SUPABASE_RELATIONS = Object.freeze({
  session: [
    "argus_app.members",
    "argus_app.profiles",
    "argus_app.preferences",
    "argus_app.onboarding_states",
  ],
  accounts: [
    "argus_app.profiles",
    "argus_app.preferences",
    "argus_app.astrology_profiles",
    "argus_app.investor_profiles",
    "argus_app.consent_records",
  ],
  assets: [
    "argus_app.catalog_assets",
    "argus_app.evidence_sources",
    "argus_app.evidence_claims",
  ],
  editorial: [
    "argus_app.editorial_items",
    "argus_app.editorial_revisions",
    "argus_app.evidence_sources",
    "argus_app.evidence_claims",
  ],
  briefings: [
    "argus_app.briefings",
    "argus_app.briefing_sections",
    "argus_app.briefing_read_states",
  ],
  circles: [
    "argus_app.circles",
    "argus_app.circle_assets",
    "argus_app.saved_items",
  ],
  coven: ["argus_app.coven_entries", "argus_app.companies"],
  discover: [
    "argus_app.grimoires",
    "argus_app.community_templates",
    "argus_app.catalog_assets",
  ],
  media: ["argus_private.media_upload_intents", "argus_app.media_assets"],
  moderation: ["argus_app.content_reports", "argus_app.moderation_cases"],
  notifications: [
    "argus_app.notifications",
    "argus_app.notification_preferences",
  ],
  privacy: [
    "argus_app.privacy_requests",
    "argus_private.outbox_events",
    "argus_private.deletion_tombstones",
  ],
  scenarios: [
    "argus_app.intentions",
    "argus_app.future_mirror_runs",
    "argus_app.future_mirror_points",
    "argus_private.member_idempotency_records",
  ],
  publicPreview: [
    "argus_app.editorial_items",
    "argus_app.editorial_revisions",
  ],
  rituals: [
    "argus_app.daily_ritual_assignments",
    "argus_app.ritual_schedules",
    "argus_app.ritual_scenario_revisions",
  ],
  rowan: [
    "argus_app.rowan_scripts",
    "argus_app.rowan_script_revisions",
    "argus_app.rowan_context_bindings",
  ],
  search: ["argus_app.catalog_assets", "argus_app.editorial_items"],
  admin: [
    "argus_private.staff_principals",
    "argus_private.staff_step_up_receipts",
    "argus_private.admin_audit_events",
    "argus_app.editorial_items",
    "argus_app.editorial_revisions",
    "argus_app.editorial_review_requests",
    "argus_app.editorial_review_decisions",
    "argus_app.publication_events",
  ],
  adminOperations: [
    "argus_private.job_runs",
    "argus_app.privacy_requests",
    "argus_private.admin_audit_events",
    "argus_brokerage.connections",
    "argus_private.provider_commands",
    "argus_private.reconciliation_records",
  ],
});

export type SupabaseRepositoryBinding = Readonly<{
  pool: DatabasePool;
  claims: VerifiedRequestClaims;
  signedStorage?: PrivacySignedStorage;
}>;

function config(binding: SupabaseRepositoryBinding): RequestTransactionConfig {
  return { pool: binding.pool, verifiedClaims: binding.claims };
}

function ownerTransaction<T>(
  binding: SupabaseRepositoryBinding,
  callback: (database: DatabaseTransaction) => Promise<T>,
): Promise<T> {
  return withRequestTransaction(config(binding), (database) =>
    callback(database),
  );
}

function staffTransaction<T>(
  binding: SupabaseRepositoryBinding,
  permission: string,
  callback: (database: DatabaseTransaction) => Promise<T>,
): Promise<T> {
  return withStaffRequestTransaction(config(binding), permission, (database) =>
    callback(database),
  );
}

function activeStaffTransaction<T>(
  binding: SupabaseRepositoryBinding,
  callback: (database: DatabaseTransaction) => Promise<T>,
): Promise<T> {
  return withActiveStaffRequestTransaction(config(binding), (database) =>
    callback(database),
  );
}

function first<Row>(rows: Row[]): Row {
  const row = rows[0];
  if (row === undefined) throw new RepositoryNotFoundError();
  return row;
}

async function selectEvidence(
  database: DatabaseTransaction,
  claimIds: readonly string[],
): Promise<JsonObject[]> {
  return (
    await database.query<JsonObject>(
      `select claim.*, to_jsonb(source) as source
         from argus_app.evidence_claims claim
         join argus_app.evidence_sources source on source.id = claim.source_id
        where claim.id = any($1::uuid[])
          and claim.status = 'active' and source.status = 'active'
        order by claim.observed_at desc nulls last, claim.id`,
      [claimIds],
    )
  ).rows;
}

export function createSupabaseSessionRepository(
  binding: SupabaseRepositoryBinding,
) {
  const selectSnapshot = async (database: DatabaseTransaction) => {
    const result = await database.query<JsonObject>(
      `select jsonb_build_object(
         'member', to_jsonb(member),
         'profile', to_jsonb(profile),
         'preferences', to_jsonb(preferences),
         'onboarding', to_jsonb(onboarding),
         'investor_profile', to_jsonb(investor),
         'astrology_profile', to_jsonb(astrology),
         'server_time', clock_timestamp()
       ) as snapshot
       from argus_app.members member
       left join argus_app.profiles profile on profile.user_id = member.user_id
       left join argus_app.preferences preferences on preferences.user_id = member.user_id
       left join argus_app.onboarding_states onboarding on onboarding.user_id = member.user_id
       left join argus_app.investor_profiles investor on investor.user_id = member.user_id
       left join argus_app.astrology_profiles astrology on astrology.user_id = member.user_id
       where member.user_id = argus_private.request_user_id() and member.status = 'active'`,
    );
    return supabaseSessionSnapshotSchema.parse(first(result.rows).snapshot);
  };
  return Object.freeze({
    bootstrap: () =>
      ownerTransaction(binding, selectSnapshot),
    finalizeOnboarding: (input: Readonly<{
      expectedOnboardingVersion: number;
      investing: Readonly<{
        goalType: "calm_fund" | "long_term_growth" | "income" | "exploration";
        timeHorizon: "short" | "medium" | "long";
        riskComfort: "low" | "moderate" | "high";
      }>;
      astrology: Readonly<{ enabled: boolean; birthDate?: string }>;
      consents: Readonly<Record<string, Readonly<{
        policyVersion: string;
        decision: "accepted" | "declined";
      }>>>;
    }>, idempotencyKey: string) =>
      ownerTransaction(binding, async (database) => {
        const operation = "onboarding.finalize";
        const requestHash = await sha256TextHex(JSON.stringify(input));
        await database.query(
          "select pg_advisory_xact_lock(hashtextextended($1,0))",
          [`${binding.claims.userId}\u0000${operation}\u0000${idempotencyKey}`],
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
          return selectSnapshot(database);
        }
        const current = await database.query<{ version: number; completed_at: string | null }>(
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
        return selectSnapshot(database);
      }),
  });
}

export function createSupabaseAccountRepository(
  binding: SupabaseRepositoryBinding,
) {
  return Object.freeze({
    get: () =>
      ownerTransaction(binding, async (database) => {
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
            where member.user_id = argus_private.request_user_id()`,
        );
        return first(result.rows);
      }),
    updatePreferences: (
      patch: Readonly<{
        themeMode?: "system" | "light" | "dark";
        ritualMode?: "tarot" | "astrology";
        timezone?: string;
        locale?: string;
      }>,
      expectedVersion: number,
    ) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `update argus_app.preferences
              set theme_mode = coalesce($1, theme_mode),
                  ritual_mode = coalesce($2, ritual_mode),
                  timezone = coalesce($3, timezone),
                  locale = coalesce($4, locale),
                  version = version + 1
            where user_id = argus_private.request_user_id() and version = $5
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
      }),
    recordConsent: (
      input: Readonly<{
        policyCode: string;
        policyVersion: string;
        decision: "accepted" | "declined" | "withdrawn";
      }>,
    ) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `insert into argus_app.consent_records(
             user_id, deletion_epoch, policy_code, policy_version, decision
           )
           select argus_private.request_user_id(), member.deletion_epoch, $1, $2, $3
             from argus_app.members member
            where member.user_id = argus_private.request_user_id() and member.status = 'active'
          returning *`,
          [input.policyCode, input.policyVersion, input.decision],
        );
        return first(result.rows);
      }),
    updateInvestor: (
      input: Readonly<{
        goalType: "calm_fund" | "long_term_growth" | "income" | "exploration";
        timeHorizon: "short" | "medium" | "long";
        riskComfort: "low" | "moderate" | "high";
      }>,
      expectedVersion?: number,
    ) => ownerTransaction(binding, async (database) => {
      const current = await database.query<{ version: number }>(
        `select version from argus_app.investor_profiles
          where user_id=argus_private.request_user_id() for update`,
      );
      if (current.rows[0] === undefined) {
        if (expectedVersion !== undefined) throw new RepositoryRevisionConflictError();
        const inserted = await database.query<JsonObject>(
          `insert into argus_app.investor_profiles(
             user_id,deletion_epoch,goal_type,time_horizon,risk_comfort
           ) select member.user_id,member.deletion_epoch,$1,$2,$3
               from argus_app.members member
              where member.user_id=argus_private.request_user_id() and member.status='active'
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
          where user_id=argus_private.request_user_id()
        returning *`,
        [input.goalType, input.timeHorizon, input.riskComfort],
      );
      return first(updated.rows);
    }),
    updateAstrology: (birthDate: string, expectedVersion?: number) =>
      ownerTransaction(binding, async (database) => {
        const current = await database.query<{ present: boolean }>(
          `select true as present from argus_app.astrology_profiles
            where user_id=argus_private.request_user_id() for update`,
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
              where member.user_id=argus_private.request_user_id() and member.status='active'
           on conflict (user_id) do update
             set birth_date=excluded.birth_date,
                 derived_profile_code=excluded.derived_profile_code,
                 algorithm_version='v1',enabled_at=clock_timestamp()
          returning *,1 as version`,
          [birthDate],
        );
        return first(result.rows);
      }),
    deleteAstrology: (expectedVersion: number) =>
      ownerTransaction(binding, async (database) => {
        if (expectedVersion !== 1) throw new RepositoryRevisionConflictError();
        await database.query(
          `delete from argus_app.astrology_profiles
            where user_id=argus_private.request_user_id()`,
        );
        return { removed: true };
      }),
  });
}

export function createSupabaseCircleRepository(
  binding: SupabaseRepositoryBinding,
) {
  const selectCircle = async (database: DatabaseTransaction, id: string) => {
    const result = await database.query<JsonObject>(
      `select circle.*,true as private,
              (select item.current_published_revision_id
                 from argus_app.community_templates template
                 join argus_app.editorial_items item on item.id=template.editorial_item_id
                where template.id=circle.source_template_id) as source_revision_id,
              coalesce(jsonb_agg(to_jsonb(asset) order by asset.ordinal)
                filter (where asset.id is not null), '[]'::jsonb) as assets
         from argus_app.circles circle
         left join argus_app.circle_assets asset
           on asset.user_id = circle.user_id and asset.circle_id = circle.id
        where circle.user_id = argus_private.request_user_id() and circle.id = $1
        group by circle.id`,
      [id],
    );
    return first(result.rows);
  };
  return Object.freeze({
    list: (limit: number) =>
      ownerTransaction(binding, async (database) =>
        (
          await database.query<JsonObject>(
            `select circle.*,true as private,
                    (select item.current_published_revision_id
                       from argus_app.community_templates template
                       join argus_app.editorial_items item on item.id=template.editorial_item_id
                      where template.id=circle.source_template_id) as source_revision_id,
                    coalesce((select jsonb_agg(to_jsonb(asset) order by asset.ordinal)
                                from argus_app.circle_assets asset
                               where asset.user_id=circle.user_id and asset.circle_id=circle.id),
                             '[]'::jsonb) as assets
               from argus_app.circles circle
              where user_id = argus_private.request_user_id()
              order by archived_at nulls first, id
              limit $1`,
            [limit],
          )
        ).rows,
      ),
    get: (id: string) =>
      ownerTransaction(binding, (database) => selectCircle(database, id)),
    create: (input: Readonly<{
      title: string;
      description: string;
      assets?: readonly Readonly<{
        assetId: string;
        ordinal: number;
        weightBps?: number | null | undefined;
        note?: string | null | undefined;
      }>[];
      sourceTemplateId?: string;
    }>) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `insert into argus_app.circles(
             user_id, deletion_epoch, title, description,source_template_id
           )
           select argus_private.request_user_id(), member.deletion_epoch, $1, $2,$3
             from argus_app.members member
            where member.user_id = argus_private.request_user_id() and member.status = 'active'
          returning *`,
          [input.title, input.description, input.sourceTemplateId ?? null],
        );
        const circle = first(result.rows);
        for (const asset of input.assets ?? []) {
          await database.query(
            `insert into argus_app.circle_assets(
               user_id,deletion_epoch,circle_id,asset_id,ordinal,weight_bps,note
             ) values(argus_private.request_user_id(),$1,$2,$3,$4,$5,$6)`,
            [
              circle.deletion_epoch,
              circle.id,
              asset.assetId,
              asset.ordinal,
              asset.weightBps ?? null,
              asset.note ?? null,
            ],
          );
        }
        return selectCircle(database, String(circle.id));
      }),
    update: (
      id: string,
      input: Readonly<{ title?: string; description?: string }>,
      expectedVersion: number,
    ) =>
      ownerTransaction(binding, async (database) => {
        const updated = await database.query<JsonObject>(
          `update argus_app.circles
              set title = coalesce($2, title),
                  description = coalesce($3, description),
                  version = version + 1
            where user_id = argus_private.request_user_id() and id = $1 and version = $4
          returning id`,
          [
            id,
            input.title ?? null,
            input.description ?? null,
            expectedVersion,
          ],
        );
        if (updated.rows.length !== 1) {
          throw new RepositoryRevisionConflictError();
        }
        return selectCircle(database, id);
      }),
    replaceAssets: (
      id: string,
      assets: readonly Readonly<{
        assetId: string;
        ordinal: number;
        weightBps?: number | null | undefined;
        note?: string | null | undefined;
      }>[],
      expectedVersion: number,
    ) => ownerTransaction(binding, async (database) => {
      const updated = await database.query<{ deletion_epoch: number }>(
        `update argus_app.circles set version=version+1
          where user_id=argus_private.request_user_id() and id=$1 and version=$2
        returning deletion_epoch`,
        [id, expectedVersion],
      );
      const circle = first(updated.rows);
      await database.query(
        `delete from argus_app.circle_assets
          where user_id=argus_private.request_user_id() and circle_id=$1`,
        [id],
      );
      for (const asset of assets) {
        await database.query(
          `insert into argus_app.circle_assets(
             user_id,deletion_epoch,circle_id,asset_id,ordinal,weight_bps,note
           ) values(argus_private.request_user_id(),$1,$2,$3,$4,$5,$6)`,
          [circle.deletion_epoch,id,asset.assetId,asset.ordinal,asset.weightBps ?? null,asset.note ?? null],
        );
      }
      return selectCircle(database,id);
    }),
    putAsset: (
      id: string,
      assetId: string,
      asset: Readonly<{
        ordinal: number;
        weightBps?: number | null | undefined;
        note?: string | null | undefined;
      }>,
      expectedVersion: number,
    ) => ownerTransaction(binding, async (database) => {
      const updated = await database.query<{ deletion_epoch: number }>(
        `update argus_app.circles set version=version+1
          where user_id=argus_private.request_user_id() and id=$1 and version=$2
        returning deletion_epoch`,
        [id,expectedVersion],
      );
      const circle = first(updated.rows);
      await database.query(
        `insert into argus_app.circle_assets(
           user_id,deletion_epoch,circle_id,asset_id,ordinal,weight_bps,note
         ) values(argus_private.request_user_id(),$1,$2,$3,$4,$5,$6)
         on conflict(user_id,circle_id,asset_id) do update
           set ordinal=excluded.ordinal,weight_bps=excluded.weight_bps,note=excluded.note`,
        [circle.deletion_epoch,id,assetId,asset.ordinal,asset.weightBps ?? null,asset.note ?? null],
      );
      return selectCircle(database,id);
    }),
    deleteAsset: (id: string, assetId: string, expectedVersion: number) =>
      ownerTransaction(binding, async (database) => {
        const updated = await database.query(
          `update argus_app.circles set version=version+1
            where user_id=argus_private.request_user_id() and id=$1 and version=$2
          returning id`,
          [id,expectedVersion],
        );
        first(updated.rows);
        await database.query(
          `delete from argus_app.circle_assets
            where user_id=argus_private.request_user_id() and circle_id=$1 and asset_id=$2`,
          [id,assetId],
        );
        return selectCircle(database,id);
      }),
    archive: (id: string, expectedVersion: number) =>
      ownerTransaction(binding, async (database) => {
        const updated = await database.query(
          `update argus_app.circles
              set archived_at=coalesce(archived_at,clock_timestamp()),version=version+1
            where user_id=argus_private.request_user_id() and id=$1 and version=$2
          returning id`,
          [id,expectedVersion],
        );
        first(updated.rows);
        return selectCircle(database,id);
      }),
    getTemplate: (id: string) => ownerTransaction(binding, async (database) => {
      const result = await database.query<JsonObject>(
        `select template.*,item.slug,revision.id as revision_id,revision.created_at as revision_created_at,
                revision.payload,
                exists(select 1 from argus_app.saved_items saved
                        where saved.user_id=argus_private.request_user_id()
                          and saved.item_kind='circle_template' and saved.item_id=template.id) as saved,
                coalesce((select jsonb_agg(jsonb_build_object(
                  'id',asset.id,'slug',asset.slug,'symbol',asset.symbol,'name',asset.name,
                  'asset_type',asset.asset_type,'currency',asset.currency,
                  'ordinal',entry.ordinal,'weight_bps',null,'note',null,
                  'revision_id',asset_revision.id,'payload',asset_revision.payload
                ) order by entry.ordinal)
                  from unnest(template.asset_ids) with ordinality entry(asset_id,ordinal)
                  join argus_app.catalog_assets asset on asset.id=entry.asset_id
                  left join lateral (
                    select r.id,r.payload from argus_app.editorial_items i
                    join argus_app.editorial_revisions r on r.id=i.current_published_revision_id
                    where i.kind='asset_codex' and (i.slug=asset.slug or r.payload->>'asset_id'=asset.id::text)
                    limit 1
                  ) asset_revision on true),'[]'::jsonb) as assets
           from argus_app.community_templates template
           join argus_app.editorial_items item on item.id=template.editorial_item_id
           join argus_app.editorial_revisions revision on revision.id=item.current_published_revision_id
          where template.id=$1 and item.status='published' and revision.state='published'`,
        [id],
      );
      return result.rows[0] ?? null;
    }),
    listSaved: (limit: number) =>
      ownerTransaction(binding, async (database) =>
        (
          await database.query<JsonObject>(
            `select * from argus_app.saved_items
              where user_id = argus_private.request_user_id()
              order by saved_at desc, item_kind, item_id
              limit $1`,
            [limit],
          )
        ).rows,
      ),
    save: (
      itemKind: "asset" | "grimoire" | "circle_template" | "coven",
      itemId: string,
      sourceKind = "direct",
      sourceId?: string,
    ) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `insert into argus_app.saved_items(
             user_id, deletion_epoch, item_kind, item_id, source_kind, source_id
           )
           select argus_private.request_user_id(), member.deletion_epoch, $1, $2, $3, $4
             from argus_app.members member
            where member.user_id = argus_private.request_user_id() and member.status = 'active'
           on conflict (user_id, item_kind, item_id) do update
             set source_kind = excluded.source_kind, source_id = excluded.source_id
          returning *`,
          [itemKind, itemId, sourceKind, sourceId ?? null],
        );
        return first(result.rows);
      }),
    unsave: (
      itemKind: "asset" | "grimoire" | "circle_template" | "coven",
      itemId: string,
    ) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `delete from argus_app.saved_items
            where user_id = argus_private.request_user_id() and item_kind = $1 and item_id = $2
          returning *`,
          [itemKind, itemId],
        );
        return result.rows[0] ?? null;
      }),
  });
}

export function createSupabaseEditorialRepository(
  binding: SupabaseRepositoryBinding,
) {
  return Object.freeze({
    listPublished: (kind: string, limit: number) =>
      ownerTransaction(binding, async (database) =>
        (
          await database.query<JsonObject>(
            `select item.id, item.kind, item.slug, revision.id as revision_id,
                    revision.revision_number, revision.payload
               from argus_app.editorial_items item
               join argus_app.editorial_revisions revision
                 on revision.id = item.current_published_revision_id
              where item.status = 'published'
                and revision.state = 'published'
                and item.kind = $1
              order by item.slug, item.id
              limit $2`,
            [kind, limit],
          )
        ).rows,
      ),
    getPublished: (slug: string) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `select item.id, item.kind, item.slug, revision.id as revision_id,
                  revision.revision_number, revision.payload
             from argus_app.editorial_items item
             join argus_app.editorial_revisions revision
               on revision.id = item.current_published_revision_id
            where item.status = 'published'
              and revision.state = 'published'
              and item.slug = $1`,
          [slug],
        );
        return result.rows[0] ?? null;
      }),
    listEvidence: (claimIds: readonly string[]) =>
      ownerTransaction(binding, (database) =>
        selectEvidence(database, claimIds),
      ),
  });
}

export function createSupabaseBriefingRepository(
  binding: SupabaseRepositoryBinding,
) {
  const selectBriefing = `select briefing.*,1 as generation,1 as source_sequence,
      read_state.read_at,
      coalesce(jsonb_agg(to_jsonb(section) order by section.ordinal)
        filter (where section.id is not null),'[]'::jsonb) as sections
    from argus_app.briefings briefing
    left join argus_app.briefing_sections section
      on section.user_id=briefing.user_id and section.briefing_id=briefing.id
    left join argus_app.briefing_read_states read_state
      on read_state.user_id=briefing.user_id
     and read_state.deletion_epoch=briefing.deletion_epoch
     and read_state.briefing_id=briefing.id
   where briefing.user_id=argus_private.request_user_id()`;
  return Object.freeze({
    list: (
      limit: number,
      type?: string,
      periodStart?: string,
      periodEnd?: string,
    ) =>
      ownerTransaction(binding, async (database) =>
        (
          await database.query<JsonObject>(
            `select briefing.*,1 as generation,1 as source_sequence,
                    read_state.read_at
               from argus_app.briefings briefing
               left join argus_app.briefing_read_states read_state
                 on read_state.user_id=briefing.user_id
                and read_state.deletion_epoch=briefing.deletion_epoch
                and read_state.briefing_id=briefing.id
              where briefing.user_id = argus_private.request_user_id()
                and briefing.status='ready'
                and ($2::text is null or briefing_type=$2)
                and ($3::date is null or period_start >= $3)
                and ($4::date is null or period_end <= $4)
              order by period_end desc, id desc
              limit $1`,
            [limit, type ?? null, periodStart ?? null, periodEnd ?? null],
          )
        ).rows,
      ),
    get: (id: string) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `${selectBriefing} and briefing.id = $1
            and briefing.status='ready'
            group by briefing.id, read_state.read_at`,
          [id],
        );
        return result.rows[0] ?? null;
      }),
    daily: (localDate: string) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `${selectBriefing}
             and briefing.briefing_type='daily'
             and briefing.period_start <= $1 and briefing.period_end >= $1
           group by briefing.id, read_state.read_at
           order by briefing.generated_at desc nulls last,briefing.id desc
           limit 1`,
          [localDate],
        );
        return result.rows[0] ?? null;
      }),
    setRead: (id: string, read: boolean) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `with target as materialized (
             select briefing.*
               from argus_app.briefings briefing
              where briefing.user_id=argus_private.request_user_id()
                and briefing.id=$1
           ), marked as (
             insert into argus_app.briefing_read_states (
               user_id,deletion_epoch,briefing_id,read_at,updated_at
             )
             select target.user_id,target.deletion_epoch,target.id,
                    clock_timestamp(),clock_timestamp()
               from target
              where $2
             on conflict (user_id,briefing_id) do update
               set deletion_epoch=excluded.deletion_epoch,
                   read_at=excluded.read_at,
                   updated_at=excluded.updated_at
             returning read_at
           ), unmarked as (
             delete from argus_app.briefing_read_states read_state
              using target
              where not $2
                and read_state.user_id=target.user_id
                and read_state.deletion_epoch=target.deletion_epoch
                and read_state.briefing_id=target.id
             returning read_state.briefing_id
           )
           select target.*,1 as generation,1 as source_sequence,
                  case when $2 then (select read_at from marked) else null end as read_at
             from target`,
          [id, read],
        );
        return first(result.rows);
      }),
  });
}

export function createSupabaseNotificationRepository(
  binding: SupabaseRepositoryBinding,
) {
  return Object.freeze({
    list: (limit: number) =>
      ownerTransaction(binding, async (database) =>
        (
          await database.query<JsonObject>(
            `select notification.*, null::text as deep_link,
                    notification.created_at as scheduled_at
               from argus_app.notifications notification
              where user_id = argus_private.request_user_id()
              order by created_at desc, id desc
              limit $1`,
            [limit],
          )
        ).rows,
      ),
    setRead: (id: string, read: boolean) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `update argus_app.notifications
              set read_at = case when $2 then coalesce(read_at, clock_timestamp()) else null end
            where user_id = argus_private.request_user_id() and id = $1
          returning *, null::text as deep_link, created_at as scheduled_at`,
          [id, read],
        );
        return first(result.rows);
      }),
    readAll: (before: string) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `with updated as (
             update argus_app.notifications
                set read_at=coalesce(read_at,clock_timestamp())
              where user_id=argus_private.request_user_id()
                and created_at <= $1 and read_at is null
              returning id
           ) select count(*)::int as updated_count from updated`,
          [before],
        );
        return first(result.rows);
      }),
    getPreferences: () =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `select * from argus_app.notification_preferences
            where user_id = argus_private.request_user_id()`,
        );
        return first(result.rows);
      }),
    updatePreferences: (patch: JsonObject, expectedVersion: number) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `update argus_app.notification_preferences
              set daily_ritual = coalesce(($1::jsonb->>'daily_ritual')::boolean, daily_ritual),
                  weekly_recap = coalesce(($1::jsonb->>'weekly_recap')::boolean, weekly_recap),
                  moon_cycle = coalesce(($1::jsonb->>'moon_cycle')::boolean, moon_cycle),
                  quiet_hours = coalesce($1::jsonb->'quiet_hours', quiet_hours),
                  version = version + 1
            where user_id = argus_private.request_user_id() and version = $2
          returning *`,
          [patch, expectedVersion],
        );
        if (result.rows.length !== 1) {
          throw new RepositoryRevisionConflictError();
        }
        return result.rows[0]!;
      }),
  });
}

export function createSupabaseMediaRepository(
  binding: SupabaseRepositoryBinding,
) {
  return Object.freeze({
    createUploadIntent: (
      input: Readonly<{
        bucketId: "member-media" | "media-quarantine";
        objectPath: string;
        mimeType: "image/jpeg" | "image/png" | "image/webp";
        maxBytes: number;
        expiresAt: Date;
      }>,
    ) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `insert into argus_private.media_upload_intents(
             user_id, deletion_epoch, bucket_id, object_path, mime_type,
             max_bytes, expires_at
           )
           select argus_private.request_user_id(), member.deletion_epoch, $1, $2, $3, $4, $5
             from argus_app.members member
            where member.user_id = argus_private.request_user_id() and member.status = 'active'
          returning *`,
          [
            input.bucketId,
            input.objectPath,
            input.mimeType,
            input.maxBytes,
            input.expiresAt,
          ],
        );
        return first(result.rows);
      }),
    getUploadIntent: (id: string) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `select * from argus_private.media_upload_intents
            where user_id = argus_private.request_user_id() and id = $1`,
          [id],
        );
        return result.rows[0] ?? null;
      }),
    finalizeUpload: (intentId: string, byteSize: number, checksum: string) =>
      staffTransaction(binding, "editorial:write", async (database) => {
        const updated = await database.query<{
          bucket_id: string;
          object_path: string;
          mime_type: string;
          max_bytes: number;
          user_id: string;
          deletion_epoch: number;
        }>(
          `update argus_private.media_upload_intents
              set status = 'uploaded'
            where id = $1 and user_id = argus_private.request_user_id() and status = 'pending'
              and expires_at > clock_timestamp() and max_bytes >= $2
          returning bucket_id, object_path, mime_type, max_bytes, user_id, deletion_epoch`,
          [intentId, byteSize],
        );
        const intent = first(updated.rows);
        const asset = await database.query<JsonObject>(
          `insert into argus_app.media_assets(
             storage_bucket, storage_path, mime_type, byte_size, checksum
           ) values ($1, $2, $3, $4, $5)
          returning *`,
          [
            intent.bucket_id,
            intent.object_path,
            intent.mime_type,
            byteSize,
            checksum,
          ],
        );
        await database.query(
          `insert into argus_private.outbox_events(
             user_id,deletion_epoch,topic,event_type,aggregate_id,dedupe_key
           ) values ($1,$2,'argus_jobs','media.scan.requested',$3,$4)
           on conflict (topic,dedupe_key) do nothing`,
          [intent.user_id, intent.deletion_epoch, intentId, `media-scan:${intentId}`],
        );
        return first(asset.rows);
      }),
    getAsset: (id: string) =>
      staffTransaction(binding, "editorial:read", async (database) => {
        const result = await database.query<JsonObject>(
          `select * from argus_app.media_assets where id = $1`,
          [id],
        );
        return result.rows[0] ?? null;
      }),
  });
}

export function createSupabaseModerationRepository(
  binding: SupabaseRepositoryBinding,
) {
  return Object.freeze({
    report: (
      input: Readonly<{
        targetKind: string;
        targetId: string;
        reasonCode: string;
        details?: string;
      }>,
    ) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `insert into argus_app.content_reports(
             user_id, deletion_epoch, target_kind, target_id, reason_code,
             details
           )
           select argus_private.request_user_id(), member.deletion_epoch, $1, $2, $3, $4
             from argus_app.members member
            where member.user_id = argus_private.request_user_id() and member.status = 'active'
          returning *`,
          [
            input.targetKind,
            input.targetId,
            input.reasonCode,
            input.details ?? null,
          ],
        );
        const report = first(result.rows) as JsonObject & { id: string };
        await database.query(
          `insert into argus_private.outbox_events(
             user_id,deletion_epoch,topic,event_type,aggregate_id,dedupe_key
           )
           select report.user_id,report.deletion_epoch,'argus_jobs',
                  'content-report.created',report.id,$2
             from argus_app.content_reports report where report.id=$1
           on conflict (topic,dedupe_key) do nothing`,
          [report.id, `content-report:${report.id}`],
        );
        return report;
      }),
    decide: (
      caseId: string,
      expectedVersion: number,
      decision: JsonObject,
      correlationId: string,
    ) =>
      staffTransaction(binding, "editorial:write", async (database) => {
        const result = await database.query<JsonObject>(
          `update argus_app.moderation_cases
              set status = $3,
                  decision_payload = $4::jsonb,
                  version = version + 1,
                  updated_at = clock_timestamp()
            where id = $1 and version = $2
          returning *`,
          [caseId, expectedVersion, decision.status, JSON.stringify(decision)],
        );
        if (result.rows.length !== 1) {
          throw new RepositoryRevisionConflictError();
        }
        await database.query(
          `insert into argus_private.admin_audit_events(
             actor_user_id, action, target_kind, target_id, outcome,
             correlation_id
           ) values (argus_private.request_user_id(), 'moderation.decide', 'moderation_case', $1,
                     'allowed', $2)`,
          [caseId, correlationId],
        );
        return result.rows[0]!;
      }),
  });
}

export function createSupabasePrivacyRepository(
  binding: SupabaseRepositoryBinding,
) {
  return Object.freeze({
    list: () =>
      ownerTransaction(binding, async (database) =>
        (
          await database.query<JsonObject>(
            `select * from argus_app.privacy_requests
              where user_id = argus_private.request_user_id()
              order by requested_at desc, id desc`,
          )
        ).rows,
      ),
    request: (
      requestType: "export" | "deletion",
      dedupeKey: string,
      stepUpReceipt?: string,
    ) =>
      ownerTransaction(binding, async (database) => {
        if (requestType === "deletion") {
          if (stepUpReceipt === undefined) throw new RepositoryStepUpRequiredError();
          try {
            const result = await database.query<{ id: string }>(
              "select argus_private.begin_member_deletion($1,$2,$3) as id",
              [
                await sha256TextHex(stepUpReceipt),
                binding.claims.sessionId,
                dedupeKey,
              ],
            );
            const deletion = first(result.rows);
            const request = await database.query<JsonObject>(
              `select * from argus_app.privacy_requests
                where user_id=argus_private.request_user_id() and id=$1`,
              [deletion.id],
            );
            return first(request.rows);
          } catch (error) {
            if (
              error instanceof Error &&
              (error.message === "step_up_required" || error.message.includes("step_up_required"))
            ) {
              throw new RepositoryStepUpRequiredError();
            }
            throw error;
          }
        }
        const scopedDedupeKey = `privacy-export:${await sha256TextHex(
          `${binding.claims.userId}\u0000${dedupeKey}`,
        )}`;
        await database.query(
          "select pg_advisory_xact_lock(hashtextextended($1,0))",
          [scopedDedupeKey],
        );
        const member = await database.query<{ user_id: string }>(
          `select user_id from argus_app.members
            where user_id=argus_private.request_user_id() and status='active'
            for update`,
        );
        if (member.rows[0] === undefined) throw new RepositoryNotFoundError();
        const existing = await database.query<{
          event_type: string;
          aggregate_id: string;
        }>(
          `select event_type,aggregate_id from argus_private.outbox_events
            where user_id=argus_private.request_user_id()
              and topic='argus_jobs' and dedupe_key=$1`,
          [scopedDedupeKey],
        );
        if (existing.rows[0] !== undefined) {
          if (existing.rows[0].event_type !== "privacy.export.requested") {
            throw new RepositoryRevisionConflictError();
          }
          const existingRequest = await database.query<JsonObject>(
            `select * from argus_app.privacy_requests
              where user_id=argus_private.request_user_id() and id=$1`,
            [existing.rows[0].aggregate_id],
          );
          return first(existingRequest.rows);
        }
        const created = await database.query<{ id: string }>(
          `insert into argus_app.privacy_requests(
             user_id, deletion_epoch, request_type, status
           )
           select argus_private.request_user_id(), member.deletion_epoch, $1, 'requested'
             from argus_app.members member
            where member.user_id = argus_private.request_user_id() and member.status = 'active'
          returning id`,
          [requestType],
        );
        const request = first(created.rows);
        await database.query(
          `insert into argus_private.outbox_events(
             user_id, deletion_epoch, topic, event_type, aggregate_id,
             dedupe_key
           )
           select argus_private.request_user_id(), member.deletion_epoch, 'argus_jobs', $2, $1, $3
             from argus_app.members member
            where member.user_id = argus_private.request_user_id() and member.status = 'active'`,
          [request.id, "privacy.export.requested", scopedDedupeKey],
        );
        const createdRequest = await database.query<JsonObject>(
          `select * from argus_app.privacy_requests
            where user_id=argus_private.request_user_id() and id=$1`,
          [request.id],
        );
        return first(createdRequest.rows);
      }),
    getDeletionTombstone: () =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `select * from argus_private.deletion_tombstones
            where user_id = argus_private.request_user_id()
            order by deletion_epoch desc
            limit 1`,
        );
        return result.rows[0] ?? null;
      }),
    createDownloadUrl: async (requestId: string) => {
      if (binding.signedStorage === undefined) throw new Error("storage_unavailable");
      const artifact = await ownerTransaction(binding, async (database) => {
        const result = await database.query<{
          bucket_id: string;
          object_path: string;
        }>(
          `select artifact.bucket_id,artifact.object_path
             from argus_private.privacy_export_artifacts artifact
             join argus_app.privacy_requests request on request.id=artifact.request_id
             join argus_app.members member on member.user_id=artifact.user_id
            where artifact.request_id=$1
              and artifact.user_id=argus_private.request_user_id()
              and artifact.deletion_epoch=member.deletion_epoch
              and request.status='completed'
              and artifact.revoked_at is null
              and artifact.expires_at>clock_timestamp()
              and member.status='active'`,
          [requestId],
        );
        if (result.rows[0] === undefined) throw new RepositoryNotFoundError();
        return result.rows[0];
      });
      const issuedAt = Date.now();
      const url = await binding.signedStorage.createSignedUrl(
        artifact.bucket_id,
        artifact.object_path,
        300,
      );
      await ownerTransaction(binding, async (database) => {
        const current = await database.query<{ current: boolean }>(
          `select exists(
             select 1 from argus_private.privacy_export_artifacts artifact
             join argus_app.privacy_requests request on request.id=artifact.request_id
             join argus_app.members member on member.user_id=artifact.user_id
            where artifact.request_id=$1
              and artifact.user_id=argus_private.request_user_id()
              and artifact.deletion_epoch=member.deletion_epoch
              and artifact.revoked_at is null
              and artifact.expires_at>clock_timestamp()
              and request.status='completed'
              and member.status='active'
           ) as current`,
          [requestId],
        );
        if (current.rows[0]?.current !== true) throw new RepositoryNotFoundError();
      });
      return {
        url,
        expires_at: new Date(issuedAt + 300_000).toISOString(),
      };
    },
  });
}

export function createSupabaseRitualRepository(
  binding: SupabaseRepositoryBinding,
) {
  const selectAssignment = `select assignment.*, revision.payload,
                  rowan.body_template, rowan.allowed_tokens, rowan.risk_footer
             from argus_app.daily_ritual_assignments assignment
             join argus_app.editorial_revisions revision
               on revision.id = assignment.revision_id
             left join argus_app.rowan_script_revisions rowan
               on rowan.revision_id = assignment.rowan_revision_id
            where assignment.user_id = argus_private.request_user_id()`;
  return Object.freeze({
    getDaily: (mode?: "tarot" | "astrology") =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `${selectAssignment}
             and ($1::text is null or assignment.mode = $1)
            order by assignment.local_date desc, assignment.id desc
            limit 1`,
          [mode ?? null],
        );
        return result.rows[0] ?? null;
      }),
    get: (assignmentId: string) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `${selectAssignment} and assignment.id = $1`,
          [assignmentId],
        );
        return result.rows[0] ?? null;
      }),
    history: (limit: number) =>
      ownerTransaction(binding, async (database) =>
        (
          await database.query<JsonObject>(
            `${selectAssignment}
              order by assignment.local_date desc, assignment.id desc
              limit $1`,
            [limit],
          )
        ).rows,
      ),
    evidence: (assignmentId: string) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `select claim.*, to_jsonb(source) as source
             from argus_app.daily_ritual_assignments assignment
             join argus_app.ritual_scenario_revisions scenario
               on scenario.revision_id = assignment.revision_id
             join argus_app.evidence_claims claim
               on claim.id = any(scenario.evidence_claim_ids)
             join argus_app.evidence_sources source on source.id = claim.source_id
            where assignment.user_id = argus_private.request_user_id()
              and assignment.id = $1
              and claim.status = 'active' and source.status = 'active'
            order by claim.observed_at desc nulls last, claim.id`,
          [assignmentId],
        );
        return result.rows;
      }),
    transition: (
      assignmentId: string,
      from: "assigned" | "revealed",
      to: "revealed" | "completed",
      expectedVersion: number,
    ) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `update argus_app.daily_ritual_assignments
              set state = $3,
                  revealed_at = case when $3 = 'revealed'
                    then coalesce(revealed_at, clock_timestamp()) else revealed_at end,
                  completed_at = case when $3 = 'completed'
                    then coalesce(completed_at, clock_timestamp()) else completed_at end,
                  version = version + 1
            where user_id = argus_private.request_user_id() and id = $1 and state = $2
              and version = $4
          returning *`,
          [assignmentId, from, to, expectedVersion],
        );
        if (result.rows.length !== 1) {
          throw new RepositoryRevisionConflictError();
        }
        return result.rows[0]!;
      }),
    getSchedule: (localDate: string, mode: "tarot" | "astrology") =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `select schedule.*, revision.payload
             from argus_app.ritual_schedules schedule
             join argus_app.editorial_revisions revision
               on revision.id = schedule.revision_id
            where schedule.local_date = $1 and schedule.mode = $2
              and schedule.audience = 'member' and schedule.state = 'active'`,
          [localDate, mode],
        );
        return result.rows[0] ?? null;
      }),
    getScenario: (revisionId: string) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `select * from argus_app.ritual_scenario_revisions
            where revision_id = $1`,
          [revisionId],
        );
        return result.rows[0] ?? null;
      }),
  });
}

export function createSupabaseSearchRepository(
  binding: SupabaseRepositoryBinding,
) {
  return Object.freeze({
    search: (query: string, limit: number) =>
      ownerTransaction(binding, async (database) =>
        (
          await database.query<JsonObject>(
            `select 'asset' as kind, asset.id, asset.slug, asset.name as label
               from argus_app.catalog_assets asset
              where asset.status = 'active'
                and (asset.name ilike '%' || $1 || '%'
                  or asset.symbol ilike '%' || $1 || '%')
             union all
             select item.kind, item.id, item.slug, item.slug as label
               from argus_app.editorial_items item
              where item.status = 'published' and item.slug ilike '%' || $1 || '%'
              order by label, id
              limit $2`,
            [query, limit],
          )
        ).rows,
      ),
  });
}

export function createSupabaseAdminRepository(
  binding: SupabaseRepositoryBinding,
) {
  const viewEditorialItem = async (
    database: DatabaseTransaction,
    itemId: string,
  ): Promise<JsonObject> =>
    first(
      (
        await database.query<JsonObject>(
          `select item.id,item.kind,item.slug,item.status,
                  revision.id as revision_id,revision.revision_number,
                  revision.edit_version as version,revision.state as revision_state,
                  '"v' || revision.edit_version || '"' as etag
             from argus_app.editorial_items item
             join lateral (
               select * from argus_app.editorial_revisions candidate
                where candidate.item_id=item.id
                order by candidate.revision_number desc,candidate.id desc
                limit 1
             ) revision on true
            where item.id=$1`,
          [itemId],
        )
      ).rows,
    );
  const auditEditorial = (
    database: DatabaseTransaction,
    action: string,
    itemId: string,
    outcome: "allowed" | "denied" | "failed",
    requestId: string,
    reasonCode: string | null = null,
  ) =>
    database.query(
      `insert into argus_private.admin_audit_events(
         actor_user_id,action,target_kind,target_id,outcome,reason_code,
         correlation_id,details
       ) values (
         argus_private.request_user_id(),$1,'editorial_item',$2,$3,$4,$5,'{}'::jsonb
       )`,
      [action, itemId, outcome, reasonCode, requestId],
    );

  return Object.freeze({
    getStaffPrincipal: () =>
      activeStaffTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `select user_id,display_label,permissions,revocation_epoch
             from argus_private.staff_principals
            where user_id = argus_private.request_user_id() and status = 'active'`,
        );
        return result.rows[0] ?? null;
      }),
    issueStepUp: (
      action: "admin_job_retry" | "admin_privacy_retry",
      targetId: string,
    ) =>
      staffTransaction(
        binding,
        action === "admin_job_retry" ? "operations:write" : "privacy:write",
        async (database) => {
        const receipt = `${crypto.randomUUID().replaceAll("-", "")}${crypto.randomUUID().replaceAll("-", "")}`;
        await database.query(
          `insert into argus_private.staff_step_up_receipts(
             user_id,session_id,action,target_id,receipt_hash,expires_at
           ) values (argus_private.request_user_id(),$1,$2,$3,$4,
                     clock_timestamp()+interval '5 minutes')`,
          [
            binding.claims.sessionId,
            action,
            targetId,
            await sha256TextHex(receipt),
          ],
        );
        return receipt;
        },
      ),
    listAudit: (limit: number) =>
      staffTransaction(binding, "audit:read", async (database) =>
        (
          await database.query<JsonObject>(
            `select id,actor_user_id,action,target_kind,target_id,outcome,
                    reason_code,correlation_id,occurred_at
               from argus_private.admin_audit_events
              order by occurred_at desc, id desc
              limit $1`,
            [limit],
          )
        ).rows,
      ),
    listEditorial: (limit: number, kind?: string) =>
      staffTransaction(binding, "editorial:read", async (database) =>
        (
          await database.query<JsonObject>(
            `select item.id,item.kind,item.slug,item.status,
                    revision.id as revision_id,revision.revision_number,
                    revision.edit_version as version,
                    revision.state as revision_state,
                    '"v' || revision.edit_version || '"' as etag
               from argus_app.editorial_items item
               join lateral (
                 select * from argus_app.editorial_revisions candidate
                  where candidate.item_id=item.id
                  order by candidate.revision_number desc,candidate.id desc
                  limit 1
               ) revision on true
              where ($2::text is null or item.kind=$2)
              order by item.created_at desc, item.id desc
              limit $1`,
            [limit, kind ?? null],
          )
        ).rows,
      ),
    getEditorial: (itemId: string) =>
      staffTransaction(binding, "editorial:read", async (database) => {
        const item = await viewEditorialItem(database, itemId);
        const revision = first(
          (
            await database.query<JsonObject>(
              `select id,revision_number,edit_version as version,state,
                      author_staff_id,content_hash,payload,created_at,
                      '"v' || edit_version || '"' as etag
                 from argus_app.editorial_revisions
                where item_id=$1
                order by revision_number desc,id desc limit 1`,
              [itemId],
            )
          ).rows,
        );
        return { ...item, revision };
      }),
    createEditorial: (
      kind: "ritual" | "asset_codex" | "coven" | "grimoire" |
        "circle_template" | "rowan" | "briefing_template",
      slug: string,
      payload: JsonObject,
      requestId: string,
    ) =>
      staffTransaction(binding, "editorial:write", async (database) => {
        const item = first(
          (
            await database.query<{ id: string }>(
              `insert into argus_app.editorial_items(kind,slug,status)
               values ($1,$2,'draft') returning id`,
              [kind, slug],
            )
          ).rows,
        );
        await database.query(
          `insert into argus_app.editorial_revisions(
             item_id,revision_number,state,author_staff_id,content_hash,payload
           ) values ($1,1,'draft',argus_private.request_user_id(),$2,$3::jsonb)`,
          [item.id, await sha256TextHex(JSON.stringify(payload)), JSON.stringify(payload)],
        );
        await database.query(
          `select argus_private.create_editorial_kind_link($1,$2,$3::jsonb)`,
          [kind, item.id, JSON.stringify(payload)],
        );
        await auditEditorial(database, "editorial.create", item.id, "allowed", requestId);
        return viewEditorialItem(database, item.id);
      }),
    createEditorialRevision: (
      itemId: string,
      payload: JsonObject,
      requestId: string,
    ) =>
      staffTransaction(binding, "editorial:write", async (database) => {
        const item = first(
          (
            await database.query<{ id: string }>(
              `select id from argus_app.editorial_items where id=$1 for update`,
              [itemId],
            )
          ).rows,
        );
        await database.query(
          `insert into argus_app.editorial_revisions(
             item_id,revision_number,state,author_staff_id,content_hash,payload
           ) select $1,coalesce(max(revision_number),0)+1,'draft',
                    argus_private.request_user_id(),$2,$3::jsonb
               from argus_app.editorial_revisions where item_id=$1`,
          [item.id, await sha256TextHex(JSON.stringify(payload)), JSON.stringify(payload)],
        );
        await auditEditorial(database, "editorial.revision.create", item.id, "allowed", requestId);
        return viewEditorialItem(database, item.id);
      }),
    patchEditorialRevision: (
      itemId: string,
      revisionId: string,
      expectedVersion: number,
      payload: JsonObject,
      requestId: string,
    ) =>
      staffTransaction(binding, "editorial:write", async (database) => {
        const result = await database.query<{ id: string }>(
          `update argus_app.editorial_revisions
              set payload=$1::jsonb,content_hash=$2,edit_version=edit_version+1
            where id=$3 and item_id=$4 and state='draft' and edit_version=$5
          returning id`,
          [
            JSON.stringify(payload),
            await sha256TextHex(JSON.stringify(payload)),
            revisionId,
            itemId,
            expectedVersion,
          ],
        );
        if (result.rows.length === 0) throw new RepositoryRevisionConflictError();
        await auditEditorial(database, "editorial.revision.patch", itemId, "allowed", requestId);
        return viewEditorialItem(database, itemId);
      }),
    commandEditorial: (
      action: "request_review" | "approve" | "changes_requested" | "publish" | "withdraw",
      itemId: string,
      revisionId: string | null,
      reason: string,
      highTrust: boolean,
      requestId: string,
    ) => {
      const permission = action === "publish" || action === "withdraw"
        ? "editorial:publish"
        : action === "approve" || action === "changes_requested"
        ? "editorial:review"
        : "editorial:write";
      return staffTransaction(binding, permission, async (database) => {
        if (action === "request_review") {
          const revision = first(
            (
              await database.query<{ id: string; kind: string; payload: JsonObject }>(
                `select revision.id,item.kind,revision.payload
                   from argus_app.editorial_revisions revision
                   join argus_app.editorial_items item on item.id=revision.item_id
                  where revision.id=$1 and revision.item_id=$2
                    and revision.state='draft'
                  for update of revision`,
                [revisionId, itemId],
              )
            ).rows,
          );
          await database.query(
            `select argus_private.materialize_editorial_revision($1,$2,$3::jsonb)`,
            [revision.kind, revision.id, JSON.stringify(revision.payload)],
          );
          await database.query(
            `update argus_app.editorial_revisions set state='submitted'
              where id=$1`,
            [revision.id],
          );
          await database.query(
            `insert into argus_app.editorial_review_requests(
               revision_id,requested_by,high_trust,status
             ) values (
               $1,argus_private.request_user_id(),
               ($2 or $3 in ('ritual','rowan')),'open'
             )`,
            [revision.id, highTrust, revision.kind],
          );
        } else if (action === "approve" || action === "changes_requested") {
          const request = first(
            (
              await database.query<{
                id: string;
                author_staff_id: string;
                high_trust: boolean;
              }>(
                `select review.id,revision.author_staff_id,review.high_trust
                   from argus_app.editorial_review_requests review
                   join argus_app.editorial_revisions revision on revision.id=review.revision_id
                  where review.revision_id=$1 and revision.item_id=$2
                    and review.status='open' and revision.state='submitted'
                  for update`,
                [revisionId, itemId],
              )
            ).rows,
          );
          if (
            request.high_trust === true &&
            request.author_staff_id === binding.claims.userId
          ) {
            await auditEditorial(database, "editorial.review.decision", itemId, "denied", requestId, "self_approval");
            return { _denied: "self_approval" };
          }
          const decision = action === "approve" ? "approved" : "changes_requested";
          await database.query(
            `insert into argus_app.editorial_review_decisions(
               request_id,reviewer_id,decision,reason
             ) values ($1,argus_private.request_user_id(),$2,$3)`,
            [request.id, decision, reason],
          );
          await database.query(
            `update argus_app.editorial_review_requests set status='closed' where id=$1`,
            [request.id],
          );
          await database.query(
            `update argus_app.editorial_revisions set state=$1 where id=$2`,
            [action === "approve" ? "approved" : "rejected", revisionId],
          );
        } else if (action === "publish") {
          first(
            (
              await database.query<{ id: string }>(
                `update argus_app.editorial_revisions set state='published'
                  where id=$1 and item_id=$2 and state='approved' returning id`,
                [revisionId, itemId],
              )
            ).rows,
          );
          await database.query(
            `update argus_app.editorial_items
                set status='published',current_published_revision_id=$1
              where id=$2`,
            [revisionId, itemId],
          );
          await database.query(
            `insert into argus_app.publication_events(
               item_id,revision_id,action,effective_at,actor_id,reason
             ) values ($1,$2,'publish',clock_timestamp(),argus_private.request_user_id(),$3)`,
            [itemId, revisionId, reason],
          );
        } else {
          const item = first(
            (
              await database.query<{ current_published_revision_id: string }>(
                `update argus_app.editorial_items set status='withdrawn'
                  where id=$1 and status='published'
                  returning current_published_revision_id`,
                [itemId],
              )
            ).rows,
          );
          await database.query(
            `update argus_app.editorial_revisions set state='withdrawn'
              where id=$1 and state='published'`,
            [item.current_published_revision_id],
          );
          await database.query(
            `insert into argus_app.publication_events(
               item_id,revision_id,action,effective_at,actor_id,reason
             ) values ($1,$2,'withdraw',clock_timestamp(),argus_private.request_user_id(),$3)`,
            [itemId, item.current_published_revision_id, reason],
          );
        }
        await auditEditorial(database, `editorial.${action}`, itemId, "allowed", requestId);
        return viewEditorialItem(database, itemId);
      }).then((result) => {
        if (result._denied === "self_approval") {
          throw new StaffAuthorizationError();
        }
        return result;
      });
    },
  });
}

export function createSupabaseAdminOperationsRepository(
  binding: SupabaseRepositoryBinding,
) {
  return Object.freeze({
    listJobs: (limit: number) =>
      staffTransaction(binding, "operations:read", async (database) =>
        (
          await database.query<JsonObject>(
            `select id as correlation_id,job_type,status,attempts,
                    next_attempt_at,last_error_code,created_at,updated_at
               from argus_private.job_runs
              order by created_at desc, id desc
              limit $1`,
            [limit],
          )
        ).rows,
      ),
    listPrivacy: (limit: number) =>
      staffTransaction(binding, "privacy:read", async (database) =>
        (
          await database.query<JsonObject>(
            `select id as correlation_id,request_type,status,requested_at,
                    completed_at,
                    case when failure_code is null then null
                         else 'privacy_failure_redacted' end as reason_code
               from argus_app.privacy_requests
              order by requested_at desc, id desc
              limit $1`,
            [limit],
          )
        ).rows,
      ),
    listAudit: (limit: number) =>
      staffTransaction(binding, "audit:read", async (database) =>
        (
          await database.query<JsonObject>(
            `select id,actor_user_id,action,target_kind,target_id,outcome,
                    reason_code,correlation_id,occurred_at
               from argus_private.admin_audit_events
              order by occurred_at desc, id desc
              limit $1`,
            [limit],
          )
        ).rows,
      ),
    listBrokerageDiagnostics: (limit: number) =>
      staffTransaction(binding, "brokerage:read", async (database) =>
        (
          await database.query<JsonObject>(
            `with diagnostics as (
               select connection.id,'connection_health'::text as kind,
                      connection.status,connection.last_error_code as reason_code,
                      connection.updated_at as observed_at
                 from argus_brokerage.connections connection
               union all
               select command.id,'provider_command'::text,command.state,
                      null::text,command.updated_at
                 from argus_private.provider_commands command
               union all
               select reconciliation.id,'reconciliation'::text,
                      reconciliation.status,reconciliation.last_error_code,
                      reconciliation.updated_at
                 from argus_private.reconciliation_records reconciliation
             )
             select argus_private.admin_diagnostic_correlation(
                      diagnostics.kind,diagnostics.id
                    ) as correlation_id,
                    diagnostics.kind,diagnostics.status,
                    case when diagnostics.reason_code is null then null
                         when diagnostics.reason_code ~ '^[a-z][a-z0-9_]{0,63}$'
                           then diagnostics.reason_code
                         else 'provider_error_redacted' end as reason_code,
                    diagnostics.observed_at
               from diagnostics
              order by diagnostics.observed_at desc,diagnostics.id desc
              limit $1`,
            [limit],
          )
        ).rows,
      ),
    requestJobRetry: (jobId: string, dedupeKey: string, receipt: string) =>
      staffTransaction(binding, "operations:write", async (database) => {
        const result = await database.query<{ outbox_id: string }>(
          `select argus_private.request_admin_job_retry($1,$2,$3,$4) as outbox_id`,
          [
            jobId,
            dedupeKey,
            await sha256TextHex(receipt),
            binding.claims.sessionId,
          ],
        );
        return first(result.rows).outbox_id;
      }).catch((error: unknown) => {
        if (error instanceof Error && error.message.includes("step_up_required")) {
          throw new RepositoryStepUpRequiredError();
        }
        throw error;
      }),
    requestPrivacyRetry: (
      requestId: string,
      dedupeKey: string,
      receipt: string,
    ) =>
      staffTransaction(binding, "privacy:write", async (database) => {
        const result = await database.query<{ outbox_id: string }>(
          `select argus_private.request_admin_privacy_retry($1,$2,$3,$4) as outbox_id`,
          [
            requestId,
            dedupeKey,
            await sha256TextHex(receipt),
            binding.claims.sessionId,
          ],
        );
        return first(result.rows).outbox_id;
      }).catch((error: unknown) => {
        if (error instanceof Error && error.message.includes("step_up_required")) {
          throw new RepositoryStepUpRequiredError();
        }
        throw error;
      }),
  });
}

export function createSupabasePublicPreviewRepository(pool: DatabasePool) {
  return Object.freeze({
    listPublished: (kind: string, limit: number) =>
      withAnonymousRequestTransaction(pool, async (database) =>
        (
          await database.query<JsonObject>(
            `select item.id, item.kind, item.slug, revision.id as revision_id,
                    revision.revision_number, revision.payload
               from argus_app.editorial_items item
               join argus_app.editorial_revisions revision
                 on revision.id = item.current_published_revision_id
              where item.status = 'published'
                and revision.state = 'published'
                and item.kind = $1
              order by item.slug, item.id
              limit $2`,
            [kind, limit],
          )
        ).rows,
      ),
    getPublished: (slug: string) =>
      withAnonymousRequestTransaction(pool, async (database) => {
        const result = await database.query<JsonObject>(
          `select item.id, item.kind, item.slug, revision.id as revision_id,
                  revision.revision_number, revision.payload
             from argus_app.editorial_items item
             join argus_app.editorial_revisions revision
               on revision.id = item.current_published_revision_id
            where item.status = 'published'
              and revision.state = 'published'
              and item.slug = $1`,
          [slug],
        );
        return result.rows[0] ?? null;
      }),
  });
}

export function createSupabaseAssetRepository(
  binding: SupabaseRepositoryBinding,
) {
  const publishedAssetSelect = `select asset.*,
      revision.id as revision_id,revision.created_at as revision_created_at,
      revision.payload,
      exists(select 1 from argus_app.saved_items saved
              where saved.user_id=argus_private.request_user_id()
                and saved.item_kind='asset' and saved.item_id=asset.id) as saved
    from argus_app.catalog_assets asset
    join lateral (
      select candidate.id,candidate.created_at,candidate.payload
        from argus_app.editorial_items item
        join argus_app.editorial_revisions candidate
          on candidate.id=item.current_published_revision_id
       where item.kind='asset_codex' and item.status='published'
         and candidate.state='published'
         and (item.slug=asset.slug or candidate.payload->>'asset_id'=asset.id::text)
       order by (candidate.payload->>'asset_id'=asset.id::text) desc
       limit 1
    ) revision on true`;
  return Object.freeze({
    list: (limit: number, assetType?: string, symbolPrefix?: string) =>
      ownerTransaction(binding, async (database) =>
        (
          await database.query<JsonObject>(
            `${publishedAssetSelect}
              where asset.status = 'active'
                and ($2::text is null or asset_type = $2)
                and ($3::text is null or symbol ilike $3 || '%')
              order by symbol, id
              limit $1`,
            [limit, assetType ?? null, symbolPrefix ?? null],
          )
        ).rows,
      ),
    get: (id: string) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `${publishedAssetSelect}
            where asset.id = $1 and asset.status = 'active'`,
          [id],
        );
        return result.rows[0] ?? null;
      }),
    listEvidence: (claimIds: readonly string[]) =>
      ownerTransaction(binding, (database) =>
        selectEvidence(database, claimIds),
      ),
    evidence: (assetId: string) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `select claim.*,to_jsonb(source) as source
             from argus_app.catalog_assets asset
             join argus_app.editorial_items item
               on item.kind='asset_codex' and item.status='published'
             join argus_app.editorial_revisions revision
               on revision.id=item.current_published_revision_id
              and revision.state='published'
             cross join lateral jsonb_array_elements_text(
               coalesce(revision.payload->'evidence_claim_ids','[]'::jsonb)
             ) claim_id
             join argus_app.evidence_claims claim on claim.id=claim_id::text::uuid
             join argus_app.evidence_sources source on source.id=claim.source_id
            where asset.id=$1 and asset.status='active'
              and (item.slug=asset.slug or revision.payload->>'asset_id'=asset.id::text)
              and claim.status='active' and source.status='active'
            order by claim.observed_at desc nulls last,claim.id`,
          [assetId],
        );
        return result.rows;
      }),
    metrics: (assetId: string) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `select metric.value as metric
             from argus_app.catalog_assets asset
             join argus_app.editorial_items item
               on item.kind='asset_codex' and item.status='published'
             join argus_app.editorial_revisions revision
               on revision.id=item.current_published_revision_id
              and revision.state='published'
             cross join lateral jsonb_array_elements(
               coalesce(revision.payload->'metrics','[]'::jsonb)
             ) metric(value)
            where asset.id=$1 and asset.status='active'
              and (item.slug=asset.slug or revision.payload->>'asset_id'=asset.id::text)
            limit 90`,
          [assetId],
        );
        return result.rows.map((row) => row.metric as JsonObject);
      }),
    compare: (assetIds: readonly string[]) =>
      ownerTransaction(binding, async (database) =>
        (
          await database.query<JsonObject>(
            `${publishedAssetSelect}
              where asset.id=any($1::uuid[]) and asset.status='active'
              order by array_position($1::uuid[],asset.id)`,
            [assetIds],
          )
        ).rows,
      ),
  });
}

export function createSupabaseCovenRepository(
  binding: SupabaseRepositoryBinding,
) {
  const select = `select coven.*, to_jsonb(company) as company,
                         asset.symbol,revision.id as revision_id,
                         revision.created_at as revision_created_at,
                         revision.payload, item.slug,
                         exists(select 1 from argus_app.saved_items saved
                           where saved.user_id=argus_private.request_user_id()
                             and saved.item_kind='coven' and saved.item_id=coven.id) as saved
                    from argus_app.coven_entries coven
                    join argus_app.companies company on company.id = coven.company_id
                    left join argus_app.catalog_assets asset on asset.id=company.asset_id
                    join argus_app.editorial_items item
                      on item.id = coven.editorial_item_id
                    join argus_app.editorial_revisions revision
                      on revision.id = item.current_published_revision_id
                   where item.status = 'published' and revision.state = 'published'`;
  return Object.freeze({
    list: (limit: number) =>
      ownerTransaction(binding, async (database) =>
        (await database.query<JsonObject>(`${select} order by item.slug limit $1`, [limit])).rows,
      ),
    get: (id: string) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `${select} and coven.id = $1`,
          [id],
        );
        return result.rows[0] ?? null;
      }),
  });
}

export function createSupabaseDiscoverRepository(
  binding: SupabaseRepositoryBinding,
) {
  return Object.freeze({
    listAssets: (limit: number) =>
      ownerTransaction(binding, async (database) =>
        (
          await database.query<JsonObject>(
            `select * from argus_app.catalog_assets
              where status = 'active' order by symbol, id limit $1`,
            [limit],
          )
        ).rows,
      ),
    listGrimoires: (limit: number, theme?: string) =>
      ownerTransaction(binding, async (database) =>
        (
          await database.query<JsonObject>(
            `select grimoire.*, item.slug,revision.id as revision_id,
                    revision.created_at as revision_created_at, revision.payload,
                    exists(select 1 from argus_app.saved_items saved
                      where saved.user_id=argus_private.request_user_id()
                        and saved.item_kind='grimoire' and saved.item_id=grimoire.id) as saved
               from argus_app.grimoires grimoire
               join argus_app.editorial_items item
                 on item.id = grimoire.editorial_item_id
               join argus_app.editorial_revisions revision
                 on revision.id = item.current_published_revision_id
              where item.status = 'published' and revision.state = 'published'
                and ($2::text is null or grimoire.theme_code = $2)
              order by item.slug limit $1`,
            [limit, theme ?? null],
          )
        ).rows,
      ),
    listCircleTemplates: (limit: number, creator?: string) =>
      ownerTransaction(binding, async (database) =>
        (
          await database.query<JsonObject>(
            `select template.*, item.slug,revision.id as revision_id,
                    revision.created_at as revision_created_at, revision.payload,
                    exists(select 1 from argus_app.saved_items saved
                      where saved.user_id=argus_private.request_user_id()
                        and saved.item_kind='circle_template' and saved.item_id=template.id) as saved
               from argus_app.community_templates template
               join argus_app.editorial_items item
                 on item.id = template.editorial_item_id
               join argus_app.editorial_revisions revision
                 on revision.id = item.current_published_revision_id
              where item.status = 'published' and revision.state = 'published'
                and ($2::text is null or template.creator_label = $2)
              order by item.slug limit $1`,
            [limit, creator ?? null],
          )
        ).rows,
      ),
    getGrimoire: (id: string) => ownerTransaction(binding, async (database) => {
      const result = await database.query<JsonObject>(
        `select grimoire.*,item.slug,revision.id as revision_id,
                revision.created_at as revision_created_at,revision.payload,
                exists(select 1 from argus_app.saved_items saved
                  where saved.user_id=argus_private.request_user_id()
                    and saved.item_kind='grimoire' and saved.item_id=grimoire.id) as saved,
                coalesce((select jsonb_agg(jsonb_build_object(
                  'id',asset.id,'slug',asset.slug,'symbol',asset.symbol,'name',asset.name,
                  'asset_type',asset.asset_type,'currency',asset.currency,
                  'revision_id',asset_revision.id,'revision_created_at',asset_revision.created_at,
                  'payload',asset_revision.payload
                ) order by entry.ordinal)
                  from unnest(grimoire.asset_ids) with ordinality entry(asset_id,ordinal)
                  join argus_app.catalog_assets asset on asset.id=entry.asset_id
                  left join lateral (
                    select r.id,r.created_at,r.payload from argus_app.editorial_items i
                    join argus_app.editorial_revisions r on r.id=i.current_published_revision_id
                    where i.kind='asset_codex' and (i.slug=asset.slug or r.payload->>'asset_id'=asset.id::text)
                    limit 1
                  ) asset_revision on true),'[]'::jsonb) as assets
           from argus_app.grimoires grimoire
           join argus_app.editorial_items item on item.id=grimoire.editorial_item_id
           join argus_app.editorial_revisions revision on revision.id=item.current_published_revision_id
          where grimoire.id=$1 and item.status='published' and revision.state='published'`,
        [id],
      );
      return result.rows[0] ?? null;
    }),
    listCreators: (limit: number) => ownerTransaction(binding, async (database) =>
      (
        await database.query<JsonObject>(
          `select distinct on (template.creator_label)
                  template.id,item.slug,template.creator_label,
                  revision.created_at as revision_created_at,revision.payload
             from argus_app.community_templates template
             join argus_app.editorial_items item on item.id=template.editorial_item_id
             join argus_app.editorial_revisions revision on revision.id=item.current_published_revision_id
            where item.status='published' and revision.state='published'
            order by template.creator_label,item.slug
            limit $1`,
          [limit],
        )
      ).rows,
    ),
  });
}

export function createSupabaseRowanRepository(
  binding: SupabaseRepositoryBinding,
) {
  return Object.freeze({
    resolve: (surface: string, contextKey: string) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `select script.id, script.script_key, binding.priority,
                  revision.body_template, revision.allowed_tokens,
                  revision.risk_footer
             from argus_app.rowan_context_bindings binding
             join argus_app.rowan_scripts script on script.id = binding.script_id
             join argus_app.editorial_items item
               on item.id = script.editorial_item_id
             join argus_app.rowan_script_revisions revision
               on revision.revision_id = item.current_published_revision_id
            where binding.surface = $1 and binding.context_key = $2
              and item.status = 'published'
            order by binding.priority
            limit 1`,
          [surface, contextKey],
        );
        return result.rows[0] ?? null;
      }),
  });
}
