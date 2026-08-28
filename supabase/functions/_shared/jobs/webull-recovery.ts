import type { DatabaseClient } from "../../../../ritual-investing-api/src/db/database-port.ts";
import type {
  BrokerageProjectionResource,
  ProviderProjection,
} from "../../../../ritual-investing-api/src/domains/brokerage-projections/types.ts";
import type {
  BrokerageOrderDetail,
  BrokerageOrderOperation,
} from "../../../../ritual-investing-api/src/domains/brokerage-orders/types.ts";
import type { WebullProjectionRefreshPort } from "../../../../ritual-investing-api/src/jobs/webull-projection-refresh.ts";
import { assertBackgroundProjectionSafe } from "../../../../ritual-investing-api/src/jobs/webull-projection-refresh.ts";
import type { WebullReconciliationPort } from "../../../../ritual-investing-api/src/jobs/webull-reconciliation.ts";
import type { WebullTokenRefreshPort } from "../../../../ritual-investing-api/src/jobs/webull-token-refresh.ts";
import {
  type PlainWebullCredentials,
  type ProtectedWebullCredentials,
  WebullRefreshRejectedError,
  WebullTokenVault,
} from "../webull/tokens.ts";
import type { WorkerTransaction } from "./purge.ts";

type ProviderEnvironment = "sandbox" | "production";

export class WebullRecoveryBeforeEgressError extends Error {}
export class WebullRecoveryReauthorizationError extends Error {}

export type WebullExistingCommandLookup = Readonly<{
  accessToken: string;
  providerAccountId: string;
  operation: BrokerageOrderOperation;
  clientOrderId: string;
  targetOrderReference: string | null;
}>;

export type WebullExistingCommandResult = Readonly<
  | {
    kind: "resolved";
    resolution: "applied" | "authoritative_not_applied" | "superseded_by_fill";
    providerOrderReference: string;
    order: BrokerageOrderDetail;
  }
  | { kind: "not_found" }
  | { kind: "ambiguous"; reasonCode: string }
>;

/** Read/refresh/detail only. Financial command submission is not representable. */
export interface WebullRecoveryProvider {
  refresh(
    refreshToken: string,
    ownerRateLimitScope: string,
  ): Promise<PlainWebullCredentials>;
  readProjection(input: Readonly<{
    accessToken: string;
    providerAccountId: string;
    ownerRateLimitScope: string;
    resource: BrokerageProjectionResource;
  }>): Promise<ProviderProjection>;
  lookupExistingCommand(
    input: WebullExistingCommandLookup,
  ): Promise<WebullExistingCommandResult>;
}

export function createBlockedWebullRecoveryProvider(): WebullRecoveryProvider {
  const blocked = async (): Promise<never> => {
    throw new WebullRecoveryBeforeEgressError("provider_contract_unavailable");
  };
  return Object.freeze({
    refresh: blocked,
    readProjection: blocked,
    lookupExistingCommand: blocked,
  });
}

export function createBlockedWebullRecoveryPorts(): Readonly<{
  tokenRefresh: WebullTokenRefreshPort;
  projectionRefresh: WebullProjectionRefreshPort;
  reconciliation: WebullReconciliationPort;
}> {
  const blocked = async (): Promise<never> => {
    throw new Error("worker_killed");
  };
  return Object.freeze({
    tokenRefresh: Object.freeze({ refreshExistingConnection: blocked }),
    projectionRefresh: Object.freeze({ refreshExistingProjection: blocked }),
    reconciliation: Object.freeze({ inspectExistingCommand: blocked }),
  });
}

type CredentialRow = Readonly<{
  user_id: string;
  deletion_epoch: number | string;
  connection_id: string;
  provider_environment: ProviderEnvironment;
  token_version: number | string;
  key_version: number | string;
  access_ciphertext: Uint8Array;
  access_nonce: Uint8Array;
  access_tag: Uint8Array;
  refresh_ciphertext: Uint8Array;
  refresh_nonce: Uint8Array;
  refresh_tag: Uint8Array;
  wrapped_data_key: Uint8Array;
  wrapped_key_nonce: Uint8Array;
  wrapped_key_tag: Uint8Array;
  associated_data_hash: string;
  access_expires_at: Date | string;
  refresh_expires_at: Date | string;
}>;

function integer(value: number | string, name: string): number {
  const parsed = typeof value === "string" && /^\d+$/.test(value)
    ? Number(value)
    : value;
  if (!Number.isSafeInteger(parsed) || Number(parsed) < 0) {
    throw new Error(`invalid_${name}`);
  }
  return Number(parsed);
}

function date(value: Date | string, name: string): Date {
  const parsed = value instanceof Date ? value : new Date(value);
  if (!Number.isFinite(parsed.getTime())) throw new Error(`invalid_${name}`);
  return parsed;
}

function credentials(row: CredentialRow): ProtectedWebullCredentials {
  return Object.freeze({
    environment: row.provider_environment,
    userId: row.user_id,
    deletionEpoch: integer(row.deletion_epoch, "deletion_epoch"),
    connectionId: row.connection_id,
    tokenVersion: integer(row.token_version, "token_version"),
    keyVersion: integer(row.key_version, "key_version"),
    accessCiphertext: row.access_ciphertext,
    accessNonce: row.access_nonce,
    accessTag: row.access_tag,
    refreshCiphertext: row.refresh_ciphertext,
    refreshNonce: row.refresh_nonce,
    refreshTag: row.refresh_tag,
    wrappedDataKey: row.wrapped_data_key,
    wrappedKeyNonce: row.wrapped_key_nonce,
    wrappedKeyTag: row.wrapped_key_tag,
    associatedDataHash: row.associated_data_hash,
    accessExpiresAt: date(row.access_expires_at, "access_expires_at"),
    refreshExpiresAt: date(row.refresh_expires_at, "refresh_expires_at"),
  });
}

async function sha256Hex(value: string): Promise<string> {
  const digest = new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)),
  );
  return [...digest].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function safeReason(value: string): string {
  return /^[a-z][a-z0-9_]{0,63}$/.test(value)
    ? value
    : "provider_lookup_unavailable";
}

function validateOrderDetail(order: BrokerageOrderDetail): void {
  const encoded = JSON.stringify(order);
  if (
    !/^[0-9a-f-]{36}$/i.test(order.id) ||
    !/^[0-9a-f-]{36}$/i.test(order.instrument_id) ||
    order.source !== "detail" ||
    new TextEncoder().encode(encoded).byteLength > 64 * 1024 ||
    /"(?:access|refresh)?_?token"\s*:|"secret"\s*:|"raw_payload"\s*:|"reviewed_payload"\s*:/i
      .test(encoded)
  ) throw new Error("invalid_event_payload");
}

export function createWebullRecoveryPorts(config: Readonly<{
  transaction: WorkerTransaction;
  vault: WebullTokenVault;
  provider: WebullRecoveryProvider;
  now?: () => Date;
}>): Readonly<{
  tokenRefresh: WebullTokenRefreshPort;
  projectionRefresh: WebullProjectionRefreshPort;
  reconciliation: WebullReconciliationPort;
}> {
  const now = config.now ?? (() => new Date());

  const tokenRefresh: WebullTokenRefreshPort = Object.freeze({
    async refreshExistingConnection(
      input: Parameters<WebullTokenRefreshPort["refreshExistingConnection"]>[0],
    ) {
      const leaseToken = crypto.randomUUID();
      let egressStarted = false;
      let terminalized = false;
      const claimed = await config.transaction(async (database) => {
        const result = await database.query<CredentialRow & { claim_outcome: string }>(
          "select * from argus_private.claim_webull_token_refresh($1,$2,45)",
          [input.eventId, leaseToken],
        );
        return result.rows[0];
      });
      if (claimed === undefined || claimed.claim_outcome === "stale") return "stale";
      if (claimed.claim_outcome === "reauthorization_required") {
        return "reauthorization_required";
      }
      const current = credentials(claimed);
      try {
        let plain: PlainWebullCredentials;
        try {
          plain = await config.vault.openCredentials(current, {
            environment: current.environment,
            userId: current.userId,
            connectionId: current.connectionId,
            deletionEpoch: current.deletionEpoch,
          });
        } catch {
          await config.transaction((database) => database.query(
            "select argus_private.fence_webull_refresh_outcome($1,$2,$3,$4,$5,'refresh_rejected')",
            [input.eventId, current.connectionId, current.tokenVersion, current.keyVersion, current.associatedDataHash],
          ));
          terminalized = true;
          return "reauthorization_required";
        }
        if (plain.refreshExpiresAt <= now()) {
          await config.transaction((database) => database.query(
            "select argus_private.fence_webull_refresh_outcome($1,$2,$3,$4,$5,'refresh_expired')",
            [input.eventId, current.connectionId, current.tokenVersion, current.keyVersion, current.associatedDataHash],
          ));
          terminalized = true;
          return "reauthorization_required";
        }
        await input.keepAlive();
        const egressGate = await config.transaction((database) => database.query<{
          allowed: boolean;
        }>(
          "select argus_private.mark_webull_refresh_egress_started($1,$2,$3,$4,$5) as allowed",
          [input.eventId, current.connectionId, current.tokenVersion, current.keyVersion, leaseToken],
        ));
        if (egressGate.rows[0]?.allowed !== true) {
          throw new Error("deletion_epoch_changed");
        }
        egressStarted = true;
        let refreshed: PlainWebullCredentials;
        try {
          refreshed = await config.provider.refresh(
            plain.refreshToken,
            await sha256Hex(current.userId),
          );
        } catch (error) {
          if (error instanceof WebullRecoveryBeforeEgressError) {
            await config.transaction((database) => database.query(
              "select argus_private.reset_webull_refresh_before_egress($1,$2,$3,$4,$5,$6)",
              [input.eventId, current.connectionId, current.tokenVersion, current.keyVersion, current.associatedDataHash, leaseToken],
            ));
            egressStarted = false;
            throw new Error("dependency_unavailable");
          }
          const reason = error instanceof WebullRefreshRejectedError ||
              error instanceof WebullRecoveryReauthorizationError
            ? "refresh_rejected"
            : "refresh_outcome_unknown";
          await config.transaction((database) => database.query(
            "select argus_private.fence_webull_refresh_outcome($1,$2,$3,$4,$5,$6)",
            [input.eventId, current.connectionId, current.tokenVersion, current.keyVersion, current.associatedDataHash, reason],
          ));
          terminalized = true;
          return "reauthorization_required";
        }
        const next = await config.vault.protectCredentials({
          userId: current.userId,
          connectionId: current.connectionId,
          deletionEpoch: current.deletionEpoch,
          tokenVersion: current.tokenVersion + 1,
          ...refreshed,
        });
        await input.keepAlive();
        const committed = await config.transaction(async (database) => {
          const result = await database.query<{ committed: boolean }>(
            `select argus_private.commit_webull_token_refresh(
               $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20
             ) as committed`,
            [
              input.eventId, current.connectionId, current.tokenVersion,
              current.keyVersion, current.associatedDataHash, leaseToken,
              next.tokenVersion, next.keyVersion, next.accessCiphertext,
              next.accessNonce, next.accessTag, next.refreshCiphertext,
              next.refreshNonce, next.refreshTag, next.wrappedDataKey,
              next.wrappedKeyNonce, next.wrappedKeyTag,
              next.associatedDataHash,
              next.accessExpiresAt, next.refreshExpiresAt,
            ],
          );
          return result.rows[0]?.committed === true;
        });
        if (committed) {
          terminalized = true;
          return "rotated";
        }
        const fenced = await config.transaction(async (database) => {
          const result = await database.query<{ fenced: boolean }>(
            "select argus_private.fence_webull_refresh_outcome($1,$2,$3,$4,$5,'refresh_outcome_unknown') as fenced",
            [input.eventId, current.connectionId, current.tokenVersion, current.keyVersion, current.associatedDataHash],
          );
          return result.rows[0]?.fenced === true;
        });
        terminalized = true;
        return fenced ? "reauthorization_required" : "won_elsewhere";
      } finally {
        if (!egressStarted || terminalized) {
          await config.transaction((database) => database.query(
            "select argus_private.release_webull_token_refresh($1,$2)",
            [claimed.connection_id, leaseToken],
          )).catch(() => undefined);
        }
      }
    },
  });

  const projectionRefresh: WebullProjectionRefreshPort = Object.freeze({
    async refreshExistingProjection(
      input: Parameters<WebullProjectionRefreshPort["refreshExistingProjection"]>[0],
    ) {
      const leaseToken = crypto.randomUUID();
      let preserveForRetry = false;
      const claimed = await config.transaction(async (database) => {
        const result = await database.query<CredentialRow & {
          claim_outcome: string;
          lease_id: string;
          account_id: string;
          resource_type: BrokerageProjectionResource;
          provider_account_id_ciphertext: Uint8Array;
          provider_account_key_version: number | string;
        }>("select * from argus_private.claim_webull_projection_refresh($1,$2,$3,45)", [
          input.eventId,
          input.leaseId,
          leaseToken,
        ]);
        return result.rows[0];
      });
      if (claimed === undefined || claimed.claim_outcome !== "claimed") return "stale";
      const current = credentials(claimed);
      try {
        let plain: PlainWebullCredentials;
        try {
          plain = await config.vault.openCredentials(current, {
            environment: current.environment,
            userId: current.userId,
            connectionId: current.connectionId,
            deletionEpoch: current.deletionEpoch,
          });
        } catch {
          await config.transaction((database) => database.query(
            "select argus_private.mark_webull_reauthorization($1,$2,$3,$4,$5)",
            [input.eventId, current.connectionId, current.tokenVersion, current.keyVersion, current.associatedDataHash],
          ));
          return "reauthorization_required";
        }
        if (plain.accessExpiresAt <= now()) throw new Error("dependency_unavailable");
        let providerAccountId: string;
        try {
          providerAccountId = await config.vault.openProviderIdentifier(
            claimed.provider_account_id_ciphertext,
            {
              environment: current.environment,
              userId: current.userId,
              connectionId: current.connectionId,
              deletionEpoch: current.deletionEpoch,
            },
            claimed.account_id,
            integer(claimed.provider_account_key_version, "provider_account_key_version"),
          );
        } catch {
          await config.transaction((database) => database.query(
            "select argus_private.mark_webull_reauthorization($1,$2,$3,$4,$5)",
            [input.eventId, current.connectionId, current.tokenVersion, current.keyVersion, current.associatedDataHash],
          ));
          return "reauthorization_required";
        }
        await input.keepAlive();
        const egressGate = await config.transaction((database) => database.query<{
          allowed: boolean;
        }>(
          "select argus_private.authorize_webull_projection_egress($1,$2,$3,$4,$5,$6) as allowed",
          [input.eventId, input.leaseId, leaseToken, current.tokenVersion, current.keyVersion, current.associatedDataHash],
        ));
        if (egressGate.rows[0]?.allowed !== true) {
          throw new Error("deletion_epoch_changed");
        }
        let projection: ProviderProjection;
        try {
          projection = await config.provider.readProjection({
            accessToken: plain.accessToken,
            providerAccountId,
            ownerRateLimitScope: await sha256Hex(current.userId),
            resource: claimed.resource_type,
          });
        } catch (error) {
          if (error instanceof WebullRecoveryReauthorizationError) {
            await config.transaction((database) => database.query(
              "select argus_private.mark_webull_reauthorization($1,$2,$3,$4,$5)",
              [input.eventId, current.connectionId, current.tokenVersion, current.keyVersion, current.associatedDataHash],
            ));
            return "reauthorization_required";
          }
          preserveForRetry = true;
          throw new Error("dependency_unavailable");
        }
        assertBackgroundProjectionSafe(projection, now());
        await input.keepAlive();
        const result = await config.transaction((database) => database.query<{ committed: boolean }>(
          `select argus_private.commit_webull_projection_refresh(
             $1,$2,$3,$4,$5,$6,$7,$8::jsonb,$9,$10,$11,$12,$13
           ) as committed`,
          [
            input.eventId, input.leaseId, leaseToken, current.tokenVersion,
            current.keyVersion, current.associatedDataHash,
            claimed.resource_type, JSON.stringify(projection.payload),
            projection.providerObservedAt, projection.fetchedAt,
            projection.expiresAt, projection.availability,
            projection.reasonCode ?? null,
          ],
        ));
        return result.rows[0]?.committed === true ? "refreshed" : "won_elsewhere";
      } catch (error) {
        preserveForRetry = true;
        throw error;
      } finally {
        await config.transaction((database) => database.query(
          "select argus_private.release_webull_projection_refresh($1,$2,$3,$4)",
          [input.eventId, input.leaseId, leaseToken, preserveForRetry],
        )).catch(() => undefined);
      }
    },
  });

  const reconciliation: WebullReconciliationPort = Object.freeze({
    async inspectExistingCommand(
      input: Parameters<WebullReconciliationPort["inspectExistingCommand"]>[0],
    ) {
      const claimed = await config.transaction(async (database) => {
        const result = await database.query<CredentialRow & {
          claim_outcome: string;
          command_id: string;
          account_id: string;
          operation: BrokerageOrderOperation;
          client_order_id: string;
          target_order_id: string | null;
          provider_account_id_ciphertext: Uint8Array;
          provider_account_key_version: number | string;
          target_order_ref_ciphertext: Uint8Array | null;
          target_order_ref_key_version: number | string | null;
        }>("select * from argus_private.claim_webull_command_reconciliation($1,$2)", [
          input.eventId,
          input.commandId,
        ]);
        return result.rows[0];
      });
      if (claimed === undefined || claimed.claim_outcome === "stale") return "stale";
      if (claimed.claim_outcome === "manual_review") return "manual_review";
      const current = credentials(claimed);
      const ownership = {
        environment: current.environment,
        userId: current.userId,
        connectionId: current.connectionId,
        deletionEpoch: current.deletionEpoch,
      } as const;
      let plain: PlainWebullCredentials;
      let providerAccountId: string;
      let targetOrderReference: string | null;
      try {
        plain = await config.vault.openCredentials(current, ownership);
      } catch {
        await config.transaction((database) => database.query(
          "select argus_private.mark_webull_reconciliation_reauthorization($1,$2,$3,$4,$5,$6)",
          [input.eventId, input.commandId, current.tokenVersion, current.keyVersion, current.associatedDataHash, "provider_authorization_invalid"],
        ));
        return "reauthorization_required";
      }
      if (plain.accessExpiresAt <= now()) throw new Error("dependency_unavailable");
      try {
        providerAccountId = await config.vault.openProviderIdentifier(
          claimed.provider_account_id_ciphertext,
          ownership,
          claimed.account_id,
          integer(claimed.provider_account_key_version, "provider_account_key_version"),
        );
        targetOrderReference = claimed.target_order_id === null ||
            claimed.target_order_ref_ciphertext === null ||
            claimed.target_order_ref_key_version === null
          ? null
          : await config.vault.openProviderOrderReference(
            claimed.target_order_ref_ciphertext,
            ownership,
            claimed.account_id,
            claimed.target_order_id,
            integer(claimed.target_order_ref_key_version, "target_order_ref_key_version"),
          );
      } catch {
        await config.transaction((database) => database.query(
          "select argus_private.mark_webull_reconciliation_reauthorization($1,$2,$3,$4,$5,$6)",
          [input.eventId, input.commandId, current.tokenVersion, current.keyVersion, current.associatedDataHash, "provider_authorization_invalid"],
        ));
        return "reauthorization_required";
      }
      await input.keepAlive();
      const egressGate = await config.transaction((database) => database.query<{
        allowed: boolean;
      }>(
        "select argus_private.authorize_webull_reconciliation_egress($1,$2,$3,$4,$5) as allowed",
        [input.eventId, input.commandId, current.tokenVersion, current.keyVersion, current.associatedDataHash],
      ));
      if (egressGate.rows[0]?.allowed !== true) {
        throw new Error("deletion_epoch_changed");
      }
      let detail: WebullExistingCommandResult;
      try {
        detail = await config.provider.lookupExistingCommand({
          accessToken: plain.accessToken,
          providerAccountId,
          operation: claimed.operation,
          clientOrderId: claimed.client_order_id,
          targetOrderReference,
        });
      } catch (error) {
        if (error instanceof WebullRecoveryReauthorizationError) {
          await config.transaction((database) => database.query(
            "select argus_private.mark_webull_reconciliation_reauthorization($1,$2,$3,$4,$5,$6)",
            [input.eventId, input.commandId, current.tokenVersion, current.keyVersion, current.associatedDataHash, "provider_authorization_invalid"],
          ));
          return "reauthorization_required";
        }
        detail = { kind: "ambiguous", reasonCode: "provider_lookup_unavailable" };
      }
      await input.keepAlive();
      if (detail.kind === "not_found" || detail.kind === "ambiguous") {
        const reason = detail.kind === "not_found"
          ? "provider_order_not_found"
          : safeReason(detail.reasonCode);
        const result = await config.transaction((database) => database.query<{ outcome: string }>(
          "select argus_private.record_webull_reconciliation_retry($1,$2,$3,$4,$5,$6) as outcome",
          [input.eventId, input.commandId, current.tokenVersion, current.keyVersion, current.associatedDataHash, reason],
        ));
        if (result.rows[0]?.outcome === "manual_review") return "manual_review";
        throw new Error("dependency_unavailable");
      }
      validateOrderDetail(detail.order);
      const sealedReference = await config.vault.protectProviderOrderReference(
        ownership,
        claimed.account_id,
        detail.order.id,
        detail.providerOrderReference,
      );
      const referenceHash = await sha256Hex(detail.providerOrderReference);
      const result = await config.transaction((database) => database.query<{ committed: boolean }>(
        `select argus_private.commit_webull_reconciliation(
           $1,$2,$3,$4,$5,$6,$7,$8,$9,$10::jsonb,$11,$12,$13,$14,$15,$16
         ) as committed`,
        [
          input.eventId, input.commandId, current.tokenVersion,
          current.keyVersion, current.associatedDataHash,
          detail.resolution, detail.order.id, detail.order.state,
          detail.order.filled_quantity, JSON.stringify(detail.order),
          detail.order.provider_observed_at, detail.order.fetched_at,
          sealedReference, referenceHash, config.vault.activeKeyVersion,
          detail.order.instrument_id,
        ],
      ));
      if (result.rows[0]?.committed === true) return "resolved";
      await config.transaction((database) => database.query(
        "select argus_private.terminalize_webull_recovery_dead_letter($1,$2)",
        [input.eventId, "reconciliation_commit_lost"],
      ));
      return "manual_review";
    },
  });

  return Object.freeze({ tokenRefresh, projectionRefresh, reconciliation });
}

// Keeps the imported DatabaseClient part of this adapter's public audit seam:
// every provider result is persisted only through a fresh WorkerTransaction.
export type WebullRecoveryDatabaseClient = DatabaseClient;
