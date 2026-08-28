import type { ProviderProjection } from "../domains/brokerage-projections/types.ts";
import type { OutboxEvent } from "./consumer-receipts.ts";

export type WebullProjectionRefreshOutcome =
  | "refreshed"
  | "won_elsewhere"
  | "reauthorization_required"
  | "stale";

export interface WebullProjectionRefreshPort {
  refreshExistingProjection(
    input: Readonly<{
      eventId: string;
      leaseId: string;
      keepAlive: () => Promise<void>;
    }>,
  ): Promise<WebullProjectionRefreshOutcome>;
}

export function assertBackgroundProjectionSafe(
  projection: ProviderProjection,
  now: Date,
): void {
  if (
    !Number.isFinite(projection.fetchedAt.getTime()) ||
    !Number.isFinite(projection.expiresAt.getTime()) ||
    projection.expiresAt < projection.fetchedAt ||
    projection.expiresAt.getTime() - projection.fetchedAt.getTime() > 300_000 ||
    Math.abs(projection.fetchedAt.getTime() - now.getTime()) > 30_000 ||
    (projection.providerObservedAt !== null &&
      (!Number.isFinite(projection.providerObservedAt.getTime()) ||
        projection.providerObservedAt > projection.fetchedAt))
  ) throw new Error("invalid_event_payload");

  const serialized = JSON.stringify(projection.payload);
  if (
    serialized === undefined ||
    new TextEncoder().encode(serialized).byteLength > 512 * 1024 ||
    /"(?:access|refresh)?_?token"\s*:|"secret"\s*:|"raw_payload"\s*:|"provider_(?:account|asset|order)_(?:id|ref)"\s*:/i
      .test(serialized)
  ) throw new Error("invalid_event_payload");
}

/** Refreshes an already-leased read projection; it has no financial command port. */
export async function runWebullProjectionRefresh(
  event: OutboxEvent,
  port: WebullProjectionRefreshPort,
  keepAlive: () => Promise<void>,
): Promise<string> {
  if (
    event.handlerName !== "webull-projection-refresh" ||
    event.eventType !== "webull.projection.refresh.requested" ||
    event.userId === null ||
    event.deletionEpoch === null
  ) throw new Error("invalid_event_payload");
  const outcome = await port.refreshExistingProjection({
    eventId: event.id,
    leaseId: event.aggregateId,
    keepAlive,
  });
  return `webull-projection-refresh:${event.aggregateId}:${outcome}`;
}
