import type { PoolClient } from "@neondatabase/serverless";

import { withScopedRuntimeClient } from "../../db/client.ts";
import { createRequestDatabaseContext } from "../../db/request-context.ts";
import type { ResolvedAccountContext } from "../../db/client.ts";
import { InvalidCursorError } from "../editorial/cursor.ts";
import type {
  AccountView,
  AstrologyProfile,
  ConsentRequest,
  InvestorProfile,
  OnboardingView,
  PreferencesView,
} from "./schemas.ts";

export type MemberContext = ResolvedAccountContext & { subject: string };
export type CircleAssetInput = {
  asset_id: string;
  ordinal: number;
  weight_bps?: number;
  note?: string;
};
export type CircleView = {
  id: string;
  title: string;
  description: string;
  private: true;
  source_template_id: string | null;
  source_revision_id: string | null;
  assets: CircleAssetInput[];
  version: number;
  archived_at: string | null;
};
export type CirclePage = { items: CircleView[]; nextPosition: string | null };

export interface MemberRepository {
  getAccount(context: MemberContext): Promise<AccountView>;
  patchProfile(
    context: MemberContext,
    patch: Record<string, unknown>,
    version: number,
  ): Promise<AccountView>;
  getPreferences(context: MemberContext): Promise<PreferencesView>;
  patchPreferences(
    context: MemberContext,
    patch: Record<string, unknown>,
    version: number,
  ): Promise<PreferencesView>;
  getOnboarding(context: MemberContext): Promise<OnboardingView>;
  patchOnboarding(
    context: MemberContext,
    patch: Record<string, unknown>,
    version: number,
  ): Promise<OnboardingView>;
  getAstrologyProfile(context: MemberContext): Promise<AstrologyProfile | null>;
  putAstrologyProfile(
    context: MemberContext,
    input: Record<string, unknown>,
    version?: number,
  ): Promise<AstrologyProfile>;
  deleteAstrologyProfile(
    context: MemberContext,
    version?: number,
  ): Promise<void>;
  getInvestorProfile(context: MemberContext): Promise<InvestorProfile | null>;
  putInvestorProfile(
    context: MemberContext,
    input: Record<string, unknown>,
    version?: number,
  ): Promise<InvestorProfile>;
  createConsent(
    context: MemberContext,
    input: ConsentRequest,
  ): Promise<Record<string, unknown>>;
  listCircles(
    context: MemberContext,
    input: {
      archived: "exclude" | "include" | "only";
      limit: number;
      after?: string;
    },
  ): Promise<CirclePage>;
  createCircle(
    context: MemberContext,
    input: Record<string, unknown>,
    idempotencyKey: string,
  ): Promise<CircleView>;
  copyTemplate(
    context: MemberContext,
    templateId: string,
    idempotencyKey: string,
    input: Record<string, unknown>,
  ): Promise<CircleView>;
  getCircle(
    context: MemberContext,
    circleId: string,
  ): Promise<CircleView | null>;
  patchCircle(
    context: MemberContext,
    circleId: string,
    patch: Record<string, unknown>,
    version: number,
  ): Promise<CircleView | null>;
  archiveCircle(
    context: MemberContext,
    circleId: string,
    version: number,
  ): Promise<boolean>;
  putCircleAsset(
    context: MemberContext,
    circleId: string,
    assetId: string,
    input: CircleAssetInput,
    version: number,
  ): Promise<CircleView | null>;
  deleteCircleAsset(
    context: MemberContext,
    circleId: string,
    assetId: string,
    version: number,
  ): Promise<CircleView | null>;
  save(
    context: MemberContext,
    kind: string,
    id: string,
    input: Record<string, unknown>,
  ): Promise<Record<string, unknown>>;
  unsave(context: MemberContext, kind: string, id: string): Promise<void>;
}

export class VersionConflictError extends Error {
  constructor() {
    super("version_conflict");
  }
}
export class InvalidTransitionError extends Error {
  constructor() {
    super("invalid_transition");
  }
}
export class InvalidChildError extends Error {
  constructor() {
    super("invalid_child");
  }
}
export class MemberInputError extends Error {
  readonly code: string;
  constructor(code: string) {
    super(code);
    this.code = code;
  }
}
export class IdempotencyConflictError extends Error {
  constructor() {
    super("idempotency_conflict");
  }
}

function scoped<T>(
  url: string,
  context: MemberContext,
  callback: (client: PoolClient) => Promise<T>,
) {
  return withScopedRuntimeClient(
    url,
    createRequestDatabaseContext({
      accountId: context.accountId,
      tenantId: context.tenantId,
      accountStatus: context.accountStatus,
      tenantStatus: context.tenantStatus,
      revocationEpoch: context.revocationEpoch,
      principal: context.subject,
    }),
    callback,
  );
}

function iso(value: Date | string | null): string | null {
  return value === null ? null : new Date(value).toISOString();
}

export function createPostgresMemberRepository(url: string): MemberRepository {
  const circle = async (
    client: PoolClient,
    tenantId: string,
    id: string,
  ): Promise<CircleView | null> => {
    const result = await client.query(
      `select c.id,c.title,c.description,c.source_template_id,c.source_revision_id,c.version,c.archived_at,
      coalesce(json_agg(json_build_object('asset_id',a.asset_id,'ordinal',a.ordinal,'weight_bps',a.weight_bps,'note',a.note) order by a.ordinal) filter (where a.id is not null),'[]') assets
      from circles c left join circle_assets a on a.tenant_id=c.tenant_id and a.circle_id=c.id
      where c.tenant_id=$1 and c.id=$2 group by c.id`,
      [tenantId, id],
    );
    const row = result.rows[0];
    return row === undefined
      ? null
      : {
          ...row,
          private: true,
          version: Number(row.version),
          archived_at: iso(row.archived_at),
        };
  };
  return {
    getAccount: (c) =>
      scoped(url, c, async (db) => {
        const r = await db.query(
          `select a.id,a.status,p.display_name,p.locale,p.version from accounts a join profiles p on p.tenant_id=a.tenant_id where a.tenant_id=$1 and a.id=$2`,
          [c.tenantId, c.accountId],
        );
        const x = r.rows[0];
        return {
          account: { id: x.id, status: x.status },
          profile: {
            display_name: x.display_name,
            locale: x.locale,
            version: Number(x.version),
          },
        };
      }),
    patchProfile: (c, p, v) =>
      scoped(url, c, async (db) => {
        const r = await db.query(
          `update profiles set display_name=coalesce($3,display_name),locale=coalesce($4,locale),version=version+1 where tenant_id=$1 and version=$2 returning display_name,locale,version`,
          [c.tenantId, v, p.display_name ?? null, p.locale ?? null],
        );
        if (!r.rowCount) throw new VersionConflictError();
        return {
          account: { id: c.accountId, status: "active" },
          profile: { ...r.rows[0], version: Number(r.rows[0].version) },
        };
      }),
    getPreferences: (c) =>
      scoped(url, c, async (db) => {
        const x = (
          await db.query(
            "select theme_mode,ritual_mode,timezone,locale,version from preferences where tenant_id=$1",
            [c.tenantId],
          )
        ).rows[0];
        return { ...x, version: Number(x.version) };
      }),
    patchPreferences: (c, p, v) =>
      scoped(url, c, async (db) => {
        const r = await db.query(
          `update preferences set theme_mode=coalesce($3,theme_mode),ritual_mode=coalesce($4,ritual_mode),timezone=coalesce($5,timezone),locale=coalesce($6,locale),version=version+1 where tenant_id=$1 and version=$2 returning theme_mode,ritual_mode,timezone,locale,version`,
          [
            c.tenantId,
            v,
            p.theme_mode ?? null,
            p.ritual_mode ?? null,
            p.timezone ?? null,
            p.locale ?? null,
          ],
        );
        if (!r.rowCount) throw new VersionConflictError();
        return { ...r.rows[0], version: Number(r.rows[0].version) };
      }),
    getOnboarding: (c) =>
      scoped(url, c, async (db) => {
        const x = (
          await db.query(
            "select current_step,completed_steps,completed_at,version from onboarding_states where tenant_id=$1",
            [c.tenantId],
          )
        ).rows[0];
        return {
          ...x,
          completed_at: iso(x.completed_at),
          version: Number(x.version),
        };
      }),
    patchOnboarding: (c, p, v) =>
      scoped(url, c, async (db) => {
        try {
          const r = await db.query(
            "select * from ritual_private.advance_onboarding($1,$2,$3,$4)",
            [c.tenantId, v, p.current_step, p.completed_steps],
          );
          const x = r.rows[0];
          return {
            ...x,
            completed_at: iso(x.completed_at),
            version: Number(x.version),
          };
        } catch (error) {
          const message = error instanceof Error ? error.message : "";
          if (message.includes("version_conflict"))
            throw new VersionConflictError();
          if (message.includes("invalid_transition"))
            throw new InvalidTransitionError();
          throw error;
        }
      }),
    getAstrologyProfile: (c) =>
      scoped(url, c, async (db) => {
        const x = (
          await db.query(
            "select birth_date,derived_profile_code,algorithm_version,enabled_at,version from astrology_profiles where tenant_id=$1",
            [c.tenantId],
          )
        ).rows[0];
        return x === undefined
          ? null
          : {
              ...x,
              birth_date: String(x.birth_date),
              enabled_at: iso(x.enabled_at)!,
              version: Number(x.version),
            };
      }),
    putAstrologyProfile: (c, p, v) =>
      scoped(url, c, async (db) => {
        const r =
          v === undefined
            ? await db.query(
                `insert into astrology_profiles(tenant_id,birth_date,derived_profile_code,algorithm_version,version) values($1,$2,$3,$4,1) on conflict(tenant_id) do nothing returning birth_date,derived_profile_code,algorithm_version,enabled_at,version`,
                [
                  c.tenantId,
                  p.birth_date,
                  p.derived_profile_code,
                  p.algorithm_version,
                ],
              )
            : await db.query(
                `update astrology_profiles set birth_date=$3,derived_profile_code=$4,algorithm_version=$5,enabled_at=now(),version=version+1 where tenant_id=$1 and version=$2 returning birth_date,derived_profile_code,algorithm_version,enabled_at,version`,
                [
                  c.tenantId,
                  v,
                  p.birth_date,
                  p.derived_profile_code,
                  p.algorithm_version,
                ],
              );
        if (!r.rowCount) throw new VersionConflictError();
        const x = r.rows[0];
        return {
          ...x,
          birth_date: String(x.birth_date),
          enabled_at: iso(x.enabled_at)!,
          version: Number(x.version),
        };
      }),
    deleteAstrologyProfile: (c, v) =>
      scoped(url, c, async (db) => {
        if (v === undefined) {
          const exists = await db.query(
            "select 1 from astrology_profiles where tenant_id=$1",
            [c.tenantId],
          );
          if (!exists.rowCount) return;
          throw new VersionConflictError();
        }
        const r = await db.query(
          "delete from astrology_profiles where tenant_id=$1 and version=$2",
          [c.tenantId, v],
        );
        if (!r.rowCount) {
          const exists = await db.query(
            "select 1 from astrology_profiles where tenant_id=$1",
            [c.tenantId],
          );
          if (exists.rowCount) throw new VersionConflictError();
        }
      }),
    getInvestorProfile: (c) =>
      scoped(url, c, async (db) => {
        const x = (
          await db.query(
            "select goal_type,time_horizon,risk_comfort,version from investor_profiles where tenant_id=$1",
            [c.tenantId],
          )
        ).rows[0];
        return x === undefined
          ? null
          : { ...x, version: Number(x.version), is_demo: true };
      }),
    putInvestorProfile: (c, p, v) =>
      scoped(url, c, async (db) => {
        const r =
          v === undefined
            ? await db.query(
                `insert into investor_profiles(tenant_id,goal_type,time_horizon,risk_comfort,version) values($1,$2,$3,$4,1) on conflict(tenant_id) do nothing returning goal_type,time_horizon,risk_comfort,version`,
                [c.tenantId, p.goal_type, p.time_horizon, p.risk_comfort],
              )
            : await db.query(
                `update investor_profiles set goal_type=$3,time_horizon=$4,risk_comfort=$5,version=version+1 where tenant_id=$1 and version=$2 returning goal_type,time_horizon,risk_comfort,version`,
                [c.tenantId, v, p.goal_type, p.time_horizon, p.risk_comfort],
              );
        if (!r.rowCount) throw new VersionConflictError();
        return {
          ...r.rows[0],
          version: Number(r.rows[0].version),
          is_demo: true,
        };
      }),
    createConsent: (c, p) =>
      scoped(url, c, async (db) => {
        const inserted = await db.query(
          `insert into consent_records(tenant_id,policy_code,policy_version,decision) values($1,$2,$3,$4) on conflict(tenant_id,policy_code,policy_version,decision) do nothing returning id,policy_code,policy_version,decision,recorded_at`,
          [c.tenantId, p.policy_code, p.policy_version, p.decision],
        );
        const row =
          inserted.rows[0] ??
          (
            await db.query(
              `select id,policy_code,policy_version,decision,recorded_at from consent_records where tenant_id=$1 and policy_code=$2 and policy_version=$3 and decision=$4`,
              [c.tenantId, p.policy_code, p.policy_version, p.decision],
            )
          ).rows[0];
        return { ...row, recorded_at: iso(row.recorded_at) };
      }),
    listCircles: (c, input) =>
      scoped(url, c, async (db) => {
        if (input.after !== undefined) {
          if (
            !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
              input.after,
            )
          )
            throw new InvalidCursorError();
          const anchor = await db.query(
            `select 1 from circles where tenant_id=$1 and id=$2 and ($3='include' or ($3='exclude' and archived_at is null) or ($3='only' and archived_at is not null))`,
            [c.tenantId, input.after, input.archived],
          );
          if (!anchor.rowCount) throw new InvalidCursorError();
        }
        const result = await db.query(
          `select c.id,c.title,c.description,c.source_template_id,c.source_revision_id,c.version,c.archived_at,
        coalesce(json_agg(json_build_object('asset_id',a.asset_id,'ordinal',a.ordinal,'weight_bps',a.weight_bps,'note',a.note) order by a.ordinal) filter (where a.id is not null),'[]') assets
        from circles c left join circle_assets a on a.tenant_id=c.tenant_id and a.circle_id=c.id
        where c.tenant_id=$1 and ($2='include' or ($2='exclude' and c.archived_at is null) or ($2='only' and c.archived_at is not null))
          and ($3::uuid is null or c.id>$3)
        group by c.id order by c.id limit $4`,
          [c.tenantId, input.archived, input.after ?? null, input.limit + 1],
        );
        const hasMore = result.rows.length > input.limit;
        const rows = hasMore ? result.rows.slice(0, input.limit) : result.rows;
        const items = rows.map((row) => ({
          ...row,
          private: true as const,
          version: Number(row.version),
          archived_at: iso(row.archived_at),
        }));
        return {
          items,
          nextPosition: hasMore ? String(items.at(-1)!.id) : null,
        };
      }),
    createCircle: (c, p, key) =>
      scoped(url, c, async (db) => {
        try {
          const r = await db.query(
            "select circle_id from ritual_private.create_circle($1,$2,$3,$4,$5)",
            [
              c.tenantId,
              key,
              p.title,
              p.description ?? "",
              JSON.stringify(p.assets ?? []),
            ],
          );
          const createdId = r.rows[0]?.circle_id;
          if (createdId === undefined) throw new InvalidChildError();
          const created = await circle(db, c.tenantId, createdId);
          if (created === null) throw new InvalidChildError();
          return created;
        } catch (error) {
          const message = error instanceof Error ? error.message : "";
          if (message.includes("idempotency_conflict"))
            throw new IdempotencyConflictError();
          if (message.includes("invalid_child")) throw new InvalidChildError();
          if (
            message.includes("invalid_weight_total") ||
            message.includes("asset_cap") ||
            message.includes("duplicate_asset") ||
            message.includes("duplicate_ordinal")
          )
            throw new MemberInputError(message);
          throw error;
        }
      }),
    copyTemplate: (c, id, key, p) =>
      scoped(url, c, async (db) => {
        try {
          const r = await db.query(
            "select circle_id from ritual_private.copy_circle_template($1,$2,$3,$4)",
            [c.tenantId, id, key, p.title ?? null],
          );
          const copiedId = r.rows[0]?.circle_id;
          if (copiedId === undefined) throw new InvalidChildError();
          const copied = await circle(db, c.tenantId, copiedId);
          if (copied === null) throw new InvalidChildError();
          return copied;
        } catch (error) {
          const message = error instanceof Error ? error.message : "";
          if (message.includes("idempotency_conflict"))
            throw new IdempotencyConflictError();
          if (
            message.includes("invalid_weight_total") ||
            message.includes("asset_cap") ||
            message.includes("duplicate_asset") ||
            message.includes("duplicate_ordinal")
          )
            throw new MemberInputError(message);
          throw error;
        }
      }),
    getCircle: (c, id) => scoped(url, c, (db) => circle(db, c.tenantId, id)),
    patchCircle: (c, id, p, v) =>
      scoped(url, c, async (db) => {
        const r = await db.query(
          "update circles set title=coalesce($4,title),description=coalesce($5,description),version=version+1 where tenant_id=$1 and id=$2 and version=$3 returning id",
          [c.tenantId, id, v, p.title ?? null, p.description ?? null],
        );
        if (!r.rowCount) {
          if (
            (
              await db.query(
                "select 1 from circles where tenant_id=$1 and id=$2",
                [c.tenantId, id],
              )
            ).rowCount
          )
            throw new VersionConflictError();
          return null;
        }
        return circle(db, c.tenantId, id);
      }),
    archiveCircle: (c, id, v) =>
      scoped(url, c, async (db) => {
        const r = await db.query(
          "update circles set archived_at=now(),version=version+1 where tenant_id=$1 and id=$2 and version=$3",
          [c.tenantId, id, v],
        );
        if (
          !r.rowCount &&
          (
            await db.query(
              "select 1 from circles where tenant_id=$1 and id=$2",
              [c.tenantId, id],
            )
          ).rowCount
        )
          throw new VersionConflictError();
        return r.rowCount === 1;
      }),
    putCircleAsset: (c, id, asset, input, v) =>
      scoped(url, c, async (db) => {
        try {
          const r = await db.query(
            "select ok from ritual_private.put_circle_asset($1,$2,$3,$4,$5,$6,$7)",
            [
              c.tenantId,
              id,
              asset,
              v,
              input.ordinal,
              input.weight_bps ?? null,
              input.note ?? null,
            ],
          );
          return !r.rowCount ? null : circle(db, c.tenantId, id);
        } catch (error) {
          const message = error instanceof Error ? error.message : "";
          if (message.includes("version_conflict"))
            throw new VersionConflictError();
          if (
            message.includes("invalid_weight_total") ||
            message.includes("asset_cap") ||
            message.includes("duplicate_ordinal")
          )
            throw new MemberInputError(message);
          throw error;
        }
      }),
    deleteCircleAsset: (c, id, asset, v) =>
      scoped(url, c, async (db) => {
        try {
          const r = await db.query(
            "select ok from ritual_private.delete_circle_asset($1,$2,$3,$4)",
            [c.tenantId, id, asset, v],
          );
          return !r.rowCount ? null : circle(db, c.tenantId, id);
        } catch (error) {
          const message = error instanceof Error ? error.message : "";
          if (message.includes("version_conflict"))
            throw new VersionConflictError();
          if (message.includes("invalid_weight_total"))
            throw new MemberInputError(message);
          throw error;
        }
      }),
    save: (c, kind, id, p) =>
      scoped(url, c, async (db) => {
        const r = await db.query(
          "select * from ritual_private.save_member_item($1,$2,$3,$4)",
          [c.tenantId, kind, id, JSON.stringify(p)],
        );
        if (!r.rowCount) throw new InvalidChildError();
        return { ...r.rows[0], saved_at: iso(r.rows[0].saved_at) };
      }),
    unsave: (c, kind, id) =>
      scoped(url, c, async (db) => {
        await db.query("select ritual_private.unsave_member_item($1,$2,$3)", [
          c.tenantId,
          kind,
          id,
        ]);
      }),
  };
}
