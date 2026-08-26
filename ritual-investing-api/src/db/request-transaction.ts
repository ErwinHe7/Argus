import { drizzle, type NeonDatabase } from "drizzle-orm/neon-serverless";

import {
  resolveAccountContext,
  withScopedRuntimeClient,
} from "./client";
import {
  createRequestDatabaseContext,
  type RequestDatabaseContext,
} from "./request-context";
import * as schema from "./schema";

export type RequestDatabase = NeonDatabase<typeof schema>;

export interface RequestTransactionConfig {
  identityDatabaseUrl: string;
  runtimeDatabaseUrl: string;
  verifiedSubject: string;
}

export class InactivePrincipalError extends Error {
  constructor() {
    super("inactive_principal");
    this.name = "InactivePrincipalError";
  }
}

export async function withRequestTransaction<T>(
  config: RequestTransactionConfig,
  callback: (
    database: RequestDatabase,
    context: RequestDatabaseContext,
  ) => Promise<T>,
): Promise<T> {
  const resolved = await resolveAccountContext(
    config.identityDatabaseUrl,
    config.verifiedSubject,
  );
  if (resolved === null) {
    throw new InactivePrincipalError();
  }

  const context = createRequestDatabaseContext({
    ...resolved,
    principal: config.verifiedSubject,
  });
  return withScopedRuntimeClient(
    config.runtimeDatabaseUrl,
    context,
    async (client) => callback(drizzle(client, { schema }), context),
  );
}
