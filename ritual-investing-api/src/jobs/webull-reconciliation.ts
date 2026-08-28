import type { OutboxEvent } from "./consumer-receipts.ts";

export type WebullReconciliationOutcome =
  | "resolved"
  | "not_found"
  | "manual_review"
  | "reauthorization_required"
  | "stale";

/**
 * Deliberately exposes lookup only. There is no order execution, normalized
 * reviewed payload, preview, placement, modification, or cancellation method.
 */
export interface WebullReconciliationPort {
  inspectExistingCommand(
    input: Readonly<{
      eventId: string;
      commandId: string;
      keepAlive: () => Promise<void>;
    }>,
  ): Promise<WebullReconciliationOutcome>;
}

export async function runWebullReconciliation(
  event: OutboxEvent,
  port: WebullReconciliationPort,
  keepAlive: () => Promise<void>,
): Promise<string> {
  if (
    event.handlerName !== "webull-reconciliation" ||
    event.eventType !== "webull.command.reconciliation.requested" ||
    event.userId === null ||
    event.deletionEpoch === null
  ) throw new Error("invalid_event_payload");
  const outcome = await port.inspectExistingCommand({
    eventId: event.id,
    commandId: event.aggregateId,
    keepAlive,
  });
  return `webull-reconciliation:${event.aggregateId}:${outcome}`;
}
