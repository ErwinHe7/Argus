import { Pool } from "@neondatabase/serverless";

import type { DatabasePoolFactory } from "../../../db/client.ts";
import type {
  AdminEditorialItem,
  AdminEditorialRevision,
  EditorialKind,
} from "./schemas.ts";
import { adminRequestHash } from "../request-hash.ts";

export type EditorialPage = {
  items: AdminEditorialItem[];
  next: string | null;
};

type ActorCommand = {
  actorStaffId: string;
  requestId: string;
};
type IdempotentCommand = ActorCommand & {
  idempotencyKey: string;
};

export interface AdminEditorialRepository {
  list(input: {
    actorStaffId: string;
    kind: EditorialKind;
    state?: string;
    authorStaffId?: string;
    search?: string;
    limit: number;
    after?: string;
  }): Promise<EditorialPage>;
  createItem(
    input: IdempotentCommand & {
      kind: EditorialKind;
      slug: string;
      payload: unknown;
    },
  ): Promise<AdminEditorialItem>;
  getItem(input: {
    actorStaffId: string;
    kind: EditorialKind;
    itemId: string;
  }): Promise<AdminEditorialItem | null>;
  createRevision(
    input: IdempotentCommand & {
      kind: EditorialKind;
      itemId: string;
      sourceRevisionId: string;
      payload: unknown;
    },
  ): Promise<AdminEditorialItem>;
  getRevision(input: {
    actorStaffId: string;
    kind: EditorialKind;
    itemId: string;
    revisionId: string;
  }): Promise<AdminEditorialRevision | null>;
  patchRevision(
    input: ActorCommand & {
      kind: EditorialKind;
      itemId: string;
      revisionId: string;
      expectedVersion: number;
      patch: unknown;
    },
  ): Promise<AdminEditorialRevision>;
  requestReview(
    input: IdempotentCommand & {
      kind: EditorialKind;
      itemId: string;
      revisionId: string;
      note: string;
      highTrust: boolean;
    },
  ): Promise<AdminEditorialRevision>;
  decideReview(
    input: IdempotentCommand & {
      kind: EditorialKind;
      itemId: string;
      revisionId: string;
      decision: "approved" | "changes_requested" | "rejected";
      reason: string;
    },
  ): Promise<AdminEditorialRevision>;
  publish(
    input: IdempotentCommand & {
      kind: EditorialKind;
      itemId: string;
      revisionId: string;
      effectiveAt: string;
      reason: string;
    },
  ): Promise<AdminEditorialItem>;
  withdraw(
    input: IdempotentCommand & {
      kind: EditorialKind;
      itemId: string;
      reason: string;
    },
  ): Promise<AdminEditorialItem>;
}

function normalizeItem(value: unknown): AdminEditorialItem {
  return value as AdminEditorialItem;
}
function normalizeRevision(value: unknown): AdminEditorialRevision {
  return value as AdminEditorialRevision;
}

function throwPersistedDenial(value: unknown): void {
  if (
    typeof value === "object" &&
    value !== null &&
    "_denied" in value &&
    value._denied === "self_approval"
  ) {
    throw new Error("self_approval");
  }
}

export function createPostgresAdminEditorialRepository(
  databaseUrl: string,
  poolFactory?: DatabasePoolFactory,
): AdminEditorialRepository {
  const scoped = async <T>(
    staffId: string,
    callback: (client: any) => Promise<T>,
  ): Promise<T> => {
    const pool =
      poolFactory?.(databaseUrl) ??
      new Pool({ connectionString: databaseUrl, max: 1 });
    const client = await pool.connect();
    try {
      await client.query("begin");
      await client.query("set local role ritual_staff");
      await client.query("select set_config('ritual.staff_id',$1,true)", [
        staffId,
      ]);
      const result = await callback(client);
      await client.query("commit");
      return result;
    } catch (error) {
      await client.query("rollback").catch(() => undefined);
      throw error;
    } finally {
      client.release();
      await pool.end();
    }
  };

  const command = async <T>(
    input: IdempotentCommand & { operation: string; request: unknown },
    callback: (client: any, requestHash: string) => Promise<T>,
  ) => {
    const requestHash = await adminRequestHash(input.request);
    return scoped(input.actorStaffId, (client) =>
      callback(client, requestHash),
    );
  };

  return {
    list: (input) =>
      scoped(input.actorStaffId, async (client) => {
        const result = await client.query(
          "select ritual_private.admin_editorial_page($1,$2,$3,$4,$5,$6)::jsonb value",
          [
            input.kind,
            input.state ?? null,
            input.authorStaffId ?? null,
            input.search ?? null,
            input.after ?? null,
            input.limit,
          ],
        );
        const value = result.rows[0]?.value as
          | { items: AdminEditorialItem[]; next: string | null }
          | undefined;
        return value ?? { items: [], next: null };
      }),
    createItem: (input) =>
      command(
        {
          ...input,
          operation: `editorial:${input.kind}:create`,
          request: {
            kind: input.kind,
            slug: input.slug,
            payload: input.payload,
          },
        },
        async (client, requestHash) => {
          const result = await client.query(
            "select ritual_private.admin_editorial_create($1,$2,$3,$4::jsonb,$5,$6,$7)::jsonb value",
            [
              input.actorStaffId,
              input.kind,
              input.slug,
              JSON.stringify(input.payload),
              input.requestId,
              input.idempotencyKey,
              requestHash,
            ],
          );
          return normalizeItem(result.rows[0]!.value);
        },
      ),
    getItem: (input) =>
      scoped(input.actorStaffId, async (client) => {
        const result = await client.query(
          "select ritual_private.admin_editorial_item($1,$2)::jsonb value",
          [input.kind, input.itemId],
        );
        return result.rows[0]?.value == null
          ? null
          : normalizeItem(result.rows[0].value);
      }),
    createRevision: (input) =>
      command(
        {
          ...input,
          operation: `editorial:${input.kind}:revision:create`,
          request: {
            itemId: input.itemId,
            sourceRevisionId: input.sourceRevisionId,
            payload: input.payload,
          },
        },
        async (client, requestHash) => {
          const result = await client.query(
            "select ritual_private.admin_editorial_revision_create($1,$2,$3,$4,$5::jsonb,$6,$7,$8)::jsonb value",
            [
              input.actorStaffId,
              input.kind,
              input.itemId,
              input.sourceRevisionId,
              JSON.stringify(input.payload),
              input.requestId,
              input.idempotencyKey,
              requestHash,
            ],
          );
          return normalizeItem(result.rows[0]!.value);
        },
      ),
    getRevision: (input) =>
      scoped(input.actorStaffId, async (client) => {
        const result = await client.query(
          "select ritual_private.admin_editorial_revision($1,$2,$3)::jsonb value",
          [input.kind, input.itemId, input.revisionId],
        );
        return result.rows[0]?.value == null
          ? null
          : normalizeRevision(result.rows[0].value);
      }),
    patchRevision: (input) =>
      scoped(input.actorStaffId, async (client) => {
        const result = await client.query(
          "select ritual_private.admin_editorial_revision_patch($1,$2,$3,$4,$5,$6::jsonb,$7)::jsonb value",
          [
            input.actorStaffId,
            input.kind,
            input.itemId,
            input.revisionId,
            input.expectedVersion,
            JSON.stringify(input.patch),
            input.requestId,
          ],
        );
        return normalizeRevision(result.rows[0]!.value);
      }),
    requestReview: (input) =>
      command(
        {
          ...input,
          operation: `editorial:${input.kind}:review-request`,
          request: {
            itemId: input.itemId,
            revisionId: input.revisionId,
            note: input.note,
            highTrust: input.highTrust,
          },
        },
        async (client, requestHash) => {
          const result = await client.query(
            "select ritual_private.admin_editorial_review_request($1,$2,$3,$4,$5,$6,$7,$8,$9)::jsonb value",
            [
              input.actorStaffId,
              input.kind,
              input.itemId,
              input.revisionId,
              input.note,
              input.highTrust,
              input.requestId,
              input.idempotencyKey,
              requestHash,
            ],
          );
          return normalizeRevision(result.rows[0]!.value);
        },
      ),
    decideReview: (input) =>
      command(
        {
          ...input,
          operation: `editorial:${input.kind}:review-decision`,
          request: {
            itemId: input.itemId,
            revisionId: input.revisionId,
            decision: input.decision,
            reason: input.reason,
          },
        },
        async (client, requestHash) => {
          const result = await client.query(
            "select ritual_private.admin_editorial_review_decision($1,$2,$3,$4,$5,$6,$7,$8,$9)::jsonb value",
            [
              input.actorStaffId,
              input.kind,
              input.itemId,
              input.revisionId,
              input.decision,
              input.reason,
              input.requestId,
              input.idempotencyKey,
              requestHash,
            ],
          );
          const value = result.rows[0]!.value;
          return {
            value: normalizeRevision(value),
            persistedDenial: value,
          };
        },
      ).then((outcome) => {
        throwPersistedDenial(outcome.persistedDenial);
        return outcome.value;
      }),
    publish: (input) =>
      command(
        {
          ...input,
          operation: `editorial:${input.kind}:publish`,
          request: {
            itemId: input.itemId,
            revisionId: input.revisionId,
            effectiveAt: input.effectiveAt,
            reason: input.reason,
          },
        },
        async (client, requestHash) => {
          const result = await client.query(
            "select ritual_private.admin_editorial_publish($1,$2,$3,$4,$5,$6,$7,$8,$9)::jsonb value",
            [
              input.actorStaffId,
              input.kind,
              input.itemId,
              input.revisionId,
              input.effectiveAt,
              input.reason,
              input.requestId,
              input.idempotencyKey,
              requestHash,
            ],
          );
          return normalizeItem(result.rows[0]!.value);
        },
      ),
    withdraw: (input) =>
      command(
        {
          ...input,
          operation: `editorial:${input.kind}:withdraw`,
          request: { itemId: input.itemId, reason: input.reason },
        },
        async (client, requestHash) => {
          const result = await client.query(
            "select ritual_private.admin_editorial_withdraw($1,$2,$3,$4,$5,$6,$7)::jsonb value",
            [
              input.actorStaffId,
              input.kind,
              input.itemId,
              input.reason,
              input.requestId,
              input.idempotencyKey,
              requestHash,
            ],
          );
          return normalizeItem(result.rows[0]!.value);
        },
      ),
  };
}
