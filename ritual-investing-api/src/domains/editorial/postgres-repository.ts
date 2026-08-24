import { Pool, type PoolClient } from "@neondatabase/serverless";

import { type DatabasePoolFactory, withScopedRuntimeClient } from "../../db/client.ts";
import { createRequestDatabaseContext } from "../../db/request-context.ts";
import {
  assetCodexDetailSchema,
  assetComparisonSchema,
  assetMetricSchema,
  assetSummarySchema,
  circleTemplateDetailSchema,
  circleTemplateSummarySchema,
  covenDetailSchema,
  covenSummarySchema,
  dailyRitualDetailSchema,
  dailyRitualPreviewSchema,
  discoverItemSchema,
  evidenceDetailSchema,
  grimoireDetailSchema,
  grimoireSummarySchema,
  publicCovenTeaserSchema,
  publicDiscoverItemSchema,
  rowanCounselSchema,
  seededCreatorSchema,
  type AssetCodexDetail,
  type AssetSummary,
  type CircleTemplateDetail,
  type CovenDetail,
  type DailyRitualDetail,
  type DiscoverItem,
  type GrimoireDetail,
} from "./schemas.ts";
import {
  ContentCursorStaleError,
  ContentInvalidStateError,
  ContentVersionConflictError,
  type MemberContentRepository,
  type MemberRequestContext,
  type PageRequest,
  type PageResult,
  type PublicContentRepository,
} from "./repository.ts";

async function withPublicClient<T>(
  databaseUrl: string,
  callback: (client: PoolClient) => Promise<T>,
  poolFactory: DatabasePoolFactory = (connectionString) => new Pool({ connectionString, max: 1 }),
): Promise<T> {
  const pool = poolFactory(databaseUrl);
  let client: PoolClient | undefined;
  try {
    client = await pool.connect();
    await client.query("begin read only");
    await client.query("set local role ritual_public");
    const result = await callback(client);
    await client.query("commit");
    return result;
  } catch (error) {
    await client?.query("rollback").catch(() => undefined);
    throw error;
  } finally {
    client?.release();
    await pool.end();
  }
}

async function withMemberClient<T>(
  databaseUrl: string,
  context: MemberRequestContext,
  callback: (client: PoolClient) => Promise<T>,
  poolFactory?: DatabasePoolFactory,
): Promise<T> {
  const databaseContext = createRequestDatabaseContext({
    accountId: context.accountId,
    tenantId: context.tenantId,
    principal: context.subject,
    revocationEpoch: context.revocationEpoch,
    accountStatus: context.accountStatus,
    tenantStatus: context.tenantStatus,
  });
  return withScopedRuntimeClient(databaseUrl, databaseContext, callback, poolFactory);
}

async function assertPosition(
  client: PoolClient,
  view: "ritual_public.discover_v1" | "ritual_public.coven_v1" | "ritual_catalog.assets_v1" | "ritual_catalog.coven_v1" | "ritual_catalog.discover_v1" | "ritual_catalog.grimoires_v1" | "ritual_catalog.creators_v1" | "ritual_catalog.circle_templates_v1" | "ritual_catalog.search_v1",
  after: string | undefined,
): Promise<void> {
  if (after === undefined) return;
  const result = await client.query(`select 1 from ${view} where sort_key = $1 limit 1`, [after]);
  if (result.rowCount !== 1) throw new ContentCursorStaleError();
}

function pageFromRows<T>(
  values: T[],
  limit: number,
  position: (value: T) => string,
): PageResult<T> {
  const hasMore = values.length > limit;
  const items = values.slice(0, limit);
  return {
    items,
    nextPosition: hasMore && items.length > 0 ? position(items[items.length - 1]!) : null,
  };
}

function summaryFromAsset(detail: AssetCodexDetail): AssetSummary {
  const { thesis: _thesis, risks: _risks, evidence: _evidence, metrics_as_of: _asOf, limitations: _limitations, saved: _saved, ...summary } = detail;
  return summary;
}

function summaryFromCoven(detail: CovenDetail) {
  const qualification = detail.qualifications[0]!;
  return covenSummarySchema.parse({
    id: detail.id,
    slug: detail.slug,
    company: detail.company,
    category: qualification.category,
    effective_date: qualification.effective_date,
    verified_as_of: qualification.verified_as_of,
    teaser: detail.summary,
    revision_id: detail.revision_id,
    demo: detail.demo,
  });
}

export function createPostgresPublicContentRepository(
  databaseUrl: string,
  poolFactory?: DatabasePoolFactory,
): PublicContentRepository {
  const publicClient = <T>(callback: (client: PoolClient) => Promise<T>) =>
    withPublicClient(databaseUrl, callback, poolFactory);
  return {
    async resolveDailyRevision(input) {
      return publicClient(async (client) => {
        const result = await client.query<{ revision_id: string }>(
          "select revision_id from ritual_public.daily_ritual_preview_v1 where local_date = $1 and mode = $2 limit 1",
          [input.date, input.mode],
        );
        return result.rows[0]?.revision_id ?? null;
      });
    },
    async loadDaily(input, revisionId) {
      return publicClient(async (client) => {
        const result = await client.query<{ payload: unknown }>(
          "select payload from ritual_public.daily_ritual_preview_v1 where local_date = $1 and mode = $2 and revision_id = $3 limit 1",
          [input.date, input.mode, revisionId],
        );
        return result.rows[0] === undefined ? null : dailyRitualPreviewSchema.parse(result.rows[0].payload);
      });
    },
    async resolveDiscoverRevision() {
      return publicClient(async (client) => {
        const result = await client.query<{ revision: string }>("select coalesce(md5(string_agg(revision_id::text, ',' order by revision_id)), 'empty') as revision from ritual_public.discover_v1");
        return result.rows[0]?.revision ?? "empty";
      });
    },
    async listDiscover(input, revisionId) {
      return publicClient(async (client) => {
        const current = await client.query<{ revision: string }>("select coalesce(md5(string_agg(revision_id::text, ',' order by revision_id)), 'empty') as revision from ritual_public.discover_v1");
        if (current.rows[0]?.revision !== revisionId) throw new ContentCursorStaleError();
        await assertPosition(client, "ritual_public.discover_v1", input.after);
        const result = await client.query<{ revision_id: string; sort_key: string; payload: unknown }>(
          "select revision_id, sort_key, payload from ritual_public.discover_v1 where ($1::text is null or sort_key > $1) order by sort_key, revision_id limit $2",
          [input.after ?? null, input.limit + 1],
        );
        return parsedPage(result.rows, input.limit, publicDiscoverItemSchema);
      });
    },
    async resolveCovenRevision(slug) {
      return publicClient(async (client) => {
        const result = await client.query<{ revision: string | null }>(
          `select case when count(*) = 0 then null else md5(string_agg(revision_id::text, ',' order by revision_id)) end as revision
           from ritual_public.coven_v1 where ($1::text is null or slug = $1)`,
          [slug ?? null],
        );
        return result.rows[0]?.revision ?? null;
      });
    },
    async listCoven(input, revisionId) {
      return publicClient(async (client) => {
        const current = await client.query<{ revision: string | null }>("select case when count(*) = 0 then null else md5(string_agg(revision_id::text, ',' order by revision_id)) end as revision from ritual_public.coven_v1");
        if (current.rows[0]?.revision !== revisionId) throw new ContentCursorStaleError();
        await assertPosition(client, "ritual_public.coven_v1", input.after);
        const result = await client.query<{ revision_id: string; sort_key: string; payload: unknown }>(
          "select revision_id, sort_key, payload from ritual_public.coven_v1 where ($1::text is null or sort_key > $1) and ($2::text is null or category = $2) order by sort_key, revision_id limit $3",
          [input.after ?? null, input.category ?? null, input.limit + 1],
        );
        return parsedPage(result.rows, input.limit, publicCovenTeaserSchema);
      });
    },
    async getCoven(slug, revisionId) {
      return publicClient(async (client) => {
        const current = await client.query<{ revision: string | null }>("select case when count(*) = 0 then null else md5(string_agg(revision_id::text, ',' order by revision_id)) end as revision from ritual_public.coven_v1 where slug = $1", [slug]);
        if (current.rows[0]?.revision !== revisionId) return null;
        const result = await client.query<{ payload: unknown }>(
          "select payload from ritual_public.coven_v1 where slug = $1 order by sort_key limit 1",
          [slug],
        );
        const row = result.rows[0];
        return row === undefined ? null : publicCovenTeaserSchema.parse(row.payload);
      });
    },
  };
}

export function createPostgresMemberContentRepository(
  databaseUrl: string,
  poolFactory?: DatabasePoolFactory,
): MemberContentRepository {
  const memberClient = <T>(context: MemberRequestContext, callback: (client: PoolClient) => Promise<T>) =>
    withMemberClient(databaseUrl, context, callback, poolFactory);
  const repository: MemberContentRepository = {
    async getOrCreateDaily(context, input) {
      return memberClient(context, async (client) => {
        const resolvedDate = input.date ?? (await client.query<{ local_date: string }>(
          `select to_char(clock_timestamp() at time zone preferences.timezone, 'YYYY-MM-DD') as local_date
           from preferences where tenant_id = $1`,
          [context.tenantId],
        )).rows[0]?.local_date;
        if (resolvedDate === undefined) return null;
        if (input.mode === "astrology") {
          const profile = await client.query<{ derived_profile_code: string }>(
            `select derived_profile_code from astrology_profiles
             where tenant_id = $1 and derived_profile_code = any($2::text[])`,
            [context.tenantId, ["lunar_patient", "solar_builder", "rising_explorer"]],
          );
          if (profile.rowCount !== 1) return null;
        }
        await client.query(
          `insert into daily_ritual_assignments(tenant_id, local_date, mode, schedule_id, revision_id, rowan_revision_id, state, version)
           select $1, $2, $3, schedule.id, schedule.revision_id, rowan.revision_id, 'assigned', 1
           from ritual_schedules schedule
           join editorial_revisions revision on revision.id = schedule.revision_id and revision.state = 'published'
           join editorial_items item on item.id = revision.item_id and item.current_published_revision_id = revision.id and item.status = 'published'
           cross join lateral (
             select script_revision.revision_id
             from rowan_context_bindings binding
             join rowan_scripts script on script.id = binding.script_id and script.surface = 'daily_ritual'
             join editorial_items script_item on script_item.id = script.editorial_item_id and script_item.status = 'published'
             join rowan_script_revisions script_revision on script_revision.revision_id = script_item.current_published_revision_id
             join editorial_revisions script_editorial on script_editorial.id = script_revision.revision_id and script_editorial.state = 'published'
             where binding.surface = 'daily_ritual' and binding.context_key = 'daily'
             order by binding.priority desc limit 1
           ) rowan
           where schedule.local_date = $2 and schedule.mode = $3 and schedule.audience = 'member' and schedule.state = 'active'
           on conflict (tenant_id, local_date, mode) do nothing`,
          [context.tenantId, resolvedDate, input.mode],
        );
        return loadAssignment(client, context.tenantId, { date: resolvedDate, mode: input.mode });
      });
    },
    async getAssignment(context, assignmentId) {
      return memberClient(context, (client) =>
        loadAssignment(client, context.tenantId, { assignmentId }));
    },
    async getAssignmentEvidence(context, assignmentId) {
      return memberClient(context, async (client) => {
        const assignment = await client.query<{ revision_id: string }>(
          "select revision_id from daily_ritual_assignments where tenant_id = $1 and id = $2",
          [context.tenantId, assignmentId],
        );
        const revision = assignment.rows[0];
        if (revision === undefined) return null;
        return loadEvidence(client, revision.revision_id);
      });
    },
    async transitionAssignment(context, assignmentId, transition, version) {
      return memberClient(context, async (client) => {
        const current = await loadAssignment(client, context.tenantId, { assignmentId });
        if (current === null) return null;
        if (transition === "reveal" && ["revealed", "completed"].includes(current.state)) return current;
        if (transition === "complete" && current.state === "completed") return current;
        if (current.version !== version) throw new ContentVersionConflictError();
        if (transition === "complete" && current.state === "assigned") throw new ContentInvalidStateError();
        const result = await client.query(
          `update daily_ritual_assignments
           set state = case when $3 = 'reveal' then 'revealed' else 'completed' end,
               revealed_at = coalesce(revealed_at, clock_timestamp()),
               completed_at = case when $3 = 'complete' then clock_timestamp() else completed_at end,
               version = version + 1
           where tenant_id = $1 and id = $2 and version = $4
             and (($3 = 'reveal' and state in ('assigned','revealed')) or ($3 = 'complete' and state = 'revealed'))
           returning id`,
          [context.tenantId, assignmentId, transition, version],
        );
        if (result.rowCount === 0) throw new ContentInvalidStateError();
        return loadAssignment(client, context.tenantId, { assignmentId });
      });
    },
    async listHistory(context, input) {
      return memberClient(context, async (client) => {
        if (input.after !== undefined) {
          const position = await client.query(
            "select 1 from daily_ritual_assignments where tenant_id = $1 and (local_date::text || '|' || id::text) = $2",
            [context.tenantId, input.after],
          );
          if (position.rowCount !== 1) throw new ContentCursorStaleError();
        }
        const result = await client.query<{ id: string; local_date: string; mode: "tarot" | "astrology" }>(
          `select id, local_date::text, mode from daily_ritual_assignments
           where tenant_id = $1 and ($2::text is null or mode = $2)
             and ($3::date is null or local_date >= $3) and ($4::date is null or local_date <= $4)
             and ($5::text is null or (local_date::text || '|' || id::text) < $5)
           order by local_date desc, id desc limit $6`,
          [context.tenantId, input.mode ?? null, input.from ?? null, input.to ?? null, input.after ?? null, input.limit + 1],
        );
        const values: Array<{ sortKey: string; value: DailyRitualDetail }> = [];
        for (const row of result.rows) {
          const detail = await loadAssignment(client, context.tenantId, { assignmentId: row.id });
          if (detail !== null) values.push({ sortKey: `${row.local_date}|${row.id}`, value: detail });
        }
        const page = pageFromRows(values, input.limit, (entry) => entry.sortKey);
        return { items: page.items.map((entry) => entry.value), nextPosition: page.nextPosition };
      });
    },
    async resolveRowan(context, input) {
      return memberClient(context, async (client) => {
        if (input.resourceId !== undefined) {
          const owned = input.surface === "daily_ritual" || input.surface === "evidence"
            ? await client.query("select 1 from daily_ritual_assignments where tenant_id = $1 and id = $2", [context.tenantId, input.resourceId])
            : input.surface === "asset_codex"
              ? await client.query("select 1 from ritual_catalog.assets_v1 where id = $1", [input.resourceId])
              : await client.query("select 1 from ritual_catalog.coven_v1 where id = $1", [input.resourceId]);
          if (owned.rowCount !== 1) return null;
        }
        const result = await client.query<{ payload: unknown }>(
          `select payload from ritual_catalog.rowan_v1
           where surface = $1 and context_key = $2
           order by priority desc limit 1`,
          [input.surface, input.contextCode],
        );
        const row = result.rows[0];
        return row === undefined ? null : rowanCounselSchema.parse(row.payload);
      });
    },
    async listAssets(context, input) {
      return memberClient(context, async (client) => {
        await assertPosition(client, "ritual_catalog.assets_v1", input.after);
        const result = await client.query<{ sort_key: string; payload: unknown }>(
          `select sort_key, payload from ritual_catalog.assets_v1
           where ($1::text is null or sort_key > $1)
             and ($2::text is null or asset_type = $2)
             and ($3::text is null or symbol like ($3 || '%'))
           order by sort_key limit $4`,
          [input.after ?? null, input.assetType ?? null, input.symbolPrefix?.toUpperCase() ?? null, input.limit + 1],
        );
        const values = result.rows.map((row) => ({ sortKey: row.sort_key, value: summaryFromAsset(assetCodexDetailSchema.parse(row.payload)) }));
        const page = pageFromRows(values, input.limit, (entry) => entry.sortKey);
        return { items: page.items.map((entry) => entry.value), nextPosition: page.nextPosition };
      });
    },
    async getAsset(context, id) {
      return memberClient(context, (client) => loadAsset(client, context.tenantId, id));
    },
    async getAssetEvidence(context, id) {
      return memberClient(context, async (client) => {
        const detail = await loadAsset(client, context.tenantId, id);
        if (detail === null) return null;
        const result = await client.query<{ payload: unknown }>(
          "select payload from ritual_catalog.asset_evidence_v1 where asset_id = $1 order by ordinal",
          [id],
        );
        return result.rows.map((row) => evidenceDetailSchema.parse(row.payload));
      });
    },
    async getAssetMetrics(context, id, asOf) {
      return memberClient(context, async (client) => {
        const exists = await client.query("select 1 from ritual_catalog.assets_v1 where id = $1", [id]);
        if (exists.rowCount !== 1) return null;
        const result = await client.query<{ payload: unknown }>(
          `select payload from ritual_catalog.asset_metrics_v1
           where asset_id = $1 and ($2::timestamptz is null or observed_at <= $2)
           order by observed_at desc limit 90`,
          [id, asOf ?? null],
        );
        return result.rows.map((row) => assetMetricSchema.parse(row.payload));
      });
    },
    async compareAssets(context, ids) {
      return memberClient(context, async (client) => {
        const entries = [];
        for (const id of ids) {
          const asset = await loadAsset(client, context.tenantId, id);
          if (asset === null) return null;
          const metric = await client.query<{ payload: unknown }>(
            "select payload from ritual_catalog.asset_metrics_v1 where asset_id = $1 order by observed_at desc limit 1",
            [id],
          );
          const latest = metric.rows[0];
          if (latest === undefined) return null;
          entries.push({ asset: summaryFromAsset(asset), latest_metric: assetMetricSchema.parse(latest.payload), risk_count: asset.risks.length });
        }
        const observed = entries.map((entry) => entry.latest_metric.observed_at).sort().at(-1)!;
        return assetComparisonSchema.parse({ assets: entries, compared_at: observed, demo: entries[0]!.asset.demo });
      });
    },
    async listMemberCoven(context, input) {
      return memberClient(context, async (client) => {
        await assertPosition(client, "ritual_catalog.coven_v1", input.after);
        const result = await client.query<{ sort_key: string; payload: unknown }>(
          `select sort_key, payload from ritual_catalog.coven_v1
           where ($1::text is null or sort_key > $1)
             and ($2::text is null or $2 = any(categories))
             and ($3::date is null or verified_as_of <= $3)
           order by sort_key limit $4`,
          [input.after ?? null, input.category ?? null, input.verifiedAsOf ?? null, input.limit + 1],
        );
        const values = result.rows.map((row) => ({ sortKey: row.sort_key, value: summaryFromCoven(covenDetailSchema.parse(row.payload)) }));
        const page = pageFromRows(values, input.limit, (entry) => entry.sortKey);
        return { items: page.items.map((entry) => entry.value), nextPosition: page.nextPosition };
      });
    },
    async getMemberCoven(context, id) {
      return memberClient(context, (client) => loadCoven(client, context.tenantId, id));
    },
    async getMemberCovenEvidence(context, id) {
      return memberClient(context, async (client) => {
        const detail = await loadCoven(client, context.tenantId, id);
        if (detail === null) return null;
        const result = await client.query<{ payload: unknown }>(
          "select payload from ritual_catalog.coven_evidence_v1 where entry_id = $1 order by ordinal",
          [id],
        );
        return result.rows.map((row) => evidenceDetailSchema.parse(row.payload));
      });
    },
    async listMemberDiscover(context, input) {
      return memberClient(context, async (client) => {
        const profile = await client.query<{ ritual_mode: string; risk_comfort: string }>(
          `select preferences.ritual_mode, investor_profiles.risk_comfort
           from preferences left join investor_profiles using (tenant_id)
           where preferences.tenant_id = $1`,
          [context.tenantId],
        );
        const ritualMode = ["tarot", "astrology"].includes(profile.rows[0]?.ritual_mode ?? "")
          ? profile.rows[0]!.ritual_mode
          : "tarot";
        const riskComfort = ["cautious", "balanced", "adventurous"].includes(profile.rows[0]?.risk_comfort ?? "")
          ? profile.rows[0]!.risk_comfort
          : "balanced";
        const preferredKind = riskComfort === "cautious"
          ? "grimoire"
          : riskComfort === "adventurous"
            ? "circle_template"
            : ritualMode === "astrology" ? "coven" : "asset";
        const personalizedView = `
          select kind, payload,
                 lpad((case when kind = $1 then 0 else 1 end)::text, 2, '0') || '|' || sort_key as page_sort
          from ritual_catalog.discover_v1
          where ($2::text is null or kind = $2)`;
        if (input.after !== undefined) {
          const position = await client.query(`select 1 from (${personalizedView}) personalized where page_sort = $3 limit 1`, [preferredKind, input.section ?? null, input.after]);
          if (position.rowCount !== 1) throw new ContentCursorStaleError();
        }
        const result = await client.query<{ sort_key: string; payload: unknown }>(
          `select page_sort as sort_key, payload from (${personalizedView}) personalized
           where ($3::text is null or page_sort > $3)
           order by page_sort limit $4`,
          [preferredKind, input.section ?? null, input.after ?? null, input.limit + 1],
        );
        return parsedPage(result.rows, input.limit, discoverItemSchema);
      });
    },
    async listGrimoires(context, input) {
      return memberClient(context, async (client) => {
        await assertPosition(client, "ritual_catalog.grimoires_v1", input.after);
        const result = await client.query<{ sort_key: string; payload: unknown }>(
          `select sort_key, payload from ritual_catalog.grimoires_v1
           where ($1::text is null or sort_key > $1) and ($2::text is null or theme = $2)
           order by sort_key limit $3`,
          [input.after ?? null, input.theme ?? null, input.limit + 1],
        );
        return parsedPage(result.rows, input.limit, grimoireSummarySchema);
      });
    },
    async getGrimoire(context, id) {
      return memberClient(context, async (client) => {
        const result = await client.query<{ payload: unknown }>("select detail_payload as payload from ritual_catalog.grimoires_v1 where id = $1", [id]);
        return result.rows[0] === undefined ? null : grimoireDetailSchema.parse(result.rows[0].payload);
      });
    },
    async listCreators(context, input) {
      return memberClient(context, async (client) => {
        await assertPosition(client, "ritual_catalog.creators_v1", input.after);
        const result = await client.query<{ sort_key: string; payload: unknown }>(
          "select sort_key, payload from ritual_catalog.creators_v1 where ($1::text is null or sort_key > $1) order by sort_key limit $2",
          [input.after ?? null, input.limit + 1],
        );
        return parsedPage(result.rows, input.limit, seededCreatorSchema);
      });
    },
    async listCircleTemplates(context, input) {
      return memberClient(context, async (client) => {
        await assertPosition(client, "ritual_catalog.circle_templates_v1", input.after);
        const result = await client.query<{ sort_key: string; payload: unknown }>(
          `select sort_key, payload from ritual_catalog.circle_templates_v1
           where ($1::text is null or sort_key > $1) and ($2::text is null or theme = $2) and ($3::text is null or creator_slug = $3)
           order by sort_key limit $4`,
          [input.after ?? null, input.theme ?? null, input.creator ?? null, input.limit + 1],
        );
        return parsedPage(result.rows, input.limit, circleTemplateSummarySchema);
      });
    },
    async getCircleTemplate(context, id) {
      return memberClient(context, async (client) => {
        const result = await client.query<{ payload: unknown }>("select detail_payload as payload from ritual_catalog.circle_templates_v1 where id = $1", [id]);
        return result.rows[0] === undefined ? null : circleTemplateDetailSchema.parse(result.rows[0].payload);
      });
    },
    async search(context, input) {
      return memberClient(context, async (client) => {
        await assertPosition(client, "ritual_catalog.search_v1", input.after);
        const result = await client.query<{ sort_key: string; payload: unknown }>(
          `select sort_key, payload from ritual_catalog.search_v1
           where ($1::text is null or sort_key > $1)
             and kind = any($2::text[])
             and search_document @@ plainto_tsquery('simple', $3)
           order by sort_key limit $4`,
          [input.after ?? null, input.kinds, input.query, input.limit + 1],
        );
        return parsedPage(result.rows, input.limit, discoverItemSchema);
      });
    },
  };
  return repository;
}

function parsedPage<T>(
  rows: Array<{ sort_key: string; payload: unknown }>,
  limit: number,
  schema: { parse(value: unknown): T },
): PageResult<T> {
  const values = rows.map((row) => ({ sortKey: row.sort_key, value: schema.parse(row.payload) }));
  const page = pageFromRows(values, limit, (entry) => entry.sortKey);
  return { items: page.items.map((entry) => entry.value), nextPosition: page.nextPosition };
}

async function loadAsset(client: PoolClient, tenantId: string, id: string): Promise<AssetCodexDetail | null> {
  const result = await client.query<{ payload: unknown }>(
    `select jsonb_set(payload, '{saved}', to_jsonb(exists(
       select 1 from saved_assets saved where saved.tenant_id = $1 and saved.asset_id = assets.id
     ))) as payload
     from ritual_catalog.assets_v1 assets where id = $2`,
    [tenantId, id],
  );
  return result.rows[0] === undefined ? null : assetCodexDetailSchema.parse(result.rows[0].payload);
}

async function loadCoven(client: PoolClient, tenantId: string, id: string): Promise<CovenDetail | null> {
  const result = await client.query<{ payload: unknown }>(
    `select jsonb_set(payload, '{saved}', to_jsonb(exists(
       select 1 from saved_coven_entries saved where saved.tenant_id = $1 and saved.entry_id = coven.id
     ))) as payload
     from ritual_catalog.coven_v1 coven where id = $2`,
    [tenantId, id],
  );
  return result.rows[0] === undefined ? null : covenDetailSchema.parse(result.rows[0].payload);
}

async function loadEvidence(client: PoolClient, revisionId: string) {
  const result = await client.query<{ payload: unknown }>(
    "select payload from ritual_catalog.ritual_evidence_v1 where revision_id = $1 order by ordinal",
    [revisionId],
  );
  return result.rows.map((row) => evidenceDetailSchema.parse(row.payload));
}

async function loadAssignment(
  client: PoolClient,
  tenantId: string,
  selector: { assignmentId: string } | { date: string; mode: "tarot" | "astrology" },
): Promise<DailyRitualDetail | null> {
  const byId = "assignmentId" in selector;
  const result = await client.query<{
    id: string;
    local_date: string;
    mode: "tarot" | "astrology";
    revision_id: string;
    state: "assigned" | "revealed" | "completed";
    version: number;
    revealed_at: Date | string | null;
    completed_at: Date | string | null;
    payload: Record<string, unknown>;
    rowan_payload: Record<string, unknown>;
  }>(
    `select assignment.id, assignment.local_date::text, assignment.mode, assignment.revision_id,
            assignment.state, assignment.version, assignment.revealed_at, assignment.completed_at,
            revision.payload, rowan.payload as rowan_payload
     from daily_ritual_assignments assignment
     join ritual_catalog.ritual_revisions_v1 revision on revision.revision_id = assignment.revision_id
     join ritual_catalog.rowan_revisions_v1 rowan on rowan.revision_id = assignment.rowan_revision_id
     where assignment.tenant_id = $1 and ${byId ? "assignment.id = $2" : "assignment.local_date = $2 and assignment.mode = $3"}
     limit 1`,
    byId ? [tenantId, selector.assignmentId] : [tenantId, selector.date, selector.mode],
  );
  const row = result.rows[0];
  if (row === undefined) return null;
  return dailyRitualDetailSchema.parse({
    ...row.payload,
    rowan: row.rowan_payload,
    assignment_id: row.id,
    date: row.local_date,
    mode: row.mode,
    state: row.state,
    version: Number(row.version),
    revealed_at: row.revealed_at === null ? null : new Date(row.revealed_at).toISOString(),
    completed_at: row.completed_at === null ? null : new Date(row.completed_at).toISOString(),
  });
}
