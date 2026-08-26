import type { PoolClient } from "@neondatabase/serverless";
import { z } from "zod";

const outboxPayload = z
  .record(z.string().min(1).max(64), z.unknown())
  .refine(
    (payload) =>
      !/(?:authorization|password|provider.?body|push.?token|raw.?token|secret)/i.test(
        JSON.stringify(payload),
      ),
    "unsafe_outbox_payload",
  );

const outboxInput = z
  .object({
    topic: z.string().regex(/^[a-z][a-z0-9_.-]{0,63}$/),
    aggregateKind: z.string().regex(/^[a-z][a-z0-9_.-]{0,63}$/),
    aggregateId: z.string().uuid(),
    aggregateVersion: z.number().int().nonnegative(),
    tenantId: z.string().uuid().nullable(),
    resetGeneration: z.number().int().nonnegative(),
    deletionGeneration: z.number().int().nonnegative(),
    dedupeKey: z.string().min(1).max(255),
    payload: outboxPayload,
    availableAt: z.date().optional(),
  })
  .strict();

export type OutboxInput = z.infer<typeof outboxInput>;

export async function enqueueOutbox(
  client: Pick<PoolClient, "query">,
  input: OutboxInput,
): Promise<string> {
  const parsed = outboxInput.safeParse(input);
  if (!parsed.success) {
    const unsafe = parsed.error.issues.some((issue) =>
      issue.message.includes("unsafe_outbox_payload"),
    );
    throw new Error(unsafe ? "unsafe_outbox_payload" : "invalid_outbox_event");
  }
  const event = parsed.data;
  const result = await client.query<{ id: string }>(
    `insert into outbox_events(
       topic,aggregate_kind,aggregate_id,aggregate_version,tenant_id,
       reset_generation,deletion_generation,dedupe_key,payload,schema_version,
       available_at
     ) values ($1,$2,$3,$4,$5,$6,$7,$8,$9::jsonb,1,$10)
     on conflict (topic,dedupe_key) do nothing
     returning id`,
    [
      event.topic,
      event.aggregateKind,
      event.aggregateId,
      event.aggregateVersion,
      event.tenantId,
      event.resetGeneration,
      event.deletionGeneration,
      event.dedupeKey,
      JSON.stringify(event.payload),
      event.availableAt ?? new Date(),
    ],
  );
  const id = result.rows[0]?.id;
  if (id !== undefined) return id;
  const prior = await client.query<{
    id: string;
    aggregate_kind: string;
    aggregate_id: string;
    aggregate_version: number;
    tenant_id: string | null;
    reset_generation: number | null;
    deletion_generation: number;
    payload: Record<string, unknown>;
  }>(
    `select id,aggregate_kind,aggregate_id,aggregate_version,tenant_id,
            reset_generation,deletion_generation,payload
       from outbox_events where topic=$1 and dedupe_key=$2`,
    [event.topic, event.dedupeKey],
  );
  const existing = prior.rows[0];
  if (
    existing === undefined ||
    existing.aggregate_kind !== event.aggregateKind ||
    existing.aggregate_id !== event.aggregateId ||
    existing.aggregate_version !== event.aggregateVersion ||
    existing.tenant_id !== event.tenantId ||
    Number(existing.reset_generation ?? 0) !== event.resetGeneration ||
    existing.deletion_generation !== event.deletionGeneration ||
    JSON.stringify(existing.payload) !== JSON.stringify(event.payload)
  )
    throw new Error("outbox_dedupe_conflict");
  return existing.id;
}
