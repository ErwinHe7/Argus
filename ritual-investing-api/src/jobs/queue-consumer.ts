import { z } from "zod";

/** The private outbox row supplies every sensitive and descriptive field. */
const queueWorkSchema = z
  .object({
    version: z.literal(1),
    event_id: z.string().uuid(),
  })
  .strict();

export type QueueWorkMessage = z.infer<typeof queueWorkSchema>;

export function parseQueueWork(value: unknown): QueueWorkMessage {
  return queueWorkSchema.parse(value);
}
