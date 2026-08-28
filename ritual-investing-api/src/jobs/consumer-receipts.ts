import type { DatabaseClient } from "../db/database-port.ts";
import type { RetainedEventType, RetainedJobHandler } from "./scheduled.ts";

export type OutboxEvent = Readonly<{
  id: string;
  eventType: RetainedEventType;
  handlerName: RetainedJobHandler;
  aggregateId: string;
  userId: string | null;
  deletionEpoch: number | null;
}>;

export type ConsumerEffect = (
  database: DatabaseClient,
  event: OutboxEvent,
) => Promise<string>;
