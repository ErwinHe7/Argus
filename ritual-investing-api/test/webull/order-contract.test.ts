import { describe, expect, it } from "vitest";

import fixture from "../fixtures/webull/order-contract.v1.json";
import {
  assertMonotonicOrderProjection,
  normalizeProviderOrder,
} from "../../src/domains/brokerage-orders/normalization.ts";

const orderId = "018f3c2a-4b67-7a89-8abc-123456789010";
const unknownOrderId = "018f3c2a-4b67-7a89-8abc-123456789011";
const instrumentId = "018f3c2a-4b67-7a89-8abc-123456789020";
const fetchedAt = new Date("2026-08-28T12:00:01Z");

describe("versioned synthetic Webull order contract", () => {
  it("keeps real order egress closed while pinning the approved manual subset", () => {
    expect(fixture.fixture_version).toBe("webull-order-synthetic-v1");
    expect(fixture.contract_status).toBe("partner_confirmation_required");
    expect(fixture.real_egress_enabled).toBe(false);
    expect(fixture.approved_manual_subset).toEqual({
      asset_kinds: ["EQUITY", "ETF"],
      sides: ["BUY", "SELL"],
      order_types: ["MARKET", "LIMIT"],
      time_in_force: ["DAY"],
      fractional: false,
      notional: false,
    });
  });

  it("preserves exact decimal strings and maps provider identifiers to opaque IDs", () => {
    const normalized = normalizeProviderOrder(fixture.synthetic_detail, {
      mapOrderId: () => orderId,
      mapAssetId: () => instrumentId,
      fetchedAt,
    });
    expect(normalized).toMatchObject({
      id: orderId,
      instrument_id: instrumentId,
      quantity: "3.000000000000000001",
      filled_quantity: "1.000000000000000001",
      limit_price: "10.250000000000000001",
      state: "partially_filled",
      terminal: false,
    });
    expect(JSON.stringify(normalized)).not.toContain("SYNTHETIC-ORDER");
    expect(JSON.stringify(normalized)).not.toContain("SYNTHETIC-ASSET");
  });

  it("preserves unknown enums without granting supported or terminal meaning", () => {
    const normalized = normalizeProviderOrder(
      fixture.synthetic_unknown_detail,
      {
        mapOrderId: () => unknownOrderId,
        mapAssetId: () => instrumentId,
        fetchedAt,
      },
    );
    expect(normalized).toMatchObject({
      side: "unsupported",
      provider_side: "OPEN_LONG_V2",
      order_type: "unsupported",
      provider_order_type: "PEGGED_V2",
      time_in_force: "unsupported",
      provider_time_in_force: "SESSION_V2",
      state: "unknown",
      provider_state: "PARKED_V2",
      terminal: false,
    });
  });

  it("lets later detail and fill evidence advance but rejects list or state regression", () => {
    const previous = {
      state: "partially_filled" as const,
      filledQuantity: "1.000000000000000001",
      providerObservedAt: new Date("2026-08-28T12:00:00Z"),
      source: "detail" as const,
    };
    expect(() =>
      assertMonotonicOrderProjection(previous, {
        state: "filled",
        filledQuantity: "3.000000000000000001",
        providerObservedAt: new Date("2026-08-28T12:00:02Z"),
        source: "detail",
      })
    ).not.toThrow();
    expect(() =>
      assertMonotonicOrderProjection(previous, {
        state: "pending",
        filledQuantity: "0",
        providerObservedAt: new Date("2026-08-28T12:00:03Z"),
        source: "list",
      })
    ).toThrow("provider_contract_unavailable");
    expect(() =>
      assertMonotonicOrderProjection(previous, {
        state: "partially_filled",
        filledQuantity: "1.000000000000000001",
        providerObservedAt: previous.providerObservedAt,
        source: "list",
      })
    ).toThrow("provider_contract_unavailable");
  });
});
