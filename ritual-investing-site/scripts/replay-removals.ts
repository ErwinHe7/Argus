import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import process from "node:process";

import { createWaitlistQuery } from "../src/db/client.ts";
import {
  denialDigest,
  FileDenialJournal,
  normalizeWaitlistEmail,
  type DenialJournal,
  type WaitlistEnvironment,
} from "./record-removal.ts";

export type ReplayMaintenance = {
  replayDenial(normalizedEmail: string, deletedAt: string): Promise<number>;
  purgeExpired(): Promise<number>;
};

type ReplayInput = {
  trafficGated: boolean;
  environment: WaitlistEnvironment;
  hmacKey: string;
  emails: string[];
  journal: DenialJournal;
  maintenance: ReplayMaintenance;
};

export async function replayVerifiedRemovals(input: ReplayInput): Promise<{
  denialCount: number;
  retentionCount: number;
}> {
  if (!input.trafficGated) {
    throw new Error("Waitlist traffic must be gated before restore replay.");
  }
  const entries = await input.journal.read(input.environment);
  const secureInputs = new Map<string, string>();
  for (const email of input.emails) {
    const normalized = normalizeWaitlistEmail(email);
    secureInputs.set(denialDigest(normalized, input.environment, input.hmacKey), normalized);
  }
  const missing = entries.some((entry) => !secureInputs.has(entry.digest));
  if (missing) {
    throw new Error("Secure replay input is required for every keyed denial entry.");
  }

  let denialCount = 0;
  for (const entry of [...entries].sort((left, right) => left.deletedAt.localeCompare(right.deletedAt))) {
    const normalized = secureInputs.get(entry.digest);
    if (normalized === undefined) throw new Error("Secure replay input is incomplete.");
    denialCount += await input.maintenance.replayDenial(normalized, entry.deletedAt);
  }
  const retentionCount = await input.maintenance.purgeExpired();
  return { denialCount, retentionCount };
}

function argument(name: string): string | undefined {
  const index = process.argv.indexOf(name);
  return index < 0 ? undefined : process.argv[index + 1];
}

function environmentArgument(): WaitlistEnvironment {
  const value = argument("--environment");
  if (value !== "production" && value !== "beta") throw new Error("A production or beta environment is required.");
  return value;
}

function aggregate(value: unknown): number {
  const count = typeof value === "number" ? value : typeof value === "string" ? Number(value) : Number.NaN;
  if (!Number.isSafeInteger(count) || count < 0) throw new Error("The database returned an invalid replay aggregate.");
  return count;
}

async function main(): Promise<void> {
  const environment = environmentArgument();
  const emailsFile = argument("--emails-file");
  const journalFile = argument("--journal-file");
  const databaseUrl = process.env.WAITLIST_MAINTENANCE_DATABASE_URL;
  const hmacKey = process.env.WAITLIST_DENIAL_HMAC_KEY;
  if (!process.argv.includes("--traffic-gated")) throw new Error("A traffic-gated assertion is required.");
  if (emailsFile === undefined || journalFile === undefined || databaseUrl === undefined || hmacKey === undefined) {
    throw new Error("Restore-replay inputs and maintenance capabilities are incomplete.");
  }
  const emails = (await readFile(emailsFile, "utf8")).split(/\r?\n/u).map((line) => line.trim()).filter(Boolean);
  const query = createWaitlistQuery(databaseUrl);
  const result = await replayVerifiedRemovals({
    trafficGated: true,
    environment,
    hmacKey,
    emails,
    journal: new FileDenialJournal(journalFile, environment),
    maintenance: {
      async replayDenial(normalizedEmail, deletedAt): Promise<number> {
        const rows = await query`select waitlist_private.replay_denial(${normalizedEmail}, ${deletedAt}::timestamptz) as replayed`;
        return aggregate(rows[0]?.replayed);
      },
      async purgeExpired(): Promise<number> {
        const rows = await query`select waitlist_private.purge_expired() as purged`;
        return aggregate(rows[0]?.purged);
      },
    },
  });
  process.stdout.write(JSON.stringify({ environment, ...result }) + "\n");
}

const entrypoint = process.argv[1];
if (entrypoint !== undefined && import.meta.url === pathToFileURL(resolve(entrypoint)).href) {
  main().catch(() => {
    process.stderr.write("Restore replay failed. No address or credential details were logged.\n");
    process.exitCode = 1;
  });
}
