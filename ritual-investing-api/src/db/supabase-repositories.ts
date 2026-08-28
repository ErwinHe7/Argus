import type { DatabaseClient, DatabasePool } from "./database-port.ts";
import {
  type RequestTransactionConfig,
  withAnonymousRequestTransaction,
  withRequestTransaction,
  withStaffRequestTransaction,
} from "./request-transaction.ts";
import type { VerifiedRequestClaims } from "./request-context.ts";
import { supabaseSessionSnapshotSchema } from "../domains/session/supabase-schemas.ts";

export type JsonObject = Record<string, unknown>;

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
  briefings: ["argus_app.briefings", "argus_app.briefing_sections"],
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
    "argus_private.admin_audit_events",
    "argus_app.editorial_items",
  ],
  adminOperations: [
    "argus_private.job_runs",
    "argus_app.privacy_requests",
    "argus_private.admin_audit_events",
  ],
});

export type SupabaseRepositoryBinding = Readonly<{
  pool: DatabasePool;
  claims: VerifiedRequestClaims;
}>;

function config(binding: SupabaseRepositoryBinding): RequestTransactionConfig {
  return { pool: binding.pool, verifiedClaims: binding.claims };
}

function ownerTransaction<T>(
  binding: SupabaseRepositoryBinding,
  callback: (database: DatabaseClient) => Promise<T>,
): Promise<T> {
  return withRequestTransaction(config(binding), (database) =>
    callback(database),
  );
}

function staffTransaction<T>(
  binding: SupabaseRepositoryBinding,
  permission: string,
  callback: (database: DatabaseClient) => Promise<T>,
): Promise<T> {
  return withStaffRequestTransaction(config(binding), permission, (database) =>
    callback(database),
  );
}

function first<Row>(rows: Row[]): Row {
  const row = rows[0];
  if (row === undefined) throw new RepositoryNotFoundError();
  return row;
}

async function selectEvidence(
  database: DatabaseClient,
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
  return Object.freeze({
    bootstrap: () =>
      ownerTransaction(binding, async (database) => {
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
                  to_jsonb(astrology) as astrology_profile
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
  });
}

export function createSupabaseCircleRepository(
  binding: SupabaseRepositoryBinding,
) {
  const selectCircle = async (database: DatabaseClient, id: string) => {
    const result = await database.query<JsonObject>(
      `select circle.*,
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
            `select * from argus_app.circles
              where user_id = argus_private.request_user_id()
              order by archived_at nulls first, id
              limit $1`,
            [limit],
          )
        ).rows,
      ),
    get: (id: string) =>
      ownerTransaction(binding, (database) => selectCircle(database, id)),
    create: (input: Readonly<{ title: string; description: string }>) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `insert into argus_app.circles(
             user_id, deletion_epoch, title, description
           )
           select argus_private.request_user_id(), member.deletion_epoch, $1, $2
             from argus_app.members member
            where member.user_id = argus_private.request_user_id() and member.status = 'active'
          returning *`,
          [input.title, input.description],
        );
        return first(result.rows);
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
  return Object.freeze({
    list: (limit: number) =>
      ownerTransaction(binding, async (database) =>
        (
          await database.query<JsonObject>(
            `select * from argus_app.briefings
              where user_id = argus_private.request_user_id()
              order by period_end desc, id desc
              limit $1`,
            [limit],
          )
        ).rows,
      ),
    get: (id: string) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `select briefing.*,
                  coalesce(jsonb_agg(to_jsonb(section) order by section.ordinal)
                    filter (where section.id is not null), '[]'::jsonb) as sections
             from argus_app.briefings briefing
             left join argus_app.briefing_sections section
               on section.user_id = briefing.user_id
              and section.briefing_id = briefing.id
            where briefing.user_id = argus_private.request_user_id() and briefing.id = $1
            group by briefing.id`,
          [id],
        );
        return result.rows[0] ?? null;
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
            `select * from argus_app.notifications
              where user_id = argus_private.request_user_id()
              order by created_at desc, id desc
              limit $1`,
            [limit],
          )
        ).rows,
      ),
    markRead: (id: string) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `update argus_app.notifications
              set read_at = coalesce(read_at, clock_timestamp())
            where user_id = argus_private.request_user_id() and id = $1
          returning *`,
          [id],
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
        }>(
          `update argus_private.media_upload_intents
              set status = 'uploaded'
            where id = $1 and user_id = argus_private.request_user_id() and status = 'pending'
              and expires_at > clock_timestamp() and max_bytes >= $2
          returning bucket_id, object_path, mime_type, max_bytes`,
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
        return first(result.rows);
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
    ) =>
      ownerTransaction(binding, async (database) => {
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
          [request.id, `privacy.${requestType}.requested`, dedupeKey],
        );
        return request;
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
  });
}

export function createSupabaseRitualRepository(
  binding: SupabaseRepositoryBinding,
) {
  return Object.freeze({
    get: (assignmentId: string) =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `select assignment.*, revision.payload,
                  rowan.body_template, rowan.allowed_tokens, rowan.risk_footer
             from argus_app.daily_ritual_assignments assignment
             join argus_app.editorial_revisions revision
               on revision.id = assignment.revision_id
             left join argus_app.rowan_script_revisions rowan
               on rowan.revision_id = assignment.rowan_revision_id
            where assignment.user_id = argus_private.request_user_id() and assignment.id = $1`,
          [assignmentId],
        );
        return result.rows[0] ?? null;
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
  return Object.freeze({
    getStaffPrincipal: () =>
      ownerTransaction(binding, async (database) => {
        const result = await database.query<JsonObject>(
          `select * from argus_private.staff_principals
            where user_id = argus_private.request_user_id() and status = 'active'`,
        );
        return result.rows[0] ?? null;
      }),
    listAudit: (limit: number) =>
      staffTransaction(binding, "audit:read", async (database) =>
        (
          await database.query<JsonObject>(
            `select * from argus_private.admin_audit_events
              order by occurred_at desc, id desc
              limit $1`,
            [limit],
          )
        ).rows,
      ),
    listEditorial: (limit: number) =>
      staffTransaction(binding, "editorial:read", async (database) =>
        (
          await database.query<JsonObject>(
            `select item.*, revision.revision_number,
                    revision.state as revision_state, revision.payload
               from argus_app.editorial_items item
               left join argus_app.editorial_revisions revision
                 on revision.id = item.current_published_revision_id
              order by item.created_at desc, item.id desc
              limit $1`,
            [limit],
          )
        ).rows,
      ),
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
            `select * from argus_private.job_runs
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
            `select * from argus_app.privacy_requests
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
            `select * from argus_private.admin_audit_events
              order by occurred_at desc, id desc
              limit $1`,
            [limit],
          )
        ).rows,
      ),
    requestJobRetry: (jobId: string, dedupeKey: string) =>
      staffTransaction(binding, "operations:write", async (database) => {
        const result = await database.query<{ outbox_id: string }>(
          `select argus_private.request_admin_job_retry($1, $2) as outbox_id`,
          [jobId, dedupeKey],
        );
        return first(result.rows).outbox_id;
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
  return Object.freeze({
    list: (limit: number, assetType?: string, symbolPrefix?: string) =>
      ownerTransaction(binding, async (database) =>
        (
          await database.query<JsonObject>(
            `select * from argus_app.catalog_assets
              where status = 'active'
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
          `select * from argus_app.catalog_assets
            where id = $1 and status = 'active'`,
          [id],
        );
        return result.rows[0] ?? null;
      }),
    listEvidence: (claimIds: readonly string[]) =>
      ownerTransaction(binding, (database) =>
        selectEvidence(database, claimIds),
      ),
  });
}

export function createSupabaseCovenRepository(
  binding: SupabaseRepositoryBinding,
) {
  const select = `select coven.*, to_jsonb(company) as company,
                         revision.payload, item.slug
                    from argus_app.coven_entries coven
                    join argus_app.companies company on company.id = coven.company_id
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
            `select grimoire.*, item.slug, revision.payload
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
            `select template.*, item.slug, revision.payload
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
