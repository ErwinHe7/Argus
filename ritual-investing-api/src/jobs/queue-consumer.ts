import { z } from "zod";

export const queueConsumerSchema = z.enum([
  "briefing-builder",
  "notification-writer",
  "notification-delivery",
  "privacy-export",
  "privacy-purge",
  "media-scan",
  "media-cleanup",
  "moderation-triage",
  "editorial-publisher",
  "recurring-plan-delivery",
  "privacy-export-retention",
]);

const queueWorkSchema = z
  .object({
    schema_version: z.literal(1),
    outbox_id: z.string().uuid(),
    consumer: queueConsumerSchema,
  })
  .strict();

export type QueueWorkMessage = z.infer<typeof queueWorkSchema>;

export function parseQueueWork(value: unknown): QueueWorkMessage {
  return queueWorkSchema.parse(value);
}
