import type { WithBrokerageProjectionRepository } from "./ports.ts";
import {
  type BrokerageAccountContext,
  BrokerageProjectionError,
  type BrokerageProjectionResource,
  type BrokerageProjectionResponse,
  type BrokerageReadState,
  type ProviderProjection,
  type StoredProjection,
} from "./types.ts";

export interface BrokerageProjectionProvider {
  read(
    input: Readonly<{
      context: BrokerageAccountContext;
      resource: BrokerageProjectionResource;
    }>,
  ): Promise<ProviderProjection>;
}

function response(
  accountId: string,
  resource: BrokerageProjectionResource,
  projection: StoredProjection | null,
  state: BrokerageReadState,
  reason: string | null,
): BrokerageProjectionResponse {
  return Object.freeze({
    account_id: accountId,
    resource,
    generation: projection?.generation ?? null,
    state,
    reason,
    provider_observed_at: projection?.providerObservedAt?.toISOString() ?? null,
    fetched_at: projection?.fetchedAt.toISOString() ?? null,
    expires_at: projection?.expiresAt.toISOString() ?? null,
    data: projection?.payload ?? null,
  });
}

function projectionState(
  projection: StoredProjection,
  now: Date,
): BrokerageReadState {
  // Expiry dominates partial availability. A partially complete payload can
  // be useful while current, but it must never disguise stale authority.
  if (projection.expiresAt.getTime() <= now.getTime()) return "stale";
  if (projection.availability === "stale") return "stale";
  if (projection.availability === "partial") return "partial";
  if (projection.availability === "unavailable") return "unavailable";
  const empty = Array.isArray(projection.payload)
    ? projection.payload.length === 0
    : projection.payload !== null &&
      typeof projection.payload === "object" &&
      Object.keys(projection.payload).length === 0;
  return empty ? "empty" : "fresh";
}

function errorState(error: unknown): BrokerageReadState {
  if (error instanceof BrokerageProjectionError) {
    if (error.code === "offline") return "offline";
    if (error.code === "rate_limited") return "rate_limited";
    if (error.code === "reauthorization_required") {
      return "reauthorization_required";
    }
  }
  return "unavailable";
}

function assertProjectionPayloadSafe(value: unknown): void {
  const serialized = JSON.stringify(value);
  if (
    serialized === undefined ||
    new TextEncoder().encode(serialized).length > 512 * 1024
  ) {
    throw new BrokerageProjectionError("provider_contract_unavailable");
  }
  const visit = (entry: unknown, depth: number): void => {
    if (depth > 12) {
      throw new BrokerageProjectionError("provider_contract_unavailable");
    }
    if (
      entry === null ||
      typeof entry === "string" ||
      typeof entry === "boolean"
    ) return;
    if (typeof entry === "number") {
      if (!Number.isSafeInteger(entry)) {
        throw new BrokerageProjectionError("provider_contract_unavailable");
      }
      return;
    }
    if (Array.isArray(entry)) {
      for (const child of entry) visit(child, depth + 1);
      return;
    }
    if (typeof entry !== "object") {
      throw new BrokerageProjectionError("provider_contract_unavailable");
    }
    for (const [key, child] of Object.entries(entry)) {
      if (
        key === "__proto__" ||
        key === "constructor" ||
        key === "prototype" ||
        /^(?:provider|webull).*(?:_?id|identifier|reference)$/i.test(key) ||
        /(?:token|secret|authorization_code|raw_payload)/i.test(key)
      ) {
        throw new BrokerageProjectionError("provider_contract_unavailable");
      }
      visit(child, depth + 1);
    }
  };
  visit(value, 0);
}

export function createBrokerageProjectionService(
  input: Readonly<{
    withRepository: WithBrokerageProjectionRepository;
    provider: BrokerageProjectionProvider;
    now?: () => Date;
    leaseMilliseconds?: number;
    retentionMilliseconds?: number;
  }>,
) {
  const now = input.now ?? (() => new Date());
  const leaseMilliseconds = input.leaseMilliseconds ?? 15_000;
  const retentionMilliseconds = input.retentionMilliseconds ?? 30 * 86_400_000;
  const withRepository = input.withRepository;

  return Object.freeze({
    listAccounts: () =>
      withRepository((repository) => repository.listAccounts()),
    read: async (
      accountId: string,
      resource: BrokerageProjectionResource,
      forceRefresh = false,
    ): Promise<BrokerageProjectionResponse> => {
      const context = await withRepository((repository) =>
        repository.account(accountId)
      );
      const currentTime = now();
      const cached = await withRepository((repository) =>
        repository.latest(accountId, resource)
      );
      if (context.connectionStatus === "disconnected") {
        return response(
          accountId,
          resource,
          cached,
          "disconnected",
          "connection_disconnected",
        );
      }
      if (context.connectionStatus === "reauthorization_required") {
        return response(
          accountId,
          resource,
          cached,
          "reauthorization_required",
          "provider_authorization_invalid",
        );
      }
      if (context.connectionStatus !== "connected") {
        return response(
          accountId,
          resource,
          cached,
          "unavailable",
          "connection_unavailable",
        );
      }
      if (!forceRefresh && cached !== null) {
        const state = projectionState(cached, currentTime);
        if (state === "fresh" || state === "empty" || state === "partial") {
          return response(
            accountId,
            resource,
            cached,
            state,
            cached.reasonCode,
          );
        }
      }

      const leaseToken = crypto.randomUUID();
      const acquired = await withRepository((repository) =>
        repository.acquireRefreshLease({
          context,
          resource,
          leaseToken,
          leasedUntil: new Date(currentTime.getTime() + leaseMilliseconds),
        })
      );
      if (!acquired) {
        return response(
          accountId,
          resource,
          cached,
          cached === null ? "unavailable" : "stale",
          "refresh_in_progress",
        );
      }
      try {
        const projection = await input.provider.read({ context, resource });
        const validationTime = now();
        const maximumProjectionTtl = 5 * 60_000;
        if (
          !Number.isFinite(projection.fetchedAt.getTime()) ||
          !Number.isFinite(projection.expiresAt.getTime()) ||
          projection.expiresAt < projection.fetchedAt ||
          projection.expiresAt.getTime() - projection.fetchedAt.getTime() >
            maximumProjectionTtl ||
          Math.abs(
              projection.fetchedAt.getTime() - validationTime.getTime(),
            ) > 30_000 ||
          (projection.providerObservedAt !== null &&
            (!Number.isFinite(projection.providerObservedAt.getTime()) ||
              projection.providerObservedAt > projection.fetchedAt ||
              projection.providerObservedAt.getTime() >
                validationTime.getTime() + 30_000))
        ) {
          throw new BrokerageProjectionError("provider_contract_unavailable");
        }
        assertProjectionPayloadSafe(projection.payload);
        const stored = await withRepository((repository) =>
          repository.appendGeneration({
            context,
            resource,
            leaseToken,
            projection,
            purgeAfter: new Date(
              projection.fetchedAt.getTime() + retentionMilliseconds,
            ),
          })
        );
        return response(
          accountId,
          resource,
          stored,
          projectionState(stored, validationTime),
          stored.reasonCode,
        );
      } catch (error) {
        if (
          error instanceof BrokerageProjectionError &&
          error.code === "account_removed"
        ) {
          await withRepository((repository) =>
            repository.invalidateAccount(accountId)
          );
        } else if (
          error instanceof BrokerageProjectionError &&
          error.code === "reauthorization_required"
        ) {
          await withRepository((repository) =>
            repository.requireReauthorization(context.connectionId)
          );
        } else if (
          error instanceof BrokerageProjectionError &&
          error.code === "refresh_fenced"
        ) {
          // An in-flight disconnect/reconnect/deletion is authoritative. Do
          // not return bytes obtained for the old ownership generation.
          return response(
            accountId,
            resource,
            null,
            "unavailable",
            "refresh_fenced",
          );
        }
        return response(
          accountId,
          resource,
          cached,
          errorState(error),
          error instanceof BrokerageProjectionError
            ? error.code
            : "provider_unavailable",
        );
      } finally {
        try {
          await withRepository((repository) =>
            repository.releaseRefreshLease({
              accountId,
              resource,
              leaseToken,
            })
          );
        } catch {
          // Lease expiry is the recovery path. A release outage cannot replace
          // a successfully fenced/stored response or disclose provider data.
        }
      }
    },
  });
}

export type BrokerageProjectionService = ReturnType<
  typeof createBrokerageProjectionService
>;

export function createBlockedBrokerageProjectionProvider(): BrokerageProjectionProvider {
  return Object.freeze({
    read: async () => {
      throw new BrokerageProjectionError("provider_contract_unavailable");
    },
  });
}
