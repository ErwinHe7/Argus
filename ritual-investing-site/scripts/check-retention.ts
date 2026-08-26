import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import process from "node:process";

import { createWaitlistQuery } from "../src/db/client.ts";

const overdueAfterMilliseconds = 48 * 60 * 60 * 1_000;

export type RetentionSnapshot = {
  checkedAt: string;
  lastSuccessAt: string;
  activeCount: number;
  expiringWithinSevenDaysCount: number;
  expiredCount: number;
};

export type RetentionAssessment = {
  ok: boolean;
  overdue: boolean;
  activeCount: number;
  expiringWithinSevenDaysCount: number;
  expiredCount: number;
};

function timestamp(value: string, label: string): number {
  const milliseconds = Date.parse(value);
  if (!Number.isFinite(milliseconds) || new Date(milliseconds).toISOString() !== value) {
    throw new Error(`${label} must be a canonical UTC timestamp.`);
  }
  return milliseconds;
}

function aggregate(value: number, label: string): number {
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new Error(`${label} must be a non-negative aggregate.`);
  }
  return value;
}

export function assessRetention(snapshot: RetentionSnapshot): RetentionAssessment {
  const checkedAt = timestamp(snapshot.checkedAt, "Retention checkedAt");
  const lastSuccessAt = timestamp(snapshot.lastSuccessAt, "Retention lastSuccessAt");
  const activeCount = aggregate(snapshot.activeCount, "Active count");
  const expiringWithinSevenDaysCount = aggregate(
    snapshot.expiringWithinSevenDaysCount,
    "Expiring count",
  );
  const expiredCount = aggregate(snapshot.expiredCount, "Expired count");
  const overdue = lastSuccessAt > checkedAt || checkedAt - lastSuccessAt > overdueAfterMilliseconds;
  return {
    ok: !overdue && expiredCount === 0,
    overdue,
    activeCount,
    expiringWithinSevenDaysCount,
    expiredCount,
  };
}

function numeric(value: unknown, label: string): number {
  const parsed = typeof value === "number" ? value : typeof value === "string" ? Number(value) : Number.NaN;
  return aggregate(parsed, label);
}

async function databaseSnapshot(
  databaseUrl: string,
  lastSuccessAt: string,
): Promise<RetentionSnapshot> {
  const query = createWaitlistQuery(databaseUrl);
  const rows = await query`
    select
      to_char(
        pg_catalog.clock_timestamp() at time zone 'UTC',
        'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
      ) as checked_at,
      pg_catalog.count(*)::text as active_count,
      pg_catalog.count(*) filter (
        where submitted_at <= pg_catalog.clock_timestamp() - interval '23 months 22 days'
          and submitted_at > pg_catalog.clock_timestamp() - interval '23 months 29 days'
      )::text as expiring_count,
      pg_catalog.count(*) filter (
        where submitted_at <= pg_catalog.clock_timestamp() - interval '23 months 29 days'
      )::text as expired_count
    from waitlist_private.provisional_submissions
  `;
  const row = rows[0];
  if (row === undefined || typeof row.checked_at !== "string") {
    throw new Error("Retention query returned no aggregate checkpoint.");
  }
  return {
    checkedAt: row.checked_at,
    lastSuccessAt,
    activeCount: numeric(row.active_count, "Active count"),
    expiringWithinSevenDaysCount: numeric(row.expiring_count, "Expiring count"),
    expiredCount: numeric(row.expired_count, "Expired count"),
  };
}

function argument(name: string): string | undefined {
  const index = process.argv.indexOf(name);
  return index < 0 ? undefined : process.argv[index + 1];
}

async function fileSnapshot(path: string): Promise<RetentionSnapshot> {
  const source = await readFile(resolve(path), "utf8");
  if (source.includes("@")) throw new Error("Retention evidence must contain aggregates only.");
  const parsed = JSON.parse(source) as Record<string, unknown>;
  const allowed = new Set([
    "checkedAt",
    "lastSuccessAt",
    "activeCount",
    "expiringWithinSevenDaysCount",
    "expiredCount",
  ]);
  if (Object.keys(parsed).some((key) => !allowed.has(key))) {
    throw new Error("Retention evidence contains a non-aggregate field.");
  }
  return parsed as RetentionSnapshot;
}

async function main(): Promise<void> {
  const snapshotFile = argument("--snapshot");
  const databaseUrl = process.env.WAITLIST_OWNER_DATABASE_URL;
  const lastSuccessAt = process.env.RETENTION_LAST_SUCCESS_AT;
  const snapshot = snapshotFile !== undefined
    ? await fileSnapshot(snapshotFile)
    : databaseUrl !== undefined && lastSuccessAt !== undefined
      ? await databaseSnapshot(databaseUrl, lastSuccessAt)
      : undefined;
  if (snapshot === undefined) {
    throw new Error("Provide an aggregate snapshot or managed owner URL and retention checkpoint.");
  }
  const assessment = assessRetention(snapshot);
  process.stdout.write(`${JSON.stringify(assessment)}\n`);
  if (!assessment.ok) process.exitCode = 1;
}

const entrypoint = process.argv[1];
if (entrypoint !== undefined && import.meta.url === pathToFileURL(resolve(entrypoint)).href) {
  main().catch((error) => {
    process.stderr.write(`${error instanceof Error ? error.message : "Retention check failed."}\n`);
    process.exitCode = 1;
  });
}
