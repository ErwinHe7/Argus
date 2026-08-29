import type {
  BrokerageOrderRepository,
  WithBrokerageOrderRepository,
} from "./ports.ts";
import {
  normalizeCancelOrderIntent,
  normalizeModifyOrderIntent,
  normalizePlaceOrderIntent,
} from "./normalization.ts";
import { normalizeBrokerageReasonCode } from "./reason-codes.ts";
import {
  BROKERAGE_ORDER_POLICY_VERSION,
  type BrokerageOrderAuthority,
  type BrokerageOrderCommand,
  BrokerageOrderError,
  type BrokerageOrderOperation,
  type BrokerageOrderPreview,
  type NormalizedOrderIntent,
  type OwnedOrderTarget,
  type PreparedOrderCommand,
  type ProviderCommandResult,
  type ProviderDetailResult,
  type ProviderOrderListProjection,
  type ProviderOrderPreview,
} from "./types.ts";

export interface BrokerageOrderProvider {
  preview(
    input: Readonly<{
      authority: BrokerageOrderAuthority;
      operation: BrokerageOrderOperation;
      intent: NormalizedOrderIntent;
      target: OwnedOrderTarget | null;
    }>,
  ): Promise<ProviderOrderPreview>;
  execute(command: PreparedOrderCommand): Promise<ProviderCommandResult>;
  detail(command: PreparedOrderCommand): Promise<ProviderDetailResult>;
  list(
    authority: BrokerageOrderAuthority,
  ): Promise<ProviderOrderListProjection>;
}

async function sha256Hex(value: string): Promise<string> {
  const digest = new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)),
  );
  return [...digest]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function assertFreshAuthority(
  authority: BrokerageOrderAuthority,
  now: Date,
): void {
  if (
    authority.context.connectionStatus !== "connected" ||
    authority.context.accountStatus !== "available" ||
    authority.accountExpiresAt === null ||
    authority.accountExpiresAt <= now ||
    authority.restrictionGeneration === null ||
    authority.restrictionExpiresAt === null ||
    authority.restrictionExpiresAt <= now ||
    authority.restrictionAvailability !== "available"
  ) {
    throw new BrokerageOrderError("brokerage_authority_stale");
  }
  const availableCapabilities = new Set(
    authority.capabilities
      .filter((capability) => capability.available)
      .map((capability) => capability.capability),
  );
  if (
    !availableCapabilities.has("manual_orders") ||
    !availableCapabilities.has("orders_read")
  ) {
    throw new BrokerageOrderError("capability_unavailable");
  }
  // This intentionally does not enumerate only known restriction values.
  // Any active unknown/unsupported restriction is a fail-closed mutation gate.
  if (authority.restrictions.some((restriction) => restriction.active)) {
    throw new BrokerageOrderError("brokerage_restricted");
  }
}

function assertMutableTarget(target: OwnedOrderTarget): void {
  if (!["pending", "partially_filled"].includes(target.state)) {
    throw new BrokerageOrderError("unsupported_order");
  }
}

export function createBrokerageOrderService(
  input: Readonly<{
    withRepository: WithBrokerageOrderRepository;
    withStaffRepository: WithBrokerageOrderRepository;
    provider: BrokerageOrderProvider;
    now?: () => Date;
    id?: () => string;
  }>,
): Readonly<{
  previewPlace(
    accountId: string,
    intent: unknown,
  ): Promise<BrokerageOrderPreview>;
  previewModify(
    accountId: string,
    orderId: string,
    intent: unknown,
  ): Promise<BrokerageOrderPreview>;
  previewCancel(
    accountId: string,
    orderId: string,
  ): Promise<BrokerageOrderPreview>;
  confirmPlace(
    input: Readonly<
      {
        accountId: string;
        previewId: string;
        idempotencyKey: string;
        intent: unknown;
      }
    >,
  ): Promise<BrokerageOrderCommand>;
  confirmModify(
    input: Readonly<
      {
        accountId: string;
        orderId: string;
        previewId: string;
        idempotencyKey: string;
        intent: unknown;
      }
    >,
  ): Promise<BrokerageOrderCommand>;
  confirmCancel(
    input: Readonly<
      {
        accountId: string;
        orderId: string;
        previewId: string;
        idempotencyKey: string;
      }
    >,
  ): Promise<BrokerageOrderCommand>;
  command(commandId: string): Promise<BrokerageOrderCommand>;
  staffReconciliation(
    commandId: string,
  ): ReturnType<BrokerageOrderRepository["staffReconciliation"]>;
  listOrders(
    accountId: string,
    forceRefresh?: boolean,
  ): ReturnType<BrokerageOrderRepository["listOrders"]>;
  order(
    accountId: string,
    orderId: string,
  ): ReturnType<BrokerageOrderRepository["order"]>;
  reconcile(commandId: string): Promise<BrokerageOrderCommand>;
}> {
  const now = input.now ?? (() => new Date());
  const id = input.id ?? (() => crypto.randomUUID());
  const withRepository = input.withRepository;

  const preview = async (
    accountId: string,
    operation: BrokerageOrderOperation,
    intent: NormalizedOrderIntent,
    target: OwnedOrderTarget | null,
  ): Promise<BrokerageOrderPreview> => {
    const authority = await withRepository((repository) =>
      repository.authority(accountId)
    );
    const currentTime = now();
    assertFreshAuthority(authority, currentTime);
    if ("instrument_id" in intent) {
      await withRepository((repository) =>
        repository.assertInstrumentOwned(accountId, intent.instrument_id)
      );
    }
    if (target !== null) assertMutableTarget(target);
    const providerPreview = await input.provider.preview({
      authority,
      operation,
      intent,
      target,
    });
    if (
      providerPreview.expiresAt <= currentTime ||
      providerPreview.expiresAt.getTime() - currentTime.getTime() > 120_000 ||
      !/^[a-f0-9]{64}$/.test(providerPreview.reference.hash) ||
      providerPreview.reference.keyVersion < 1 ||
      providerPreview.reference.ciphertext.length < 32 ||
      providerPreview.reference.ciphertext.length > 4096
    ) {
      throw new BrokerageOrderError("provider_contract_unavailable", true);
    }
    const normalizedPayloadHash = await sha256Hex(JSON.stringify(intent));
    return withRepository((repository) =>
      repository.savePreview({
        authority,
        id: id(),
        operation,
        targetOrderId: target?.orderId ?? null,
        normalizedPayload: intent,
        normalizedPayloadHash,
        provider: providerPreview,
        policyVersion: BROKERAGE_ORDER_POLICY_VERSION,
      })
    );
  };

  const confirm = async (
    accountId: string,
    operation: BrokerageOrderOperation,
    targetOrderId: string | null,
    previewId: string,
    idempotencyKey: string,
    intent: NormalizedOrderIntent,
  ): Promise<BrokerageOrderCommand> => {
    const payloadHash = await sha256Hex(JSON.stringify(intent));
    const authority = await withRepository((repository) =>
      repository.authority(accountId)
    );
    // This identifier is deterministic for the exact owner/account/operation/
    // idempotency/payload binding, so duplicate devices cannot manufacture a
    // conflicting provider identifier before the database returns the winner.
    const stableDigest = await sha256Hex([
      authority.context.userId,
      authority.context.connectionId,
      accountId,
      operation,
      idempotencyKey,
      payloadHash,
    ].join("\u001f"));
    const prepared = await withRepository((repository) =>
      repository.prepareCommand({
        authority,
        previewId,
        commandId: id(),
        operation,
        targetOrderId,
        idempotencyKey,
        clientOrderId: `argus_${stableDigest.slice(0, 48)}`,
        normalizedPayload: intent,
        normalizedPayloadHash: payloadHash,
        policyVersion: BROKERAGE_ORDER_POLICY_VERSION,
        now: now(),
      })
    );
    if (prepared.duplicate) {
      return withRepository((repository) => repository.command(prepared.id));
    }

    let result: ProviderCommandResult;
    try {
      result = await input.provider.execute(prepared);
    } catch (error) {
      if (error instanceof BrokerageOrderError && error.beforeEgress) {
        return withRepository((repository) =>
          repository.recordBeforeEgressFailure(
            prepared,
            normalizeBrokerageReasonCode(
              error.code,
              "provider_contract_unavailable",
            ),
          )
        );
      }
      return withRepository((repository) =>
        repository.recordAmbiguous(prepared, "provider_outcome_unknown")
      );
    }
    if (result.kind === "acknowledged") {
      return withRepository((repository) =>
        repository.recordAccepted(prepared, result)
      );
    }
    if (result.kind === "rejected") {
      return withRepository((repository) =>
        repository.recordRejected(
          prepared,
          normalizeBrokerageReasonCode(result.providerCode, "provider_rejected"),
        )
      );
    }
    return withRepository((repository) =>
      repository.recordAmbiguous(
        prepared,
        normalizeBrokerageReasonCode(
          result.reasonCode,
          "provider_outcome_unknown",
        ),
      )
    );
  };

  return Object.freeze({
    previewPlace: async (accountId, intent) =>
      preview(accountId, "place", normalizePlaceOrderIntent(intent), null),
    previewModify: async (accountId, orderId, intent) => {
      const target = await withRepository((repository) =>
        repository.targetOrder(accountId, orderId)
      );
      return preview(
        accountId,
        "modify",
        normalizeModifyOrderIntent(orderId, intent),
        target,
      );
    },
    previewCancel: async (accountId, orderId) => {
      const target = await withRepository((repository) =>
        repository.targetOrder(accountId, orderId)
      );
      return preview(
        accountId,
        "cancel",
        normalizeCancelOrderIntent(orderId),
        target,
      );
    },
    confirmPlace: async (request) =>
      confirm(
        request.accountId,
        "place",
        null,
        request.previewId,
        request.idempotencyKey,
        normalizePlaceOrderIntent(request.intent),
      ),
    confirmModify: async (request) =>
      confirm(
        request.accountId,
        "modify",
        request.orderId,
        request.previewId,
        request.idempotencyKey,
        normalizeModifyOrderIntent(request.orderId, request.intent),
      ),
    confirmCancel: async (request) =>
      confirm(
        request.accountId,
        "cancel",
        request.orderId,
        request.previewId,
        request.idempotencyKey,
        normalizeCancelOrderIntent(request.orderId),
      ),
    command: (commandId) =>
      withRepository((repository) => repository.command(commandId)),
    staffReconciliation: (commandId) =>
      input.withStaffRepository((repository) =>
        repository.staffReconciliation(commandId)
      ),
    listOrders: async (accountId, forceRefresh = false) => {
      const cached = await withRepository((repository) =>
        repository.listOrders(accountId)
      );
      if (
        !forceRefresh && ["fresh", "empty", "partial"].includes(cached.state)
      ) return cached;
      const authority = await withRepository((repository) =>
        repository.authority(accountId)
      );
      if (authority.context.connectionStatus !== "connected") return cached;
      try {
        const projection = await input.provider.list(authority);
        const currentTime = now();
        if (
          !Number.isFinite(projection.fetchedAt.getTime()) ||
          !Number.isFinite(projection.expiresAt.getTime()) ||
          projection.expiresAt < projection.fetchedAt ||
          projection.expiresAt.getTime() - projection.fetchedAt.getTime() >
            300_000 ||
          Math.abs(projection.fetchedAt.getTime() - currentTime.getTime()) >
            30_000 ||
          (projection.providerObservedAt !== null &&
            projection.providerObservedAt > projection.fetchedAt) ||
          projection.observations.length > 10_000 ||
          projection.observations.some((observation) =>
            observation.order.source !== "list" ||
            new Date(observation.order.fetched_at).getTime() !==
              projection.fetchedAt.getTime()
          )
        ) {
          throw new BrokerageOrderError("provider_contract_unavailable");
        }
        return await withRepository((repository) =>
          repository.saveOrderList(authority, projection)
        );
      } catch {
        return cached;
      }
    },
    order: (accountId, orderId) =>
      withRepository((repository) => repository.order(accountId, orderId)),
    reconcile: async (commandId) => {
      const prepared = await withRepository((repository) =>
        repository.claimReconciliation(commandId)
      );
      if (prepared === null) {
        return withRepository((repository) => repository.command(commandId));
      }
      let detail: ProviderDetailResult;
      try {
        detail = await input.provider.detail(prepared);
      } catch {
        // The command remains reconciling. The recovery worker may perform a
        // later detail lookup, but this path can never call execute again.
        return withRepository((repository) =>
          repository.recordReconciliationAmbiguous(
            prepared,
            "provider_lookup_unavailable",
          )
        );
      }
      if (detail.kind === "resolved") {
        return withRepository((repository) =>
          repository.recordReconciled(
            prepared,
            detail.resolution,
            detail.orderReference,
            detail.order,
          )
        );
      }
      if (detail.kind === "not_found") {
        // Not-found is weak evidence for an eventually-consistent listing and
        // can never terminalize a write whose response was lost.
        return withRepository((repository) =>
          repository.recordReconciliationNotFound(prepared)
        );
      }
      return withRepository((repository) =>
        repository.recordReconciliationAmbiguous(
          prepared,
          normalizeBrokerageReasonCode(
            detail.reasonCode,
            "provider_lookup_unavailable",
          ),
        )
      );
    },
  });
}

export type BrokerageOrderService = ReturnType<
  typeof createBrokerageOrderService
>;

export function createBlockedBrokerageOrderProvider(): BrokerageOrderProvider {
  const blocked = async (): Promise<never> => {
    throw new BrokerageOrderError("provider_contract_unavailable", true);
  };
  return Object.freeze({
    preview: blocked,
    execute: blocked,
    detail: blocked,
    list: blocked,
  });
}
