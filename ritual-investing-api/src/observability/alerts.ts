import { z } from "zod";

const alertFixtureSchema = z
  .object({
    id: z.string().regex(/^[a-z0-9-]{3,80}$/),
    metric: z.string().regex(/^[a-z][a-z0-9_.]{2,120}$/),
    comparison: z.enum(["gte", "lte", "eq"]),
    threshold: z.number().finite(),
    severity: z.enum(["warning", "critical"]),
    window: z.string().regex(/^\d+[smhd]$/),
    runbook: z.string().regex(/^docs\/ritual-investing\/[a-z0-9-]+\.md$/),
  })
  .strict();

const alertFixtureDocumentSchema = z
  .object({
    schema_version: z.literal(1),
    alerts: z.array(alertFixtureSchema).min(1).max(100),
  })
  .strict();

export type AlertFixture = z.infer<typeof alertFixtureSchema>;

export function parseAlertFixtures(input: unknown): AlertFixture[] {
  const document = alertFixtureDocumentSchema.parse(input);
  const identifiers = new Set(document.alerts.map(({ id }) => id));
  if (identifiers.size !== document.alerts.length) {
    throw new Error("alert fixture identifiers must be unique");
  }
  return document.alerts;
}

export function evaluateAlertFixtures(
  fixtures: readonly AlertFixture[],
  samples: Readonly<Record<string, number>>,
): string[] {
  return fixtures.flatMap((fixture) => {
    const sample = samples[fixture.metric];
    if (sample === undefined || !Number.isFinite(sample)) return [];
    const fired =
      fixture.comparison === "gte"
        ? sample >= fixture.threshold
        : fixture.comparison === "lte"
          ? sample <= fixture.threshold
          : sample === fixture.threshold;
    return fired ? [fixture.id] : [];
  });
}
