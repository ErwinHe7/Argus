import { neon, type NeonQueryFunction } from "@neondatabase/serverless";
import { drizzle } from "drizzle-orm/neon-http";

import * as schema from "./schema.ts";

export type WaitlistQuery = NeonQueryFunction<false, false>;

export function createWaitlistQuery(databaseUrl: string): WaitlistQuery {
  if (databaseUrl.trim().length === 0) {
    throw new Error("The waitlist database capability is unavailable.");
  }
  return neon(databaseUrl);
}

export function createWaitlistDatabase(databaseUrl: string) {
  const client = createWaitlistQuery(databaseUrl);
  return drizzle(client, { schema });
}
