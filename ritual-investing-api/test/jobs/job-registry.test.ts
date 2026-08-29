import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import {
  durableWorkRegistry,
  eventRegistration,
  validateDurableWorkRegistry,
} from "../../src/jobs/registry.ts";
import { retainedJobHandlers } from "../../src/jobs/scheduled.ts";
import { persistedFailureCodes } from "../../src/jobs/queue-runtime.ts";

describe("U6 durable-work registry", () => {
  it("single-sources every retained event and handler", () => {
    expect(validateDurableWorkRegistry(durableWorkRegistry)).toEqual([]);
    expect(retainedJobHandlers).toEqual(
      Object.fromEntries(
        Object.entries(durableWorkRegistry.events).map(([eventType, registration]) => [
          eventType,
          registration.handler,
        ]),
      ),
    );
    expect(eventRegistration("media.scan.requested")).toBeNull();
    expect(eventRegistration("media.structural_validation.requested")).toMatchObject({
      effect: "external_saga",
      handler: "media-structural-validation",
      owner: "media",
    });
  });

  it("declares exact bounded retry and dead-letter behavior", () => {
    for (const registration of Object.values(durableWorkRegistry.events)) {
      expect(registration.payloadVersion).toBe(1);
      expect(registration.visibilitySeconds).toBeGreaterThanOrEqual(15);
      expect(registration.visibilitySeconds).toBeLessThanOrEqual(55);
      expect(registration.maxAttempts).toBeGreaterThanOrEqual(1);
      expect(registration.maxAttempts).toBeLessThanOrEqual(10);
      expect(registration.deadLetter).toBe("redacted_terminal_record");
    }
  });

  it("keeps Cron on bounded coordination and enqueue functions", () => {
    expect(Object.keys(durableWorkRegistry.schedules).sort()).toEqual([
      "argus-durable-work-coordinate",
      "argus-webull-recovery-coordinate",
      "argus-worker-dispatch-enqueue",
    ]);
    for (const schedule of Object.values(durableWorkRegistry.schedules)) {
      expect(schedule.command).toMatch(
        /^select argus_private\.(?:coordinate|enqueue)_[a-z0-9_]+\(.*\);$/,
      );
      expect(schedule.command).not.toMatch(/net\.|http|cron\.|pgmq\./i);
      expect(schedule.coordinator).toMatch(/^(?:coordinate|enqueue)_[a-z0-9_]+$/);
      expect(schedule.maxBatchSize).toBeGreaterThanOrEqual(1);
      expect(schedule.maxBatchSize).toBeLessThanOrEqual(25);
      expect(schedule.retainedRunDays).toBe(7);
    }
  });

  it("matches the versioned SQL registry and schedule contract exactly", async () => {
    const sql = await readFile(
      resolve(
        dirname(fileURLToPath(import.meta.url)),
        "../../../supabase/migrations/20260829140000_u6_compose_durable_external_work.sql",
      ),
      "utf8",
    );
    const eventSection = sql.slice(
      sql.indexOf("insert into argus_private.job_event_registry"),
      sql.indexOf("create table argus_private.job_schedule_registry"),
    );
    const sqlEvents = new Map(
      [...eventSection.matchAll(
        /\('([^']+)',1,'([^']+)','([^']+)','([^']+)','([^']+)','([^']+)',([0-9]+),([0-9]+),([0-9]+),([0-9]+),'redacted'\)/g,
      )].map((match) => [match[1], {
        queue: match[2],
        handler: match[3],
        effect: match[4],
        scope: match[5],
        subjectKind: match[6],
        maxAttempts: Number(match[7]),
        visibilitySeconds: Number(match[8]),
        retryBaseSeconds: Number(match[9]),
        retryCapSeconds: Number(match[10]),
      }]),
    );
    expect(Object.fromEntries(sqlEvents)).toEqual(
      Object.fromEntries(
        Object.entries(durableWorkRegistry.events).map(([eventType, registration]) => [
          eventType,
          {
            queue: registration.queue,
            handler: registration.handler,
            effect: registration.effect,
            scope: registration.scope,
            subjectKind: registration.subjectKind,
            maxAttempts: registration.maxAttempts,
            visibilitySeconds: registration.visibilitySeconds,
            retryBaseSeconds: registration.retryBaseSeconds,
            retryCapSeconds: registration.retryCapSeconds,
          },
        ]),
      ),
    );

    const scheduleSection = sql.slice(
      sql.indexOf("insert into argus_private.job_schedule_registry"),
      sql.indexOf("create or replace function argus_private.reject_registry_mutation"),
    ).replaceAll(/\s+/g, " ");
    const sqlSchedules = new Map(
      [...scheduleSection.matchAll(
        /\('([^']+)',\s*'([^']+)',\s*'([^']+)',\s*'([^']+)',\s*([0-9]+),\s*([0-9]+)\)/g,
      )].map((match) => [match[1], {
        cron: match[2],
        command: match[3],
        coordinator: match[4],
        maxBatchSize: Number(match[5]),
        retainedRunDays: Number(match[6]),
      }]),
    );
    expect(Object.fromEntries(sqlSchedules)).toEqual(durableWorkRegistry.schedules);

    const sqlFailureCodes = (name: "p_reason_code" | "p_failure_code") => {
      const section = sql.slice(
        sql.indexOf(`if ${name} not in (`),
        sql.indexOf(") or p_diagnostic_hash", sql.indexOf(`if ${name} not in (`)),
      );
      return [...section.matchAll(/'([a-z][a-z0-9_]*)'/g)]
        .map((match) => match[1]).sort();
    };
    expect(sqlFailureCodes("p_reason_code")).toEqual([...persistedFailureCodes].sort());
    expect(sqlFailureCodes("p_failure_code")).toEqual([...persistedFailureCodes].sort());
  });
});
