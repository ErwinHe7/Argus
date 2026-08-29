import { describe, expect, it, vi } from "vitest";

import type {
  DatabaseClient,
  DatabasePool,
} from "../../src/db/database-port.ts";
import { StaffAuthorizationError } from "../../src/db/request-transaction.ts";
import { createBrokerageOrderRepository } from "../../src/domains/brokerage-orders/repository.ts";

describe("provider command database security boundary", () => {
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
    const repository = createBrokerageOrderRepository({
      pool,
      claims: {
        userId: "018f3c2a-4b67-7a89-8abc-123456789001",
        sessionId: "018f3c2a-4b67-7a89-8abc-123456789002",
        aal: "aal2",
      },
    });

    await expect(repository.staffReconciliation(
      "018f3c2a-4b67-7a89-8abc-123456789003",
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
