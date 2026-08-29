import type { OutboxEvent } from "./consumer-receipts.ts";

export interface WorkerMediaSagaPort {
  validate(
    event: OutboxEvent,
    keepAlive?: () => Promise<void>,
  ): Promise<string>;
  cleanup(
    event: OutboxEvent,
    keepAlive?: () => Promise<void>,
  ): Promise<string>;
}

export function runMediaStructuralValidation(
  event: OutboxEvent,
  port: WorkerMediaSagaPort,
  keepAlive?: () => Promise<void>,
): Promise<string> {
  if (event.handlerName !== "media-structural-validation" || event.userId === null ||
    event.tenantId === null || event.lifecycleId === null) {
    throw new Error("invalid_event_payload");
  }
  return port.validate(event, keepAlive);
}

export function runMediaCleanup(
  event: OutboxEvent,
  port: WorkerMediaSagaPort,
  keepAlive?: () => Promise<void>,
): Promise<string> {
  if (event.handlerName !== "media-cleanup" || event.userId === null ||
    event.tenantId === null || event.lifecycleId === null) {
    throw new Error("invalid_event_payload");
  }
  return port.cleanup(event, keepAlive);
}
