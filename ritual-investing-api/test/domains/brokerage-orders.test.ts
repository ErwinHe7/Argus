import { describe, expect, it, vi } from "vitest";

import {
  parseNormalizedOrderProjection,
} from "../../src/domains/brokerage-orders/repository.ts";
import type { BrokerageOrderRepository } from "../../src/domains/brokerage-orders/ports.ts";
import {
  type BrokerageOrderProvider,
  createBrokerageOrderService,
} from "../../src/domains/brokerage-orders/service.ts";
import {
  BROKERAGE_ORDER_POLICY_VERSION,
  type BrokerageOrderAuthority,
  type BrokerageOrderCommand,
  BrokerageOrderError,
  type BrokerageOrderPreview,
  type NormalizedOrderIntent,
  type PreparedOrderCommand,
  type ProviderOrderListProjection,
} from "../../src/domains/brokerage-orders/types.ts";

const now = new Date("2026-08-28T12:00:00Z");
const userId = "018f3c2a-4b67-7a89-8abc-123456789001";
const connectionId = "018f3c2a-4b67-7a89-8abc-123456789002";
const accountA = "018f3c2a-4b67-7a89-8abc-123456789003";
const accountB = "018f3c2a-4b67-7a89-8abc-123456789004";
const instrumentId = "018f3c2a-4b67-7a89-8abc-123456789005";
const unsupportedInstrumentId = "018f3c2a-4b67-7a89-8abc-123456789007";
const orderId = "018f3c2a-4b67-7a89-8abc-123456789006";
const detailOrder = Object.freeze({
  id: orderId,
  instrument_id: instrumentId,
  symbol: "ARGX",
  side: "buy" as const,
  provider_side: "BUY",
  order_type: "limit" as const,
  provider_order_type: "LIMIT",
  time_in_force: "day" as const,
  provider_time_in_force: "DAY",
  quantity: "1",
  filled_quantity: "0",
  limit_price: "10",
  stop_price: null,
  average_fill_price: null,
  currency: "USD",
  state: "pending" as const,
  provider_state: "PENDING",
  terminal: false,
  generation: 1,
  source: "detail" as const,
  provider_observed_at: now.toISOString(),
  fetched_at: now.toISOString(),
});

function authority(accountId = accountA): BrokerageOrderAuthority {
  return Object.freeze({
    context: Object.freeze({
      userId,
      deletionEpoch: 4,
      connectionId,
      connectionStatus: "connected" as const,
      accountId,
      accountStatus: "available" as const,
      capabilityVersion: 7,
    }),
    accountExpiresAt: new Date("2026-08-28T12:01:00Z"),
    capabilities: Object.freeze([
      {
        capability: "orders_read" as const,
        provider_code: "ORDERS_READ",
        available: true,
      },
      {
        capability: "manual_orders" as const,
        provider_code: "MANUAL_ORDERS",
        available: true,
      },
    ]),
    restrictionGeneration: 9,
    restrictionExpiresAt: new Date("2026-08-28T12:01:00Z"),
    restrictionAvailability: "available" as const,
    restrictions: Object.freeze([]),
  });
}

function response(command: PreparedOrderCommand): BrokerageOrderCommand {
  return Object.freeze({
    id: command.id,
    account_id: command.accountId,
    operation: command.operation,
    target_order_id: command.targetOrderId,
    order_id: ["accepted", "resolved"].includes(command.state)
      ? command.targetOrderId ?? orderId
      : null,
    state: command.state,
    ambiguous: ["dispatching", "ambiguous", "reconciling", "manual_review"]
      .includes(command.state),
    created_at: now.toISOString(),
    updated_at: now.toISOString(),
  });
}

function fixture() {
  const events: string[] = [];
  const transactionEvents: string[] = [];
  const authorities = new Map([[accountA, authority()], [
    accountB,
    authority(accountB),
  ]]);
  const previews = new Map<string, {
    value: BrokerageOrderPreview;
    operation: PreparedOrderCommand["operation"];
    payload: NormalizedOrderIntent;
    payloadHash: string;
    consumed: boolean;
  }>();
  const commands = new Map<string, PreparedOrderCommand>();
  const byIdempotency = new Map<string, PreparedOrderCommand>();
  const blockedAccounts = new Set<string>();
  const assetKinds = new Map([
    [instrumentId, "equity" as const],
    [unsupportedInstrumentId, "unsupported" as const],
  ]);
  let nextId = 0;

  const repository: BrokerageOrderRepository = {
    authority: vi.fn(async (accountId) => {
      const result = authorities.get(accountId);
      if (result === undefined) {
        throw new BrokerageOrderError("account_not_found");
      }
      return result;
    }),
    assertInstrumentOwned: vi.fn(async (accountId, candidate) => {
      if (
        accountId !== accountA ||
        !["equity", "etf"].includes(assetKinds.get(candidate) ?? "unsupported")
      ) {
        throw new BrokerageOrderError("unsupported_order");
      }
    }),
    targetOrder: vi.fn(async (accountId, candidate) => {
      if (accountId !== accountA || candidate !== orderId) {
        throw new BrokerageOrderError("order_not_found");
      }
      if (!["equity", "etf"].includes(assetKinds.get(instrumentId)!)) {
        throw new BrokerageOrderError("unsupported_order");
      }
      return {
        orderId,
        accountId,
        instrumentId,
        state: "pending" as const,
      };
    }),
    savePreview: vi.fn(async (input) => {
      const value = Object.freeze({
        id: input.id,
        account_id: input.authority.context.accountId,
        operation: input.operation,
        target_order_id: input.targetOrderId,
        policy_version: BROKERAGE_ORDER_POLICY_VERSION,
        capability_version: input.authority.context.capabilityVersion,
        restriction_generation: input.authority.restrictionGeneration!,
        reviewed_payload_hash: input.normalizedPayloadHash,
        estimated_total: input.provider.estimatedTotal,
        currency: input.provider.currency,
        expires_at: input.provider.expiresAt.toISOString(),
      });
      previews.set(input.id, {
        value,
        operation: input.operation,
        payload: input.normalizedPayload,
        payloadHash: input.normalizedPayloadHash,
        consumed: false,
      });
      return value;
    }),
    prepareCommand: vi.fn(async (input) => {
      // This emulates the race-safe SQL function: the idempotency winner is
      // checked before preview expiry, freshness, or the account ambiguity gate.
      const existing = byIdempotency.get(input.idempotencyKey);
      if (existing !== undefined) {
        if (
          existing.accountId !== input.authority.context.accountId ||
          existing.operation !== input.operation ||
          existing.targetOrderId !== input.targetOrderId ||
          existing.normalizedPayloadHash !== input.normalizedPayloadHash ||
          JSON.stringify(existing.normalizedPayload) !==
            JSON.stringify(input.normalizedPayload)
        ) {
          throw new BrokerageOrderError("idempotency_conflict");
        }
        return { ...existing, duplicate: true };
      }
      const currentAuthority = input.authority;
      if (
        currentAuthority.accountExpiresAt === null ||
        currentAuthority.accountExpiresAt <= input.now ||
        currentAuthority.restrictionExpiresAt === null ||
        currentAuthority.restrictionExpiresAt <= input.now ||
        currentAuthority.restrictionAvailability !== "available"
      ) throw new BrokerageOrderError("brokerage_authority_stale");
      if (
        currentAuthority.restrictions.some((item: { active: boolean }) =>
          item.active
        )
      ) {
        throw new BrokerageOrderError("brokerage_restricted");
      }
      const saved = previews.get(input.previewId);
      if (
        saved === undefined || saved.consumed ||
        saved.operation !== input.operation ||
        saved.value.account_id !== input.authority.context.accountId ||
        saved.value.target_order_id !== input.targetOrderId ||
        saved.value.expires_at <= input.now.toISOString() ||
        saved.payloadHash !== input.normalizedPayloadHash ||
        JSON.stringify(saved.payload) !==
          JSON.stringify(input.normalizedPayload)
      ) throw new BrokerageOrderError("preview_mismatch");
      if (blockedAccounts.has(input.authority.context.accountId)) {
        throw new BrokerageOrderError("account_command_blocked");
      }
      saved.consumed = true;
      const prepared = Object.freeze({
        id: input.commandId,
        userId,
        deletionEpoch: 4,
        connectionId,
        accountId: input.authority.context.accountId,
        operation: input.operation,
        targetOrderId: input.targetOrderId,
        clientOrderId: input.clientOrderId,
        normalizedPayload: input.normalizedPayload,
        normalizedPayloadHash: input.normalizedPayloadHash,
        previewReference: {
          ciphertext: new Uint8Array(32),
          hash: "a".repeat(64),
          keyVersion: 1,
        },
        state: "dispatching" as const,
        duplicate: false,
        egressStartedAt: input.now,
      });
      commands.set(prepared.id, prepared);
      byIdempotency.set(input.idempotencyKey, prepared);
      blockedAccounts.add(prepared.accountId);
      events.push("durable-command-and-egress-attempt");
      return prepared;
    }),
    command: vi.fn(async (commandId) => {
      const found = commands.get(commandId);
      if (found === undefined) {
        throw new BrokerageOrderError("command_not_found");
      }
      return response(found);
    }),
    staffReconciliation: vi.fn(async (commandId) => {
      const found = commands.get(commandId);
      if (found === undefined) {
        throw new BrokerageOrderError("command_not_found");
      }
      return {
        command: response(found),
        status: found.state === "resolved"
          ? "resolved" as const
          : "pending" as const,
        attempts: 2,
        next_attempt_at: now.toISOString(),
        last_error_code: null,
        egress_started_at: found.egressStartedAt.toISOString(),
      };
    }),
    recordAccepted: vi.fn(async (prepared) => {
      const updated = Object.freeze({
        ...prepared,
        state: "accepted" as const,
      });
      commands.set(prepared.id, updated);
      blockedAccounts.delete(prepared.accountId);
      events.push("egress-attempt-accepted");
      return response(updated);
    }),
    recordRejected: vi.fn(async (prepared) => {
      const updated = Object.freeze({ ...prepared, state: "failed" as const });
      commands.set(prepared.id, updated);
      blockedAccounts.delete(prepared.accountId);
      events.push("egress-attempt-terminal-before-or-at-provider");
      return response(updated);
    }),
    recordAmbiguous: vi.fn(async (prepared) => {
      const updated = Object.freeze({
        ...prepared,
        state: "ambiguous" as const,
      });
      commands.set(prepared.id, updated);
      events.push("egress-attempt-ambiguous-after-boundary");
      return response(updated);
    }),
    recordBeforeEgressFailure: vi.fn(async (prepared) => {
      const updated = Object.freeze({ ...prepared, state: "failed" as const });
      commands.set(prepared.id, updated);
      blockedAccounts.delete(prepared.accountId);
      events.push("known-before-egress-failure");
      return response(updated);
    }),
    claimReconciliation: vi.fn(async (commandId) => {
      const found = commands.get(commandId);
      if (
        found === undefined ||
        !["dispatching", "ambiguous", "reconciling"].includes(found.state)
      ) {
        throw new BrokerageOrderError("command_not_found");
      }
      const updated = Object.freeze({
        ...found,
        state: "reconciling" as const,
      });
      commands.set(commandId, updated);
      events.push("detail-lookup-attempt-started");
      return updated;
    }),
    recordReconciliationNotFound: vi.fn(async (prepared) => {
      events.push("detail-not-found-remains-nonterminal");
      return response(prepared);
    }),
    recordReconciliationAmbiguous: vi.fn(async (prepared) => {
      events.push("detail-lookup-remains-ambiguous");
      return response(prepared);
    }),
    recordReconciled: vi.fn(async (prepared) => {
      const updated = Object.freeze({
        ...prepared,
        state: "resolved" as const,
      });
      commands.set(prepared.id, updated);
      blockedAccounts.delete(prepared.accountId);
      events.push("positive-detail-resolved-command");
      return response(updated);
    }),
    listOrders: vi.fn(async (accountId) => ({
      account_id: accountId,
      state: "empty" as const,
      provider_observed_at: now.toISOString(),
      fetched_at: now.toISOString(),
      expires_at: new Date(now.getTime() + 60_000).toISOString(),
      orders: [],
    })),
    saveOrderList: vi.fn(async (
      savedAuthority: BrokerageOrderAuthority,
      projection: ProviderOrderListProjection,
    ) => ({
      account_id: savedAuthority.context.accountId,
      state: projection.availability === "partial"
        ? "partial" as const
        : projection.observations.length === 0
        ? "empty" as const
        : "fresh" as const,
      provider_observed_at: projection.providerObservedAt?.toISOString() ??
        null,
      fetched_at: projection.fetchedAt.toISOString(),
      expires_at: projection.expiresAt.toISOString(),
      orders: projection.observations.map(({ order }) => order),
    })),
    order: vi.fn(async () => detailOrder),
  };

  const provider: BrokerageOrderProvider = {
    preview: vi.fn(async () => ({
      reference: {
        ciphertext: new Uint8Array(32),
        hash: "a".repeat(64),
        keyVersion: 1,
      },
      expiresAt: new Date(now.getTime() + 60_000),
      estimatedTotal: "10",
      currency: "USD",
    })),
    execute: vi.fn(async (command) => {
      expect(events.at(-1)).toBe("durable-command-and-egress-attempt");
      events.push("provider-bytes-sent-once");
      transactionEvents.push("provider-execute");
      return {
        kind: "rejected" as const,
        providerCode: "SYNTHETIC_REJECTED",
      };
    }),
    detail: vi.fn(async () => ({ kind: "not_found" as const })),
    list: vi.fn(async () => ({
      observations: [],
      providerObservedAt: now,
      fetchedAt: now,
      expiresAt: new Date(now.getTime() + 60_000),
      availability: "available" as const,
    })),
  };
  const ids = [
    "018f3c2a-4b67-7a89-8abc-123456789101",
    "018f3c2a-4b67-7a89-8abc-123456789102",
    "018f3c2a-4b67-7a89-8abc-123456789103",
    "018f3c2a-4b67-7a89-8abc-123456789104",
    "018f3c2a-4b67-7a89-8abc-123456789105",
  ];
  return {
    repository,
    provider,
    authorities,
    assetKinds,
    events,
    transactionEvents,
    blockedAccounts,
    service: createBrokerageOrderService({
      withRepository: async (callback) => {
        transactionEvents.push("member-begin");
        const result = await callback(repository);
        transactionEvents.push("member-commit");
        return result;
      },
      withStaffRepository: async (callback) => {
        transactionEvents.push("staff-begin");
        const result = await callback(repository);
        transactionEvents.push("staff-commit");
        return result;
      },
      provider,
      now: () => now,
      id: () => ids[nextId++]!,
    }),
  };
}

const placeIntent = Object.freeze({
  instrument_id: instrumentId,
  side: "buy" as const,
  order_type: "limit" as const,
  time_in_force: "day" as const,
  quantity: "1",
  limit_price: "10.00",
});

describe("manual brokerage order commands", () => {
  it("rejects malformed or augmented persisted order projections", () => {
    expect(() =>
      parseNormalizedOrderProjection({
        ...detailOrder,
        provider_order_id: "RAW-PROVIDER-ORDER",
      })
    ).toThrow("provider_contract_unavailable");
    const stored = structuredClone(detailOrder) as Record<string, unknown>;
    delete stored.generation;
    delete stored.source;
    delete stored.provider_observed_at;
    delete stored.fetched_at;
    expect(() =>
      parseNormalizedOrderProjection({
        ...stored,
        quantity: "1e9",
      })
    ).toThrow("provider_contract_unavailable");
    expect(() =>
      parseNormalizedOrderProjection({
        ...stored,
        state: "FUTURE_STATE",
      })
    ).toThrow("provider_contract_unavailable");
    expect(() =>
      parseNormalizedOrderProjection({
        ...stored,
        secret: "must-not-cross-boundary",
      })
    ).toThrow("provider_contract_unavailable");
  });

  it("accepts one supported reviewed command and records provider order evidence", async () => {
    const test = fixture();
    vi.mocked(test.provider.execute).mockResolvedValueOnce({
      kind: "acknowledged",
      orderReference: {
        ciphertext: new Uint8Array(32),
        hash: "b".repeat(64),
        keyVersion: 1,
      },
      order: detailOrder,
    });
    const preview = await test.service.previewPlace(accountA, placeIntent);
    const accepted = await test.service.confirmPlace({
      accountId: accountA,
      previewId: preview.id,
      idempotencyKey: "member-device-key-0000",
      intent: placeIntent,
    });
    expect(accepted).toMatchObject({ state: "accepted", order_id: orderId });
    expect(test.repository.recordAccepted).toHaveBeenCalledOnce();
    expect(test.provider.execute).toHaveBeenCalledOnce();
  });

  it("persists the command and immutable started attempt before exactly one provider submission", async () => {
    const test = fixture();
    const preview = await test.service.previewPlace(accountA, placeIntent);
    test.transactionEvents.length = 0;
    const command = await test.service.confirmPlace({
      accountId: accountA,
      previewId: preview.id,
      idempotencyKey: "member-device-key-0001",
      intent: placeIntent,
    });
    expect(command.state).toBe("failed");
    expect(test.provider.execute).toHaveBeenCalledOnce();
    expect(test.events).toEqual([
      "durable-command-and-egress-attempt",
      "provider-bytes-sent-once",
      "egress-attempt-terminal-before-or-at-provider",
    ]);
    const providerIndex = test.transactionEvents.indexOf("provider-execute");
    expect(test.transactionEvents[providerIndex - 1]).toBe("member-commit");
    expect(test.transactionEvents[providerIndex + 1]).toBe("member-begin");
  });

  it("returns the SQL idempotency winner across duplicate taps without a second submit", async () => {
    const test = fixture();
    const preview = await test.service.previewPlace(accountA, placeIntent);
    const request = {
      accountId: accountA,
      previewId: preview.id,
      idempotencyKey: "member-device-key-0002",
      intent: placeIntent,
    };
    const first = await test.service.confirmPlace(request);
    const duplicate = await test.service.confirmPlace(request);
    expect(duplicate.id).toBe(first.id);
    expect(test.provider.execute).toHaveBeenCalledOnce();

    await expect(test.service.confirmPlace({
      ...request,
      intent: { ...placeIntent, quantity: "2" },
    })).rejects.toThrow("idempotency_conflict");
  });

  it("returns an exact duplicate after authority expiry and an account ambiguity gate", async () => {
    const test = fixture();
    const preview = await test.service.previewPlace(accountA, placeIntent);
    const request = {
      accountId: accountA,
      previewId: preview.id,
      idempotencyKey: "member-device-key-duplicate-after-expiry",
      intent: placeIntent,
    };
    const first = await test.service.confirmPlace(request);
    test.authorities.set(accountA, {
      ...authority(),
      accountExpiresAt: new Date("2026-08-28T11:59:00Z"),
      restrictions: [{
        restriction: "unsupported",
        provider_code: "FUTURE_PROVIDER_RESTRICTION",
        active: true,
        detail: null,
      }],
    });
    test.blockedAccounts.add(accountA);

    const duplicate = await test.service.confirmPlace(request);
    expect(duplicate.id).toBe(first.id);
    expect(test.provider.execute).toHaveBeenCalledOnce();
  });

  it("rejects an owned unsupported asset before provider preview", async () => {
    const test = fixture();
    await expect(test.service.previewPlace(accountA, {
      ...placeIntent,
      instrument_id: unsupportedInstrumentId,
    })).rejects.toThrow("unsupported_order");
    expect(test.repository.assertInstrumentOwned).toHaveBeenCalledOnce();
    expect(test.provider.preview).not.toHaveBeenCalled();

    test.assetKinds.set(instrumentId, "unsupported");
    await expect(test.service.previewCancel(accountA, orderId)).rejects.toThrow(
      "unsupported_order",
    );
    expect(test.provider.preview).not.toHaveBeenCalled();
  });

  it("refreshes atomic order-list projections with explicit freshness states", async () => {
    const orderReference = {
      ciphertext: new Uint8Array(32),
      hash: "d".repeat(64),
      keyVersion: 1,
    };
    for (
      const [availability, observations, expected] of [
        [
          "available",
          [{
            orderReference,
            order: { ...detailOrder, source: "list" as const },
          }],
          "fresh",
        ],
        ["available", [], "empty"],
        [
          "partial",
          [{
            orderReference,
            order: { ...detailOrder, source: "list" as const },
          }],
          "partial",
        ],
      ] as const
    ) {
      const test = fixture();
      vi.mocked(test.provider.list).mockResolvedValueOnce({
        observations,
        providerObservedAt: now,
        fetchedAt: now,
        expiresAt: new Date(now.getTime() + 60_000),
        availability,
      });
      expect(await test.service.listOrders(accountA, true)).toMatchObject({
        state: expected,
      });
      expect(test.repository.saveOrderList).toHaveBeenCalledOnce();
    }

    for (const state of ["stale", "unavailable"] as const) {
      const test = fixture();
      vi.mocked(test.repository.listOrders).mockResolvedValueOnce({
        account_id: accountA,
        state,
        provider_observed_at: now.toISOString(),
        fetched_at: now.toISOString(),
        expires_at: now.toISOString(),
        orders: [],
      });
      vi.mocked(test.provider.list).mockRejectedValueOnce(
        new BrokerageOrderError("provider_contract_unavailable"),
      );
      expect(await test.service.listOrders(accountA, true)).toMatchObject({
        state,
      });
      expect(test.repository.saveOrderList).not.toHaveBeenCalled();
    }
  });

  it("records known pre-egress gates as failed but treats any post-boundary exception as ambiguous", async () => {
    const preEgress = fixture();
    vi.mocked(preEgress.provider.execute).mockRejectedValueOnce(
      new BrokerageOrderError("provider_contract_unavailable", true),
    );
    const preview = await preEgress.service.previewPlace(accountA, placeIntent);
    const failed = await preEgress.service.confirmPlace({
      accountId: accountA,
      previewId: preview.id,
      idempotencyKey: "member-device-key-0003",
      intent: placeIntent,
    });
    expect(failed).toMatchObject({ state: "failed", ambiguous: false });
    expect(preEgress.events).toContain("known-before-egress-failure");

    const uncertain = fixture();
    vi.mocked(uncertain.provider.execute).mockRejectedValueOnce(
      new Error("synthetic connection reset after bytes left"),
    );
    const uncertainPreview = await uncertain.service.previewPlace(
      accountA,
      placeIntent,
    );
    const ambiguous = await uncertain.service.confirmPlace({
      accountId: accountA,
      previewId: uncertainPreview.id,
      idempotencyKey: "member-device-key-0004",
      intent: placeIntent,
    });
    expect(ambiguous).toMatchObject({ state: "ambiguous", ambiguous: true });
    expect(uncertain.events).toContain(
      "egress-attempt-ambiguous-after-boundary",
    );
  });

  it("normalizes provider outcome reasons before durable command completion", async () => {
    const rejected = fixture();
    const rejectedPreview = await rejected.service.previewPlace(
      accountA,
      placeIntent,
    );
    const rejectedCommand = await rejected.service.confirmPlace({
      accountId: accountA,
      previewId: rejectedPreview.id,
      idempotencyKey: "member-reason-rejected-0001",
      intent: placeIntent,
    });
    expect(rejectedCommand).toMatchObject({ state: "failed", ambiguous: false });
    expect(rejected.repository.recordRejected).toHaveBeenCalledWith(
      expect.anything(),
      "provider_rejected",
    );

    const ambiguous = fixture();
    vi.mocked(ambiguous.provider.execute).mockResolvedValueOnce({
      kind: "ambiguous",
      reasonCode: "provider/error!",
    });
    const ambiguousPreview = await ambiguous.service.previewPlace(
      accountA,
      placeIntent,
    );
    await ambiguous.service.confirmPlace({
      accountId: accountA,
      previewId: ambiguousPreview.id,
      idempotencyKey: "member-reason-ambiguous-0001",
      intent: placeIntent,
    });
    expect(ambiguous.repository.recordAmbiguous).toHaveBeenCalledWith(
      expect.anything(),
      "provider_outcome_unknown",
    );

    const beforeEgress = fixture();
    vi.mocked(beforeEgress.provider.execute).mockRejectedValueOnce(
      new BrokerageOrderError("SYNTHETIC_REJECTED" as never, true),
    );
    const beforeEgressPreview = await beforeEgress.service.previewPlace(
      accountA,
      placeIntent,
    );
    await beforeEgress.service.confirmPlace({
      accountId: accountA,
      previewId: beforeEgressPreview.id,
      idempotencyKey: "member-reason-before-egress-0001",
      intent: placeIntent,
    });
    expect(beforeEgress.repository.recordBeforeEgressFailure)
      .toHaveBeenCalledWith(expect.anything(), "provider_contract_unavailable");

    const reconciliation = fixture();
    vi.mocked(reconciliation.provider.execute).mockRejectedValueOnce(
      new Error("lost response"),
    );
    const reconciliationPreview = await reconciliation.service.previewPlace(
      accountA,
      placeIntent,
    );
    const reconciliationCommand = await reconciliation.service.confirmPlace({
      accountId: accountA,
      previewId: reconciliationPreview.id,
      idempotencyKey: "member-reason-reconciliation-0001",
      intent: placeIntent,
    });
    vi.mocked(reconciliation.provider.detail).mockResolvedValueOnce({
      kind: "ambiguous",
      reasonCode: "SYNTHETIC_LOOKUP_TIMEOUT",
    });
    await reconciliation.service.reconcile(reconciliationCommand.id);
    expect(reconciliation.repository.recordReconciliationAmbiguous)
      .toHaveBeenCalledWith(expect.anything(), "provider_lookup_unavailable");
  });

  it("blocks only the ambiguous account and reconciles by detail without calling execute", async () => {
    const test = fixture();
    vi.mocked(test.provider.execute).mockRejectedValueOnce(
      new Error("lost response"),
    );
    const preview = await test.service.previewPlace(accountA, placeIntent);
    const ambiguous = await test.service.confirmPlace({
      accountId: accountA,
      previewId: preview.id,
      idempotencyKey: "member-device-key-0005",
      intent: placeIntent,
    });
    expect(test.blockedAccounts).toEqual(new Set([accountA]));
    await expect(test.service.previewPlace(accountB, placeIntent)).rejects
      .toThrow(
        "unsupported_order",
      );
    // The second account is not mutation-blocked; its failure is only because
    // the synthetic instrument belongs to account A.
    expect(test.blockedAccounts.has(accountB)).toBe(false);

    const firstLookup = await test.service.reconcile(ambiguous.id);
    expect(firstLookup.state).toBe("reconciling");
    expect(test.blockedAccounts.has(accountA)).toBe(true);
    expect(test.provider.execute).toHaveBeenCalledOnce();
    expect(test.provider.detail).toHaveBeenCalledOnce();
    expect(test.events).toContain("detail-not-found-remains-nonterminal");

    vi.mocked(test.provider.detail).mockResolvedValueOnce({
      kind: "ambiguous",
      reasonCode: "synthetic_lookup_timeout",
    });
    const stillAmbiguous = await test.service.reconcile(ambiguous.id);
    expect(stillAmbiguous.state).toBe("reconciling");
    expect(test.events).toContain("detail-lookup-remains-ambiguous");

    vi.mocked(test.provider.detail).mockResolvedValueOnce({
      kind: "resolved",
      resolution: "applied",
      orderReference: {
        ciphertext: new Uint8Array(32),
        hash: "c".repeat(64),
        keyVersion: 1,
      },
      order: detailOrder,
    });
    const resolved = await test.service.reconcile(ambiguous.id);
    expect(resolved.state).toBe("resolved");
    expect(test.blockedAccounts.has(accountA)).toBe(false);
    expect(test.provider.execute).toHaveBeenCalledOnce();
    expect(test.provider.detail).toHaveBeenCalledTimes(3);
  });

  it("requires command-aware evidence before resolving ambiguous modify or cancel", async () => {
    for (const state of ["pending", "partially_filled"] as const) {
      const test = fixture();
      vi.mocked(test.provider.execute).mockRejectedValueOnce(new Error("lost"));
      const preview = await test.service.previewModify(accountA, orderId, {
        quantity: "2",
        limit_price: "10",
      });
      const command = await test.service.confirmModify({
        accountId: accountA,
        orderId,
        previewId: preview.id,
        idempotencyKey: `member-modify-${state}-0001`,
        intent: { quantity: "2", limit_price: "10" },
      });
      vi.mocked(test.provider.detail).mockResolvedValueOnce({
        kind: "ambiguous",
        reasonCode: `target_still_${state}`,
      });
      const result = await test.service.reconcile(command.id);
      expect(result.state).toBe("reconciling");
      expect(test.blockedAccounts.has(accountA)).toBe(true);
      expect(test.repository.recordReconciled).not.toHaveBeenCalled();
    }

    const filled = fixture();
    vi.mocked(filled.provider.execute).mockRejectedValueOnce(new Error("lost"));
    const modifyPreview = await filled.service.previewModify(
      accountA,
      orderId,
      { quantity: "2", limit_price: "10" },
    );
    const modify = await filled.service.confirmModify({
      accountId: accountA,
      orderId,
      previewId: modifyPreview.id,
      idempotencyKey: "member-modify-filled-0001",
      intent: { quantity: "2", limit_price: "10" },
    });
    vi.mocked(filled.provider.detail).mockResolvedValueOnce({
      kind: "resolved",
      resolution: "superseded_by_fill",
      orderReference: {
        ciphertext: new Uint8Array(32),
        hash: "b".repeat(64),
        keyVersion: 1,
      },
      order: { ...detailOrder, state: "filled", terminal: true },
    });
    expect(await filled.service.reconcile(modify.id)).toMatchObject({
      state: "resolved",
    });
    expect(filled.repository.recordReconciled).toHaveBeenCalledWith(
      expect.anything(),
      "superseded_by_fill",
      expect.anything(),
      expect.objectContaining({ state: "filled" }),
    );

    const cancelled = fixture();
    vi.mocked(cancelled.provider.execute).mockRejectedValueOnce(
      new Error("lost"),
    );
    const cancelPreview = await cancelled.service.previewCancel(
      accountA,
      orderId,
    );
    const cancel = await cancelled.service.confirmCancel({
      accountId: accountA,
      orderId,
      previewId: cancelPreview.id,
      idempotencyKey: "member-cancel-cancelled-0001",
    });
    vi.mocked(cancelled.provider.detail).mockResolvedValueOnce({
      kind: "resolved",
      resolution: "applied",
      orderReference: {
        ciphertext: new Uint8Array(32),
        hash: "c".repeat(64),
        keyVersion: 1,
      },
      order: { ...detailOrder, state: "cancelled", terminal: true },
    });
    expect(await cancelled.service.reconcile(cancel.id)).toMatchObject({
      state: "resolved",
    });
    expect(cancelled.repository.recordReconciled).toHaveBeenCalledWith(
      expect.anything(),
      "applied",
      expect.anything(),
      expect.objectContaining({ state: "cancelled" }),
    );
  });

  it("fails closed on stale authority and every active unknown restriction before preview egress", async () => {
    const stale = fixture();
    stale.authorities.set(accountA, {
      ...authority(),
      restrictionExpiresAt: new Date("2026-08-28T11:59:59Z"),
    });
    await expect(stale.service.previewPlace(accountA, placeIntent)).rejects
      .toThrow(
        "brokerage_authority_stale",
      );
    expect(stale.provider.preview).not.toHaveBeenCalled();

    const unknownRestriction = fixture();
    unknownRestriction.authorities.set(accountA, {
      ...authority(),
      restrictions: [{
        restriction: "unsupported",
        provider_code: "PROVIDER_POLICY_V2",
        active: true,
        detail: null,
      }],
    });
    await expect(
      unknownRestriction.service.previewPlace(accountA, placeIntent),
    ).rejects.toThrow("brokerage_restricted");
    expect(unknownRestriction.provider.preview).not.toHaveBeenCalled();

    const closedMarket = fixture();
    vi.mocked(closedMarket.provider.preview).mockRejectedValueOnce(
      new BrokerageOrderError("unsupported_order", true),
    );
    await expect(
      closedMarket.service.previewPlace(accountA, placeIntent),
    ).rejects.toThrow("unsupported_order");
    expect(closedMarket.provider.execute).not.toHaveBeenCalled();
  });

  it("rejects changed, fractional, notional-equivalent, and cross-account targets", async () => {
    const test = fixture();
    const preview = await test.service.previewPlace(accountA, placeIntent);
    await expect(test.service.confirmPlace({
      accountId: accountA,
      previewId: preview.id,
      idempotencyKey: "member-device-key-0006",
      intent: { ...placeIntent, quantity: "2" },
    })).rejects.toThrow("preview_mismatch");
    await expect(test.service.previewPlace(accountA, {
      ...placeIntent,
      quantity: "0.5",
    })).rejects.toThrow("unsupported_order");
    await expect(
      test.service.previewModify(accountB, orderId, {
        quantity: "1",
        limit_price: "10",
      }),
    ).rejects.toThrow("order_not_found");
  });
});
