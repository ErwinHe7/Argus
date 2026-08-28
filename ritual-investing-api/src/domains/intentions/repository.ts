import type { DatabaseClient } from "../../db/database-port.ts";
import type { VerifiedRequestClaims } from "../../db/request-context.ts";
import {
  RepositoryNotFoundError,
  RepositoryRevisionConflictError,
  type SupabaseRepositoryBinding,
} from "../../db/supabase-repositories.ts";
import { withRequestTransaction } from "../../db/request-transaction.ts";
import {
  type FutureMirror,
  type FutureMirrorInput,
  type FutureMirrorPoint,
  type IntentionCreateInput,
  type IntentionPatchInput,
  type MemberIntention,
  futureMirrorInputSchema,
  futureMirrorSchema,
  intentionCreateSchema,
  intentionPatchSchema,
  intentionSchema,
} from "./schemas.ts";

const MODEL_VERSION = "argus-hypothetical-v1";
const ASSUMPTION_VERSION = "member-reviewed-v1";
const UNCERTAINTY_DISCLOSURE =
  "This is a hypothetical scenario based only on the assumptions you entered. It is not advice, a forecast, or a view of any brokerage account.";
const MONTHLY_BPS_DENOMINATOR = 120_000n;
const POSTGRES_BIGINT_MAX = 9_223_372_036_854_775_807n;

export class ScenarioConflictError extends Error {
  readonly code: "idempotency_conflict" | "invalid_scenario_input" |
    "invalid_scenario_horizon" |
    "scenario_value_too_large";

  constructor(code: ScenarioConflictError["code"]) {
    super(code);
    this.name = "ScenarioConflictError";
    this.code = code;
  }
}

type ProjectionInput = FutureMirrorInput & Readonly<{ targetDate: string }>;

function parseDateOnly(value: string): Date {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (match === null) throw new ScenarioConflictError("invalid_scenario_horizon");
  const date = new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])));
  if (date.toISOString().slice(0, 10) !== value) {
    throw new ScenarioConflictError("invalid_scenario_horizon");
  }
  return date;
}

function dateOnly(value: Date): string {
  return value.toISOString().slice(0, 10);
}

function addMonthClamped(value: Date, count: number): Date {
  const first = new Date(Date.UTC(
    value.getUTCFullYear(),
    value.getUTCMonth() + count,
    1,
  ));
  const lastDay = new Date(Date.UTC(
    first.getUTCFullYear(),
    first.getUTCMonth() + 1,
    0,
  )).getUTCDate();
  return new Date(Date.UTC(
    first.getUTCFullYear(),
    first.getUTCMonth(),
    Math.min(value.getUTCDate(), lastDay),
  ));
}

function compoundMonth(value: bigint, contribution: bigint, bps: number): bigint {
  const numerator = MONTHLY_BPS_DENOMINATOR + BigInt(bps);
  const result = ((value + contribution) * numerator) /
    MONTHLY_BPS_DENOMINATOR;
  if (result < 0n || result > POSTGRES_BIGINT_MAX) {
    throw new ScenarioConflictError("scenario_value_too_large");
  }
  return result;
}

/**
 * Deterministic hypothetical projection. Each monthly step adds the reviewed
 * contribution, applies the annual basis-point band divided by twelve, and
 * rounds down to the next whole minor unit. No floating financial math is used.
 */
export function createHypotheticalProjection(
  raw: ProjectionInput,
): FutureMirrorPoint[] {
  const { targetDate, ...reviewedInput } = raw;
  const input = futureMirrorInputSchema.parse(reviewedInput);
  const asOf = parseDateOnly(input.as_of_date);
  const target = parseDateOnly(targetDate);
  if (target.getTime() <= asOf.getTime()) {
    throw new ScenarioConflictError("invalid_scenario_horizon");
  }

  const contribution = BigInt(input.monthly_contribution.minor_units);
  let low = BigInt(input.baseline.minor_units);
  let mid = low;
  let high = low;
  const points: FutureMirrorPoint[] = [];
  let ordinal = 1;
  while (ordinal <= 121) {
    const scheduled = addMonthClamped(asOf, ordinal);
    const pointDate = scheduled.getTime() >= target.getTime()
      ? target
      : scheduled;
    low = compoundMonth(low, contribution, input.annual_return_bps.low);
    mid = compoundMonth(mid, contribution, input.annual_return_bps.mid);
    high = compoundMonth(high, contribution, input.annual_return_bps.high);
    points.push({
      ordinal,
      projected_date: dateOnly(pointDate),
      low_amount_minor: low.toString(),
      mid_amount_minor: mid.toString(),
      high_amount_minor: high.toString(),
    });
    if (pointDate.getTime() === target.getTime()) return points;
    ordinal += 1;
  }
  throw new ScenarioConflictError("invalid_scenario_horizon");
}

async function sha256(value: string): Promise<string> {
  const bytes = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(bytes)]
    .map((entry) => entry.toString(16).padStart(2, "0"))
    .join("");
}

function canonicalIntentionCreate(input: IntentionCreateInput): string {
  return JSON.stringify({
    title: input.title,
    target: input.target,
    target_date: input.target_date,
  });
}

function canonicalFutureMirror(intentionId: string, input: FutureMirrorInput): string {
  return JSON.stringify({
    intention_id: intentionId,
    name: input.name,
    baseline: input.baseline,
    monthly_contribution: input.monthly_contribution,
    annual_return_bps: input.annual_return_bps,
    as_of_date: input.as_of_date,
  });
}

function transaction<T>(
  binding: SupabaseRepositoryBinding,
  callback: (database: DatabaseClient, claims: VerifiedRequestClaims) => Promise<T>,
): Promise<T> {
  return withRequestTransaction(
    { pool: binding.pool, verifiedClaims: binding.claims },
    callback,
  );
}

async function currentDeletionEpoch(database: DatabaseClient): Promise<string> {
  const result = await database.query<{ deletion_epoch: string }>(
    `select deletion_epoch::text
       from argus_app.members
      where user_id = argus_private.request_user_id() and status = 'active'
      for share`,
  );
  const value = result.rows[0]?.deletion_epoch;
  if (value === undefined) throw new RepositoryNotFoundError();
  return value;
}

async function claimIdempotency(
  database: DatabaseClient,
  operation: string,
  key: string,
  requestHash: string,
  deletionEpoch: string,
): Promise<string | null> {
  await database.query(
    `insert into argus_private.member_idempotency_records(
       user_id, deletion_epoch, operation, idempotency_key, request_hash
     ) values (
       argus_private.request_user_id(), $1::bigint, $2, $3, $4
     ) on conflict (user_id, operation, idempotency_key) do nothing`,
    [deletionEpoch, operation, key, requestHash],
  );
  const result = await database.query<{
    deletion_epoch: string;
    request_hash: string;
    resource_id: string | null;
  }>(
    `select deletion_epoch::text, request_hash, resource_id
       from argus_private.member_idempotency_records
      where user_id = argus_private.request_user_id()
        and operation = $1 and idempotency_key = $2
      for update`,
    [operation, key],
  );
  const record = result.rows[0];
  if (
    record === undefined || record.deletion_epoch !== deletionEpoch ||
    record.request_hash !== requestHash
  ) {
    throw new ScenarioConflictError("idempotency_conflict");
  }
  return record.resource_id;
}

async function completeIdempotency(
  database: DatabaseClient,
  operation: string,
  key: string,
  resourceId: string,
  responseStatus: 200 | 201,
): Promise<void> {
  await database.query(
    `update argus_private.member_idempotency_records
        set resource_id = $3, response_status = $4
      where user_id = argus_private.request_user_id()
        and operation = $1 and idempotency_key = $2`,
    [operation, key, resourceId, responseStatus],
  );
}

async function assertFutureDate(
  database: DatabaseClient,
  value: string,
): Promise<void> {
  const result = await database.query<{ valid: boolean }>(
    "select $1::date > current_date as valid",
    [value],
  );
  if (result.rows[0]?.valid !== true) {
    throw new ScenarioConflictError("invalid_scenario_input");
  }
}

async function intentionView(
  database: DatabaseClient,
  intentionId: string,
): Promise<MemberIntention | null> {
  const result = await database.query<Record<string, unknown>>(
    `select id, title,
            jsonb_build_object(
              'minor_units', target_amount_minor::text,
              'currency', currency
            ) as target,
            target_date::text, status, version, created_at
      from argus_app.intentions
      where user_id = argus_private.request_user_id() and id = $1
        and deletion_epoch = (
          select deletion_epoch from argus_app.members
           where user_id = argus_private.request_user_id() and status = 'active'
        )
        and target_amount_minor is not null and currency is not null
        and target_date is not null`,
    [intentionId],
  );
  const row = result.rows[0];
  return row === undefined ? null : intentionSchema.parse(row);
}

async function futureMirrorView(
  database: DatabaseClient,
  intentionId: string,
  runId: string,
): Promise<FutureMirror | null> {
  const runResult = await database.query<{
    id: string;
    intention_id: string;
    input_hash: string;
    model_version: string;
    assumption_version: string;
    assumptions: Record<string, unknown>;
    generated_at: string;
    uncertainty_disclosure: string;
  }>(
    `select run.id, run.intention_id, run.input_hash, run.model_version,
            run.assumption_version, run.assumptions,
            run.created_at as generated_at, run.uncertainty_disclosure
       from argus_app.future_mirror_runs run
       join argus_app.intentions intention
         on intention.user_id = run.user_id and intention.id = run.intention_id
      where run.user_id = argus_private.request_user_id()
        and run.deletion_epoch = (
          select deletion_epoch from argus_app.members
           where user_id = argus_private.request_user_id() and status = 'active'
        )
        and intention.deletion_epoch = run.deletion_epoch
        and run.intention_id = $1 and run.id = $2 and run.status = 'completed'`,
    [intentionId, runId],
  );
  const run = runResult.rows[0];
  if (run === undefined) return null;
  const points = (
    await database.query<FutureMirrorPoint>(
      `select ordinal, projected_date::text,
              low_amount_minor::text, mid_amount_minor::text,
              high_amount_minor::text
         from argus_app.future_mirror_points
        where user_id = argus_private.request_user_id() and run_id = $1
          and deletion_epoch = (
            select deletion_epoch from argus_app.members
             where user_id = argus_private.request_user_id() and status = 'active'
          )
        order by ordinal`,
      [runId],
    )
  ).rows;
  const assumptions = run.assumptions as {
    input: FutureMirrorInput;
    intention_snapshot: { target_date: string };
  };
  return futureMirrorSchema.parse({
    id: run.id,
    intention_id: run.intention_id,
    ...assumptions.input,
    target_date: assumptions.intention_snapshot.target_date,
    points,
    model_version: run.model_version,
    assumption_version: run.assumption_version,
    input_hash: run.input_hash,
    generated_at: run.generated_at,
    uncertainty_disclosure: run.uncertainty_disclosure,
  });
}

export type ScenarioRepository = ReturnType<typeof createSupabaseScenarioRepository>;

export function createSupabaseScenarioRepository(
  binding: SupabaseRepositoryBinding,
) {
  return Object.freeze({
    listIntentions: (status?: "active" | "archived", limit = 20) =>
      transaction(binding, async (database) => {
        const result = await database.query<{ id: string }>(
          `select id from argus_app.intentions
            where user_id = argus_private.request_user_id()
              and deletion_epoch = (
                select deletion_epoch from argus_app.members
                 where user_id = argus_private.request_user_id() and status = 'active'
              )
              and ($1::text is null or status = $1)
              and target_amount_minor is not null and currency is not null
              and target_date is not null
            order by created_at desc, id
            limit $2`,
          [status ?? null, limit],
        );
        const items = await Promise.all(
          result.rows.map(({ id }) => intentionView(database, id)),
        );
        return { items: items.filter((item): item is MemberIntention => item !== null), next_cursor: null };
      }),

    getIntention: (id: string) =>
      transaction(binding, async (database) => {
        const item = await intentionView(database, id);
        if (item === null) throw new RepositoryNotFoundError();
        return item;
      }),

    createIntention: (raw: IntentionCreateInput, idempotencyKey: string) => {
      const input = intentionCreateSchema.parse(raw);
      return transaction(binding, async (database) => {
        const deletionEpoch = await currentDeletionEpoch(database);
        const requestHash = await sha256(canonicalIntentionCreate(input));
        const existingId = await claimIdempotency(
          database,
          "intention.create",
          idempotencyKey,
          requestHash,
          deletionEpoch,
        );
        if (existingId !== null) {
          const existing = await intentionView(database, existingId);
          if (existing === null) throw new ScenarioConflictError("idempotency_conflict");
          return existing;
        }
        await assertFutureDate(database, input.target_date);
        const id = crypto.randomUUID();
        const inserted = await database.query<{ id: string }>(
          `insert into argus_app.intentions(
             id, user_id, deletion_epoch, title, target_amount_minor,
             currency, target_date, status
           ) values (
             $1, argus_private.request_user_id(), $2::bigint, $3,
             $4::bigint, $5, $6::date, 'active'
           ) returning id`,
          [
            id,
            deletionEpoch,
            input.title,
            input.target.minor_units,
            input.target.currency,
            input.target_date,
          ],
        );
        if (inserted.rows.length !== 1) throw new RepositoryNotFoundError();
        await completeIdempotency(
          database,
          "intention.create",
          idempotencyKey,
          id,
          200,
        );
        const created = await intentionView(database, id);
        if (created === null) throw new RepositoryNotFoundError();
        return created;
      });
    },

    patchIntention: (
      id: string,
      raw: IntentionPatchInput,
      expectedVersion: number,
    ) => {
      const input = intentionPatchSchema.parse(raw);
      return transaction(binding, async (database) => {
        if (input.target_date !== undefined) {
          await assertFutureDate(database, input.target_date);
        }
        const result = await database.query<{ id: string }>(
          `update argus_app.intentions
              set title = coalesce($2, title),
                  target_amount_minor = coalesce($3::bigint, target_amount_minor),
                  currency = coalesce($4, currency),
                  target_date = coalesce($5::date, target_date),
                  version = version + 1
            where user_id = argus_private.request_user_id() and id = $1
              and deletion_epoch = (
                select deletion_epoch from argus_app.members
                 where user_id = argus_private.request_user_id() and status = 'active'
              )
              and status = 'active' and version = $6
          returning id`,
          [
            id,
            input.title ?? null,
            input.target?.minor_units ?? null,
            input.target?.currency ?? null,
            input.target_date ?? null,
            expectedVersion,
          ],
        );
        if (result.rows.length !== 1) {
          const existing = await intentionView(database, id);
          if (existing === null) throw new RepositoryNotFoundError();
          throw new RepositoryRevisionConflictError();
        }
        return (await intentionView(database, id))!;
      });
    },

    archiveIntention: (id: string, expectedVersion: number) =>
      transaction(binding, async (database) => {
        const result = await database.query<{ id: string }>(
          `update argus_app.intentions
              set status = 'archived', version = version + 1
            where user_id = argus_private.request_user_id() and id = $1
              and deletion_epoch = (
                select deletion_epoch from argus_app.members
                 where user_id = argus_private.request_user_id() and status = 'active'
              )
              and status = 'active' and version = $2
          returning id`,
          [id, expectedVersion],
        );
        if (result.rows.length !== 1) {
          const existing = await intentionView(database, id);
          if (existing === null) throw new RepositoryNotFoundError();
          throw new RepositoryRevisionConflictError();
        }
        return (await intentionView(database, id))!;
      }),

    createFutureMirror: (
      intentionId: string,
      raw: FutureMirrorInput,
      idempotencyKey: string,
    ) => {
      const input = futureMirrorInputSchema.parse(raw);
      return transaction(binding, async (database) => {
        const deletionEpoch = await currentDeletionEpoch(database);
        const requestHash = await sha256(canonicalFutureMirror(intentionId, input));
        const existingId = await claimIdempotency(
          database,
          "future-mirror.create",
          idempotencyKey,
          requestHash,
          deletionEpoch,
        );
        if (existingId !== null) {
          const existing = await futureMirrorView(database, intentionId, existingId);
          if (existing === null) throw new ScenarioConflictError("idempotency_conflict");
          return existing;
        }
        const locked = await database.query<Record<string, unknown>>(
          `select id, title, target_amount_minor::text as target_amount_minor,
                  currency, target_date::text, version
             from argus_app.intentions
            where user_id = argus_private.request_user_id() and id = $1
              and deletion_epoch = $2::bigint
              and status = 'active' and target_amount_minor is not null
              and currency is not null and target_date is not null
            for update`,
          [intentionId, deletionEpoch],
        );
        const intention = locked.rows[0];
        if (intention === undefined) throw new RepositoryNotFoundError();
        if (input.baseline.currency !== intention.currency) {
          throw new ScenarioConflictError("invalid_scenario_input");
        }
        const snapshot = {
          currency: intention.currency,
          target_date: intention.target_date,
        };
        const exactInputHash = await createFutureMirrorProjectionHash(
          input,
          String(intention.target_date),
          String(intention.currency),
        );
        const points = createHypotheticalProjection({
          ...input,
          targetDate: String(intention.target_date),
        });
        const candidateId = crypto.randomUUID();
        const inserted = await database.query<{ id: string }>(
          `insert into argus_app.future_mirror_runs(
             id, user_id, deletion_epoch, intention_id, input_hash,
             model_version, assumption_version, assumptions, status,
             completed_at, uncertainty_disclosure
           ) values (
             $1, argus_private.request_user_id(), $2::bigint, $3, $4,
             $5, $6, $7::jsonb, 'completed', clock_timestamp(), $8
           ) on conflict (
             user_id, deletion_epoch, intention_id, input_hash, model_version
           ) do nothing returning id`,
          [
            candidateId,
            deletionEpoch,
            intentionId,
            exactInputHash,
            MODEL_VERSION,
            ASSUMPTION_VERSION,
            JSON.stringify({ input, intention_snapshot: snapshot }),
            UNCERTAINTY_DISCLOSURE,
          ],
        );
        const runId = inserted.rows[0]?.id ?? (
          await database.query<{ id: string }>(
            `select id from argus_app.future_mirror_runs
              where user_id = argus_private.request_user_id()
                and deletion_epoch = $1::bigint and intention_id = $2
                and input_hash = $3 and model_version = $4`,
            [deletionEpoch, intentionId, exactInputHash, MODEL_VERSION],
          )
        ).rows[0]?.id;
        if (runId === undefined) throw new RepositoryNotFoundError();
        if (runId === candidateId) {
          for (const point of points) {
            await database.query(
              `insert into argus_app.future_mirror_points(
                 run_id, user_id, deletion_epoch, ordinal, projected_date,
                 low_amount_minor, mid_amount_minor, high_amount_minor
               ) values (
                 $1, argus_private.request_user_id(), $2::bigint, $3, $4::date,
                 $5::bigint, $6::bigint, $7::bigint
               )`,
              [
                runId,
                deletionEpoch,
                point.ordinal,
                point.projected_date,
                point.low_amount_minor,
                point.mid_amount_minor,
                point.high_amount_minor,
              ],
            );
          }
        }
        await completeIdempotency(
          database,
          "future-mirror.create",
          idempotencyKey,
          runId,
          200,
        );
        const created = await futureMirrorView(database, intentionId, runId);
        if (created === null) throw new RepositoryNotFoundError();
        return created;
      });
    },

    getLatestFutureMirror: (intentionId: string) =>
      transaction(binding, async (database) => {
        const result = await database.query<{ id: string }>(
          `select id from argus_app.future_mirror_runs
            where user_id = argus_private.request_user_id()
              and deletion_epoch = (
                select deletion_epoch from argus_app.members
                 where user_id = argus_private.request_user_id() and status = 'active'
              )
              and intention_id = $1 and status = 'completed'
            order by created_at desc, id desc limit 1`,
          [intentionId],
        );
        const id = result.rows[0]?.id;
        if (id === undefined) throw new RepositoryNotFoundError();
        return (await futureMirrorView(database, intentionId, id))!;
      }),

    getFutureMirror: (intentionId: string, runId: string) =>
      transaction(binding, async (database) => {
        const item = await futureMirrorView(database, intentionId, runId);
        if (item === null) throw new RepositoryNotFoundError();
        return item;
      }),
  });
}

export function createFutureMirrorProjectionHash(
  input: FutureMirrorInput,
  targetDate: string,
  currency: string,
): Promise<string> {
  return sha256(JSON.stringify({
    input,
    target_date: targetDate,
    currency,
    model_version: MODEL_VERSION,
    assumption_version: ASSUMPTION_VERSION,
  }));
}
