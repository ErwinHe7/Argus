import {
  type DatabasePool,
  type DatabaseTransaction,
  withDatabaseTransaction,
} from "./database-port.ts";
import {
  createVerifiedRequestClaims,
  type VerifiedRequestClaims,
} from "./request-context.ts";

export type RequestDatabase = DatabaseTransaction;

export interface RequestTransactionConfig {
  pool: DatabasePool;
  verifiedClaims: VerifiedRequestClaims;
}

type RequestRole =
  | "argus_runtime"
  | "argus_member"
  | "argus_callback"
  | "argus_staff";

export class InactivePrincipalError extends Error {
  constructor() {
    super("inactive_principal");
    this.name = "InactivePrincipalError";
  }
}

async function withVerifiedRequestTransaction<T>(
  config: RequestTransactionConfig,
  role: RequestRole,
  callback: (
    database: RequestDatabase,
    context: VerifiedRequestClaims,
  ) => Promise<T>,
): Promise<T> {
  const verifiedClaims = createVerifiedRequestClaims(config.verifiedClaims);
  return withDatabaseTransaction(
    config.pool,
    role,
    async (database) => callback(database, verifiedClaims),
    async (database) => {
      await database.query(
        "select argus_private.install_request_context($1::uuid, $2::uuid, $3::text)",
        [
          verifiedClaims.userId,
          verifiedClaims.sessionId,
          verifiedClaims.aal,
        ],
      );
    },
  );
}

export function withRequestTransaction<T>(
  config: RequestTransactionConfig,
  callback: (
    database: RequestDatabase,
    context: VerifiedRequestClaims,
  ) => Promise<T>,
): Promise<T> {
  return withVerifiedRequestTransaction(config, "argus_runtime", callback);
}

export function withMemberRequestTransaction<T>(
  config: RequestTransactionConfig,
  callback: (
    database: RequestDatabase,
    context: VerifiedRequestClaims,
  ) => Promise<T>,
): Promise<T> {
  return withVerifiedRequestTransaction(config, "argus_member", callback);
}

export function withCallbackRequestTransaction<T>(
  config: RequestTransactionConfig,
  callback: (
    database: RequestDatabase,
    context: VerifiedRequestClaims,
  ) => Promise<T>,
): Promise<T> {
  return withVerifiedRequestTransaction(config, "argus_callback", callback);
}

/**
 * Runs an auth-free published-content read. No JWT claims are installed, so
 * forced RLS can expose only policies that explicitly allow published rows.
 */
export async function withAnonymousRequestTransaction<T>(
  pool: DatabasePool,
  callback: (database: RequestDatabase) => Promise<T>,
): Promise<T> {
  return withDatabaseTransaction(pool, "argus_runtime", callback);
}

export class StaffAuthorizationError extends Error {
  constructor() {
    super("staff_authorization_required");
    this.name = "StaffAuthorizationError";
  }
}

async function assertLiveStaffSession(
  database: RequestDatabase,
  context: VerifiedRequestClaims,
): Promise<void> {
  const authorization = await database.query<{ live: boolean }>(
    `select argus_private.has_live_staff_session(
       $1::uuid,$2::uuid
     ) as live`,
    [context.userId, context.sessionId],
  );
  if (authorization.rows[0]?.live !== true) {
    throw new StaffAuthorizationError();
  }
}

export async function withActiveCapabilityStaffRequestTransaction<T>(
  config: RequestTransactionConfig,
  callback: (
    database: RequestDatabase,
    context: VerifiedRequestClaims,
  ) => Promise<T>,
): Promise<T> {
  return withVerifiedRequestTransaction(
    config,
    "argus_staff",
    async (database, context) => {
      await assertLiveStaffSession(database, context);
      return callback(database, context);
    },
  );
}

export async function withActiveEditorialStaffRequestTransaction<T>(
  config: RequestTransactionConfig,
  callback: (
    database: RequestDatabase,
    context: VerifiedRequestClaims,
  ) => Promise<T>,
): Promise<T> {
  return withActiveCapabilityStaffRequestTransaction(config, callback);
}

export async function withCapabilityStaffRequestTransaction<T>(
  config: RequestTransactionConfig,
  permission: string,
  callback: (
    database: RequestDatabase,
    context: VerifiedRequestClaims,
  ) => Promise<T>,
): Promise<T> {
  if (!/^[a-z][a-z0-9_.:-]{0,127}$/.test(permission)) {
    throw new StaffAuthorizationError();
  }
  return withActiveCapabilityStaffRequestTransaction(
    config,
    async (database, context) => {
      const authorization = await database.query<{ allowed: boolean }>(
        "select argus_private.has_staff_permission($1::text) as allowed",
        [permission],
      );
      if (authorization.rows[0]?.allowed !== true) {
        throw new StaffAuthorizationError();
      }
      return callback(database, context);
    },
  );
}

export async function withEditorialStaffRequestTransaction<T>(
  config: RequestTransactionConfig,
  permission: string,
  callback: (
    database: RequestDatabase,
    context: VerifiedRequestClaims,
  ) => Promise<T>,
): Promise<T> {
  return withCapabilityStaffRequestTransaction(config, permission, callback);
}

/**
 * Runs a staff request only while the JWT's concrete Supabase Auth session is
 * still live. This prevents an unexpired JWT from surviving global sign-out or
 * server-side session deletion at the admin boundary.
 */
export async function withActiveStaffRequestTransaction<T>(
  config: RequestTransactionConfig,
  callback: (
    database: RequestDatabase,
    context: VerifiedRequestClaims,
  ) => Promise<T>,
): Promise<T> {
  return withRequestTransaction(config, async (database, context) => {
    await assertLiveStaffSession(database, context);
    return callback(database, context);
  });
}

export async function withStaffRequestTransaction<T>(
  config: RequestTransactionConfig,
  permission: string,
  callback: (
    database: RequestDatabase,
    context: VerifiedRequestClaims,
  ) => Promise<T>,
): Promise<T> {
  if (!/^[a-z][a-z0-9_.:-]{0,127}$/.test(permission)) {
    throw new StaffAuthorizationError();
  }
  return withActiveStaffRequestTransaction(config, async (database, context) => {
    const authorization = await database.query<{ allowed: boolean }>(
      "select argus_private.has_staff_permission($1::text) as allowed",
      [permission],
    );
    if (authorization.rows[0]?.allowed !== true) {
      throw new StaffAuthorizationError();
    }
    return callback(database, context);
  });
}
