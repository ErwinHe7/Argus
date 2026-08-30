import type { DatabasePool, DatabaseTransaction } from "./database-port.ts";
import type { VerifiedRequestClaims } from "./request-claims.ts";
import { RepositoryNotFoundError } from "./repository-errors.ts";
export {
  RepositoryNotFoundError,
  RepositoryRevisionConflictError,
  RepositoryStepUpRequiredError,
} from "./repository-errors.ts";
import {
  type RequestTransactionConfig,
  withActiveStaffRequestTransaction,
  withAnonymousRequestTransaction,
  withCapabilityStaffRequestTransaction,
  withEditorialStaffRequestTransaction,
  withMemberRequestTransaction,
  withRequestTransaction,
  withStaffRequestTransaction,
} from "./request-transaction.ts";

export type JsonObject = Record<string, unknown>;

export type PrivacySignedStorage = Readonly<{
  createSignedUrl(
    bucket: string,
    path: string,
    expiresInSeconds: number,
  ): Promise<string>;
  getStream(
    bucket: string,
    path: string,
  ): Promise<Readonly<{
    body: ReadableStream<Uint8Array>;
    contentType: string;
  }> | null>;
}>;

export type SupabaseRepositoryBinding = Readonly<{
  pool: DatabasePool;
  claims: VerifiedRequestClaims;
  signedStorage?: PrivacySignedStorage;
}>;

function config(binding: SupabaseRepositoryBinding): RequestTransactionConfig {
  return { pool: binding.pool, verifiedClaims: binding.claims };
}

export function ownerTransaction<T>(
  binding: SupabaseRepositoryBinding,
  callback: (database: DatabaseTransaction) => Promise<T>,
): Promise<T> {
  return withMemberRequestTransaction(config(binding), callback);
}

export function legacyOwnerTransaction<T>(
  binding: SupabaseRepositoryBinding,
  callback: (database: DatabaseTransaction) => Promise<T>,
): Promise<T> {
  return withRequestTransaction(config(binding), callback);
}

export function editorialStaffTransaction<T>(
  binding: SupabaseRepositoryBinding,
  permission: string,
  callback: (database: DatabaseTransaction) => Promise<T>,
): Promise<T> {
  return withEditorialStaffRequestTransaction(
    config(binding),
    permission,
    callback,
  );
}

export function staffTransaction<T>(
  binding: SupabaseRepositoryBinding,
  permission: string,
  callback: (database: DatabaseTransaction) => Promise<T>,
): Promise<T> {
  return withStaffRequestTransaction(config(binding), permission, callback);
}

export function capabilityStaffTransaction<T>(
  binding: SupabaseRepositoryBinding,
  permission: string,
  callback: (database: DatabaseTransaction) => Promise<T>,
): Promise<T> {
  return withCapabilityStaffRequestTransaction(
    config(binding),
    permission,
    callback,
  );
}

export function activeStaffTransaction<T>(
  binding: SupabaseRepositoryBinding,
  callback: (database: DatabaseTransaction) => Promise<T>,
): Promise<T> {
  return withActiveStaffRequestTransaction(config(binding), callback);
}

export function anonymousTransaction<T>(
  pool: DatabasePool,
  callback: (database: DatabaseTransaction) => Promise<T>,
): Promise<T> {
  return withAnonymousRequestTransaction(pool, callback);
}

export function first<Row>(rows: Row[]): Row {
  const row = rows[0];
  if (row === undefined) throw new RepositoryNotFoundError();
  return row;
}
