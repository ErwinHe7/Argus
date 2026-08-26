import { createHmac } from "node:crypto";
import { readFile, rename, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import process from "node:process";

import { createWaitlistQuery } from "../src/db/client.ts";

export type WaitlistEnvironment = "production" | "beta";

export type DenialJournalEntry = {
  version: "waitlist-denial-v1";
  environment: WaitlistEnvironment;
  digest: string;
  deletedAt: string;
};

export interface DenialJournal {
  read(environment: WaitlistEnvironment): Promise<DenialJournalEntry[]>;
  put(entry: DenialJournalEntry): Promise<void>;
}

type JournalDocument = {
  version: "waitlist-denial-journal-v1";
  environment: WaitlistEnvironment;
  entries: DenialJournalEntry[];
};

export function normalizeWaitlistEmail(email: string): string {
  const normalized = email.trim().toLowerCase();
  if (
    normalized.length < 3 ||
    normalized.length > 254 ||
    !/^[^\s@]+@[^\s@]+$/u.test(normalized)
  ) {
    throw new Error("The verified address is invalid.");
  }
  return normalized;
}

export function denialDigest(
  normalizedEmail: string,
  environment: WaitlistEnvironment,
  hmacKey: string,
): string {
  if (Buffer.byteLength(hmacKey, "utf8") < 32) {
    throw new Error("The denial-journal HMAC key must contain at least 32 bytes.");
  }
  return createHmac("sha256", hmacKey)
    .update(`just-build-this:waitlist-denial:v1:${environment}:${normalizedEmail}`)
    .digest("hex");
}

function isEntry(value: unknown): value is DenialJournalEntry {
  if (typeof value !== "object" || value === null) return false;
  const candidate = value as Partial<DenialJournalEntry>;
  return (
    candidate.version === "waitlist-denial-v1" &&
    (candidate.environment === "production" || candidate.environment === "beta") &&
    typeof candidate.digest === "string" &&
    /^[a-f0-9]{64}$/.test(candidate.digest) &&
    typeof candidate.deletedAt === "string" &&
    canonicalRemovalTimestamp(candidate.deletedAt) === candidate.deletedAt
  );
}

export function canonicalRemovalTimestamp(value: string): string {
  const match = /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d{1,6}))?Z$/u.exec(value);
  if (match === null) throw new Error("The database removal timestamp is invalid.");
  const prefix = match[1];
  const fraction = (match[2] ?? "").padEnd(6, "0");
  const canonical = `${prefix}.${fraction}Z`;
  if (!Number.isFinite(Date.parse(`${prefix}.${fraction.slice(0, 3)}Z`))) {
    throw new Error("The database removal timestamp is invalid.");
  }
  return canonical;
}

export class FileDenialJournal implements DenialJournal {
  constructor(
    private readonly path: string,
    private readonly environment: WaitlistEnvironment,
  ) {}

  private async document(): Promise<JournalDocument> {
    try {
      const parsed = JSON.parse(await readFile(this.path, "utf8")) as Partial<JournalDocument>;
      if (
        parsed.version !== "waitlist-denial-journal-v1" ||
        parsed.environment !== this.environment ||
        !Array.isArray(parsed.entries) ||
        !parsed.entries.every(isEntry) ||
        parsed.entries.some((entry) => entry.environment !== this.environment)
      ) {
        throw new Error("The denial journal is invalid for this environment.");
      }
      return parsed as JournalDocument;
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === "ENOENT") {
        return { version: "waitlist-denial-journal-v1", environment: this.environment, entries: [] };
      }
      throw error;
    }
  }

  async read(environment: WaitlistEnvironment): Promise<DenialJournalEntry[]> {
    if (environment !== this.environment) throw new Error("The denial-journal environment does not match.");
    return (await this.document()).entries;
  }

  async put(entry: DenialJournalEntry): Promise<void> {
    if (entry.environment !== this.environment) throw new Error("The denial-journal environment does not match.");
    const canonicalEntry = { ...entry, deletedAt: canonicalRemovalTimestamp(entry.deletedAt) };
    const document = await this.document();
    const existing = document.entries.find((candidate) => candidate.digest === canonicalEntry.digest);
    if (existing === undefined) {
      document.entries.push(canonicalEntry);
    } else if (canonicalEntry.deletedAt > canonicalRemovalTimestamp(existing.deletedAt)) {
      existing.deletedAt = canonicalEntry.deletedAt;
    }
    document.entries.sort((left, right) => left.digest.localeCompare(right.digest));
    const temporary = `${this.path}.next`;
    await writeFile(temporary, JSON.stringify(document) + "\n", { encoding: "utf8", mode: 0o600 });
    await rename(temporary, this.path);
  }
}

export type RemovalMaintenance = {
  removeVerified(normalizedEmail: string): Promise<string | null>;
};

type RecordRemovalInput = {
  mailboxPossessionVerified: boolean;
  environment: WaitlistEnvironment;
  email: string;
  hmacKey: string;
  journal: DenialJournal;
  maintenance: RemovalMaintenance;
};

export async function recordVerifiedRemoval(input: RecordRemovalInput): Promise<{
  status: "recorded";
  digest: string;
}> {
  if (!input.mailboxPossessionVerified) {
    throw new Error("Mailbox possession must be verified before recording a removal.");
  }
  const normalized = normalizeWaitlistEmail(input.email);
  const digest = denialDigest(normalized, input.environment, input.hmacKey);
  const removedAt = await input.maintenance.removeVerified(normalized);
  if (removedAt === null) {
    throw new Error("The database did not return a trusted removal timestamp.");
  }
  const deletedAt = canonicalRemovalTimestamp(removedAt);
  await input.journal.put({
    version: "waitlist-denial-v1",
    environment: input.environment,
    digest,
    deletedAt,
  });
  return { status: "recorded", digest };
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

async function main(): Promise<void> {
  const environment = environmentArgument();
  const emailFile = argument("--email-file");
  const journalFile = argument("--journal-file");
  const databaseUrl = process.env.WAITLIST_MAINTENANCE_DATABASE_URL;
  const hmacKey = process.env.WAITLIST_DENIAL_HMAC_KEY;
  if (!process.argv.includes("--mailbox-possession-verified")) {
    throw new Error("Mailbox-possession verification assertion is required.");
  }
  if (emailFile === undefined || journalFile === undefined || databaseUrl === undefined || hmacKey === undefined) {
    throw new Error("Removal inputs and maintenance capabilities are incomplete.");
  }
  const email = (await readFile(emailFile, "utf8")).trim();
  const query = createWaitlistQuery(databaseUrl);
  const result = await recordVerifiedRemoval({
    mailboxPossessionVerified: true,
    environment,
    email,
    hmacKey,
    journal: new FileDenialJournal(journalFile, environment),
    maintenance: {
      async removeVerified(normalizedEmail): Promise<string | null> {
        const rows = await query`
          select to_char(
            waitlist_private.remove_verified(${normalizedEmail}) at time zone 'UTC',
            'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
          ) as removed_at
        `;
        const value = rows[0]?.removed_at;
        return typeof value === "string" ? value : null;
      },
    },
  });
  process.stdout.write(JSON.stringify({ status: result.status, environment, digest: result.digest }) + "\n");
}

const entrypoint = process.argv[1];
if (entrypoint !== undefined && import.meta.url === pathToFileURL(resolve(entrypoint)).href) {
  main().catch(() => {
    process.stderr.write("Verified removal failed. No address or credential details were logged.\n");
    process.exitCode = 1;
  });
}
