import { describe, expect, it } from "vitest";

import {
  collectionResponseSchema,
  errorResponseSchema,
  idempotencyKeySchema,
  moneySchema,
  objectResponseSchema,
} from "../../src/contracts/common";

const requestId = "018f3c2a-4b67-7a89-8abc-1234567890ab";

describe("common API contracts", () => {
  it("accepts object and collection envelopes with one request id", () => {
    expect(
      objectResponseSchema.parse({
        data: { id: "018f3c2a-4b67-7a89-8abc-1234567890ab" },
        meta: { request_id: requestId },
      }),
    ).toBeTruthy();

    expect(
      collectionResponseSchema.parse({
        data: [],
        meta: { request_id: requestId, next_cursor: null, has_more: false },
      }),
    ).toBeTruthy();
  });

  it("rejects unknown fields in error envelopes", () => {
    const result = errorResponseSchema.safeParse({
      error: {
        code: "validation_failed",
        message: "The request is invalid.",
        request_id: requestId,
        field_errors: [{ path: "title", code: "too_long" }],
        retryable: false,
        providerDetail: "must never escape",
      },
    });

    expect(result.success).toBe(false);
  });

  it("requires bounded idempotency keys and decimal-string money", () => {
    expect(idempotencyKeySchema.safeParse("order-01JY7W4M5GYJ2E47KCEPD88N2K").success).toBe(true);
    expect(idempotencyKeySchema.safeParse("x".repeat(65)).success).toBe(false);
    expect(moneySchema.safeParse({ currency: "USD", minor_units: 10025 }).success).toBe(true);
    expect(moneySchema.safeParse({ currency: "usd", minor_units: 100.25 }).success).toBe(false);
  });
});
