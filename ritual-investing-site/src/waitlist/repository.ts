import type { WaitlistQuery } from "../db/client.ts";
import { createWaitlistQuery } from "../db/client.ts";

export type WaitlistRepository = {
  submit(email: string, noticeVersion: string): Promise<void>;
  purgeExpired(): Promise<{ deletedCount: number }>;
};

type RepositoryOptions = {
  queryFactory?: (databaseUrl: string) => WaitlistQuery;
};

function aggregateCount(value: unknown): number {
  const count = typeof value === "number" ? value : typeof value === "string" ? Number(value) : Number.NaN;
  if (!Number.isSafeInteger(count) || count < 0) {
    throw new Error("The waitlist database returned an invalid aggregate.");
  }
  return count;
}

export function createWaitlistRepository(
  databaseUrl: string,
  options: RepositoryOptions = {},
): WaitlistRepository {
  const query = (options.queryFactory ?? createWaitlistQuery)(databaseUrl);
  return {
    async submit(email, noticeVersion): Promise<void> {
      await query`select waitlist_private.submit_provisional(${email}, ${noticeVersion})`;
    },
    async purgeExpired(): Promise<{ deletedCount: number }> {
      const rows = await query`select waitlist_private.purge_expired()`;
      return { deletedCount: aggregateCount(rows[0]?.purge_expired) };
    },
  };
}
