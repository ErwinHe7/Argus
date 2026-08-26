import { describe, expect, it } from "vitest";

import { createApp } from "../../src/app";
import { buildOpenApiDocument } from "../../src/contracts/openapi";

describe("U8 admin route inventory", () => {
  it("exposes every planned P1 path and method", () => {
    const document = buildOpenApiDocument(createApp());
    const paths = document.paths as Record<string, Record<string, unknown>>;
    const expected = new Set<string>([
      "get /v1/admin/me",
      "get /v1/admin/health/ready",
      "get /v1/admin/audit-events",
      "get /v1/admin/assets",
      "post /v1/admin/assets",
      "get /v1/admin/assets/{asset_id}",
      "patch /v1/admin/assets/{asset_id}",
      "post /v1/admin/assets/{asset_id}/metric-snapshots",
      "get /v1/admin/evidence-sources",
      "post /v1/admin/evidence-sources",
      "get /v1/admin/evidence-sources/{source_id}",
      "patch /v1/admin/evidence-sources/{source_id}",
      "get /v1/admin/evidence-claims",
      "post /v1/admin/evidence-claims",
      "get /v1/admin/evidence-claims/{claim_id}",
      "post /v1/admin/coven-entries/{entry_id}/qualifications",
      "post /v1/admin/coven-qualifications/{qualification_id}/verifications",
      "get /v1/admin/ritual-schedules",
      "post /v1/admin/ritual-schedules",
      "patch /v1/admin/ritual-schedules/{schedule_id}",
      "delete /v1/admin/ritual-schedules/{schedule_id}",
      "get /v1/admin/seeded-creators",
      "post /v1/admin/seeded-creators",
      "get /v1/admin/seeded-creators/{creator_id}",
      "patch /v1/admin/seeded-creators/{creator_id}",
      "get /v1/admin/moderation/reports",
      "post /v1/admin/moderation/reports/{report_id}/cases",
      "get /v1/admin/moderation/cases/{case_id}",
      "patch /v1/admin/moderation/cases/{case_id}",
    ]);
    for (const base of [
      "/v1/admin/ritual-scenarios",
      "/v1/admin/asset-codex",
      "/v1/admin/coven-entries",
      "/v1/admin/grimoires",
      "/v1/admin/circle-templates",
      "/v1/admin/rowan-scripts",
      "/v1/admin/briefing-templates",
    ]) {
      expected.add(`get ${base}`);
      expected.add(`post ${base}`);
      expected.add(`get ${base}/{item_id}`);
      expected.add(`post ${base}/{item_id}/revisions`);
      expected.add(`get ${base}/{item_id}/revisions/{revision_id}`);
      expected.add(`patch ${base}/{item_id}/revisions/{revision_id}`);
      expected.add(`get ${base}/{item_id}/revisions/{revision_id}/preview`);
      expected.add(
        `post ${base}/{item_id}/revisions/{revision_id}/review-requests`,
      );
      expected.add(
        `post ${base}/{item_id}/revisions/{revision_id}/review-decisions`,
      );
      expected.add(
        `post ${base}/{item_id}/revisions/{revision_id}/publications`,
      );
      expected.add(`post ${base}/{item_id}/withdrawals`);
    }

    const missing = [...expected].filter((entry) => {
      const [method, path] = entry.split(" ") as [string, string];
      return paths[path]?.[method] === undefined;
    });
    expect(missing).toEqual([]);
  });
});
