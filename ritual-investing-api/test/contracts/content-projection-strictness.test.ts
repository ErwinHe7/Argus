import { describe, expect, it } from "vitest";

import {
  evidenceClaimIds,
  presentAssetSummary,
  presentBriefingDetail,
  presentCovenSummary,
  researchDisclosure,
} from "../../src/domains/content/service.ts";

const id = "018f3c2a-4b67-7a89-8abc-123456789001";

describe("normalized content projection contracts", () => {
  it("fails closed instead of fabricating missing editorial fields or dates", () => {
    expect(() =>
      presentAssetSummary({
        id,
        revision_id: id,
        slug: "asset",
        symbol: "AST",
        name: "Asset",
        asset_type: "equity",
        currency: "USD",
        revision_created_at: "2026-08-29T00:00:00.000Z",
        payload: {},
      })
    ).toThrow("invalid_content_projection:appearance_reason");
    expect(() => researchDisclosure(null)).toThrow(
      "invalid_content_projection:observed_at",
    );
  });

  it("requires typed briefing-section fields rather than payload fallbacks", () => {
    expect(() =>
      presentBriefingDetail({
        id,
        briefing_type: "daily",
        period_start: "2026-08-28",
        period_end: "2026-08-29",
        generated_at: "2026-08-29T12:00:00.000Z",
        generation: 1,
        source_sequence: 2,
        read_at: null,
        sections: [{
          ordinal: 1,
          payload: {
            source_sequence: 2,
            schema_version: 1,
            disclosure: "Legacy document value",
          },
        }],
      })
    ).toThrow("invalid_content_projection:source_sequence");
  });

  it("normalizes postgres Date and int8 decoder values at the projection boundary", () => {
    expect(presentBriefingDetail({
      id,
      briefing_type: "daily",
      period_start: new Date("2026-08-28T00:00:00.000Z"),
      period_end: new Date("2026-08-29T00:00:00.000Z"),
      generated_at: new Date("2026-08-29T12:00:00.000Z"),
      generation: "2",
      source_sequence: "9",
      read_at: null,
      sections: [{ ordinal: "1", source_sequence: "9", schema_version: "1", disclosure: "Typed" }],
    })).toMatchObject({
      period_start: "2026-08-28",
      period_end: "2026-08-29",
      generation: 2,
      source_sequence: 9,
      sections: [{ ordinal: 1, source_sequence: 9, schema_version: 1 }],
    });
    expect(presentCovenSummary({
      id,
      revision_id: id,
      slug: "coven",
      company_name: "Argus Co",
      symbol: null,
      category: "owner",
      payload: { focus: "Focus", teaser: "Teaser" },
      effective_date: new Date("2026-08-01T00:00:00.000Z"),
      verified_as_of: new Date("2026-08-28T00:00:00.000Z"),
      revision_created_at: new Date("2026-08-29T12:00:00.000Z"),
    })).toMatchObject({ effective_date: "2026-08-01", verified_as_of: "2026-08-28" });
    expect(() => presentBriefingDetail({
      id, briefing_type: "daily", period_start: "2026-02-30", period_end: "2026-08-29",
      generated_at: new Date("2026-08-29T12:00:00.000Z"), generation: "9007199254740992",
      source_sequence: "9", read_at: null, sections: [],
    })).toThrow("invalid_content_projection:period_start");
  });

  it("reads evidence IDs only from the normalized qualification relation", () => {
    const direct = "018f3c2a-4b67-7a89-8abc-123456789002";
    const hidden = "018f3c2a-4b67-7a89-8abc-123456789003";
    expect(evidenceClaimIds({
      qualification_payload: [{ evidence_claim_id: direct }],
      payload: { nested: { claim_id: hidden } },
    })).toEqual([direct]);
  });
});
