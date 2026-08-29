import { describe, expect, it, vi } from "vitest";

import type {
  DatabaseClient,
  DatabasePool,
  DatabaseTransaction,
} from "../../src/db/database-port.ts";
import {
  StaffAuthorizationError,
  withCapabilityStaffRequestTransaction,
} from "../../src/db/request-transaction.ts";
import { createBrokerageOrderRepository } from "../../src/domains/brokerage-orders/repository.ts";
import type { PreparedOrderCommand } from "../../src/domains/brokerage-orders/types.ts";

const preparedCommand: PreparedOrderCommand = {
  id: "018f3c2a-4b67-7a89-8abc-123456789003",
  userId: "018f3c2a-4b67-7a89-8abc-123456789001",
  deletionEpoch: 1,
  connectionId: "018f3c2a-4b67-7a89-8abc-123456789004",
  accountId: "018f3c2a-4b67-7a89-8abc-123456789005",
  operation: "place",
  targetOrderId: null,
  clientOrderId: "argus_test",
  normalizedPayload: {
    instrument_id: "018f3c2a-4b67-7a89-8abc-123456789006",
    side: "buy",
    order_type: "market",
    time_in_force: "day",
    quantity: "1",
    limit_price: null,
  },
  normalizedPayloadHash: "a".repeat(64),
  previewReference: {
    ciphertext: new Uint8Array(32),
    hash: "b".repeat(64),
    keyVersion: 1,
  },
  state: "dispatching",
  duplicate: false,
  egressStartedAt: new Date("2026-08-29T12:00:00Z"),
};

describe("provider command database security boundary", () => {
  it("sends only stable internal codes to U7 command SQL", async () => {
    const row = {
      id: preparedCommand.id,
      command_id: preparedCommand.id,
      account_id: preparedCommand.accountId,
      operation: preparedCommand.operation,
      target_order_id: null,
      order_id: null,
      state: "failed",
      created_at: "2026-08-29T12:00:00.000Z",
      updated_at: "2026-08-29T12:00:00.000Z",
    };
    const calls: Array<Readonly<{ text: string; values: readonly unknown[] }>> = [];
    const query: DatabaseTransaction["query"] = async <Row>(
      text: string,
      values: readonly unknown[] = [],
    ) => {
      calls.push({ text, values });
      return {
        rows: (text.includes("from argus_private.provider_commands") ||
          text.includes("record_provider_command_dispatch_outcome")
          ? [row]
          : []) as Row[],
        rowCount: 1,
      };
    };
    const repository = createBrokerageOrderRepository(
      { query },
      preparedCommand.userId,
    );

    await repository.recordRejected(preparedCommand, "SYNTHETIC_REJECTED");
    await repository.recordAmbiguous(preparedCommand, "provider/error!");
    await repository.recordBeforeEgressFailure(
      preparedCommand,
      "SYNTHETIC_BEFORE_EGRESS",
    );
    await repository.recordReconciliationAmbiguous(
      preparedCommand,
      "SYNTHETIC_LOOKUP_TIMEOUT",
    );

    const dispatchCodes = calls
      .filter(({ text }) => text.includes("record_provider_command_dispatch_outcome"))
      .map(({ values }) => values[3]);
    expect(dispatchCodes).toEqual([
      "provider_rejected",
      "provider_outcome_unknown",
      "provider_contract_unavailable",
    ]);
    expect(calls).toContainEqual({
      text: expect.stringContaining("record_provider_command_lookup_ambiguous"),
      values: [preparedCommand.id, "provider_lookup_unavailable"],
    });
  });

  it("requires current brokerage:read staff permission even for an AAL2 principal", async () => {
    const query = vi.fn(async (text: string) => ({
      rows: text.includes("has_live_staff_session")
        ? [{ live: true }]
        : text.includes("has_staff_permission")
        ? [{ allowed: false }]
        : [],
      rowCount: 0,
    }));
    const pool: DatabasePool = {
      connect: vi.fn(async () => ({
        query: query as DatabaseClient["query"],
        release: vi.fn(),
      })),
      end: vi.fn(async () => undefined),
    };
    const claims = {
      userId: "018f3c2a-4b67-7a89-8abc-123456789001",
      sessionId: "018f3c2a-4b67-7a89-8abc-123456789002",
      aal: "aal2" as const,
    };

    await expect(withCapabilityStaffRequestTransaction(
      { pool, verifiedClaims: claims },
      "brokerage:read",
      (database) =>
        createBrokerageOrderRepository(database, claims.userId)
          .staffReconciliation(
            "018f3c2a-4b67-7a89-8abc-123456789003",
          ),
    )).rejects.toBeInstanceOf(StaffAuthorizationError);
    expect(query).toHaveBeenCalledWith(
      "select argus_private.has_staff_permission($1::text) as allowed",
      ["brokerage:read"],
    );
    expect(
      query.mock.calls.some(([text]) =>
        String(text).includes("from argus_private.provider_commands command")
      ),
    ).toBe(false);
  });
});
