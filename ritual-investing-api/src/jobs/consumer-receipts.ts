import type { DatabaseClient } from "../db/database-port.ts";
import type { RetainedEventType, RetainedJobHandler } from "./scheduled.ts";

export type OutboxEvent = Readonly<{
  id: string;
  eventType: RetainedEventType;
  handlerName: RetainedJobHandler;
  aggregateId: string;
  tenantId: string | null;
  lifecycleId: string | null;
  userId: string | null;
  /** U5 provider-adapter compatibility only; U6 authorization uses lifecycleId. */
  deletionEpoch: number | null;
}>;

export type ConsumerEffect = (
  database: DatabaseClient,
  event: OutboxEvent,
) => Promise<string>;
