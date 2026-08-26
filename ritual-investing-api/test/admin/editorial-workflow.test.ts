import { describe, expect, it, vi } from "vitest";

import { createApp } from "../../src/app";
import { createTestRsaKey } from "../support/jwt";
import {
  ADMIN_CLIENT_ID,
  accessToken,
  memberToken,
  testBindings,
} from "../support/security-fixtures";

const staffId = "018f3c2a-4b67-7a89-8abc-123456789010";
const itemId = "018f3c2a-4b67-7a89-8abc-123456789011";
const revisionId = "018f3c2a-4b67-7a89-8abc-123456789012";

describe("admin Ritual editorial workflow", () => {
  const auth0Key = createTestRsaKey("u8-admin-auth0");
  const accessKey = createTestRsaKey("u8-admin-access");

  function headers(permissions: string[], extras: Record<string, string> = {}) {
    return {
      authorization: `Bearer ${memberToken(auth0Key, {
        sub: "auth0|staff-1",
        azp: ADMIN_CLIENT_ID,
        permissions,
      })}`,
      "cf-access-jwt-assertion": accessToken(accessKey),
      "content-type": "application/json",
      "idempotency-key": "ritual-create-01JY7W4M5GYJ2E47KCEPD88N2K",
      ...extras,
    };
  }

  it("creates the first typed Ritual draft through the protected admin route", async () => {
    const createItem = vi.fn(async () => ({
      id: itemId,
      kind: "ritual_scenario" as const,
      slug: "daily-compass",
      status: "draft" as const,
      version: 1,
      current_published_revision_id: null,
      revision: {
        id: revisionId,
        revision_number: 1,
        state: "draft" as const,
        version: 1,
        author_staff_id: staffId,
        payload: {
          scenario_key: "daily-compass",
          mode: "tarot",
          cadence: "daily",
          title: "The Compass",
          interpretation: "Direction, not urgency.",
          guidance: "Pause and review the evidence.",
          market_label: "Market-informed",
          observation_at: "2026-08-24T12:00:00Z",
          uncertainty: "Demonstration only.",
          ideas: [
            {
              asset_id: "018f3c2a-4b67-7a89-8abc-123456789020",
              appearance_reason: "Dividend quality screen.",
              risk_summary: "Equity prices can decline.",
            },
            {
              asset_id: "018f3c2a-4b67-7a89-8abc-123456789021",
              appearance_reason: "Broad diversification.",
              risk_summary: "Market-wide drawdowns remain possible.",
            },
            {
              asset_id: "018f3c2a-4b67-7a89-8abc-123456789022",
              appearance_reason: "Lower-volatility demonstration.",
              risk_summary: "May lag in rising markets.",
            },
          ],
          evidence: [
            {
              claim_id: "018f3c2a-4b67-7a89-8abc-123456789030",
              factor_label: "Recorded market observation",
            },
          ],
        },
        etag: '"v1"',
      },
      etag: '"v1"',
    }));
    const app = createApp({
      dependencies: {
        auth0Keys: [auth0Key.publicJwk],
        accessKeys: [accessKey.publicJwk],
        resolveStaff: vi.fn(async () => ({
          id: staffId,
          auth0Subject: "auth0|staff-1",
          accessIdentity: "operator@ritual-investing.test",
          allowedClientId: ADMIN_CLIENT_ID,
          displayLabel: "Ritual Operator",
          revocationEpoch: 0,
        })),
        adminEditorialRepository: { createItem },
      },
    } as never);

    const response = await app.request(
      "https://admin-api.ritual-investing.test/v1/admin/ritual-scenarios",
      {
        method: "POST",
        headers: headers(["admin:editorial:write"]),
        body: JSON.stringify({
          slug: "daily-compass",
          scenario_key: "daily-compass",
          mode: "tarot",
          cadence: "daily",
          title: "The Compass",
          interpretation: "Direction, not urgency.",
          guidance: "Pause and review the evidence.",
          market_label: "Market-informed",
          observation_at: "2026-08-24T12:00:00Z",
          uncertainty: "Demonstration only.",
          ideas: [
            {
              asset_id: "018f3c2a-4b67-7a89-8abc-123456789020",
              appearance_reason: "Dividend quality screen.",
              risk_summary: "Equity prices can decline.",
            },
            {
              asset_id: "018f3c2a-4b67-7a89-8abc-123456789021",
              appearance_reason: "Broad diversification.",
              risk_summary: "Market-wide drawdowns remain possible.",
            },
            {
              asset_id: "018f3c2a-4b67-7a89-8abc-123456789022",
              appearance_reason: "Lower-volatility demonstration.",
              risk_summary: "May lag in rising markets.",
            },
          ],
          evidence: [
            {
              claim_id: "018f3c2a-4b67-7a89-8abc-123456789030",
              factor_label: "Recorded market observation",
            },
          ],
        }),
      },
      testBindings(),
    );

    expect(response.status, await response.clone().text()).toBe(201);
    expect(response.headers.get("etag")).toBe('"v1"');
    expect(createItem).toHaveBeenCalledWith(
      expect.objectContaining({
        actorStaffId: staffId,
        kind: "ritual_scenario",
        idempotencyKey: "ritual-create-01JY7W4M5GYJ2E47KCEPD88N2K",
      }),
    );
    expect(await response.json()).toMatchObject({
      data: { id: itemId, revision: { id: revisionId } },
    });
  });
});
