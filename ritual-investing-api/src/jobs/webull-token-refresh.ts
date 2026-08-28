import type { OutboxEvent } from "./consumer-receipts.ts";

export type WebullTokenRefreshOutcome =
  | "rotated"
  | "won_elsewhere"
  | "reauthorization_required"
  | "stale";

export interface WebullTokenRefreshPort {
  refreshExistingConnection(
    input: Readonly<{
      eventId: string;
      connectionId: string;
      keepAlive: () => Promise<void>;
    }>,
  ): Promise<WebullTokenRefreshOutcome>;
}

/** Recovery may rotate credentials for an existing connection; it cannot create one. */
export async function runWebullTokenRefresh(
  event: OutboxEvent,
  port: WebullTokenRefreshPort,
  keepAlive: () => Promise<void>,
): Promise<string> {
  if (
    event.handlerName !== "webull-token-refresh" ||
    event.eventType !== "webull.token.refresh.requested" ||
    event.userId === null ||
    event.deletionEpoch === null
  ) {
    throw new Error("invalid_event_payload");
  }
  const outcome = await port.refreshExistingConnection({
    eventId: event.id,
    connectionId: event.aggregateId,
    keepAlive,
  });
  return `webull-token-refresh:${event.aggregateId}:${outcome}`;
}
