import { describe, expect, it } from "vitest";

import { createApp } from "../../src/app";
import { createTestRsaKey } from "../support/jwt";
import { memberToken, resolvedMemberAccount, testBindings } from "../support/security-fixtures";
import { createDeterministicContentRepository, fixtureIds } from "../../src/domains/editorial/fixtures";

describe("Founders' Coven", () => {
  const auth0Key = createTestRsaKey("coven-domain-key");

  it("preserves distinct dated qualification categories and evidence for members", async () => {
    const response = await createApp({
      dependencies: {
        auth0Keys: [auth0Key.publicJwk],
        accountResolver: async () => resolvedMemberAccount,
        contentRepository: createDeterministicContentRepository(),
      },
    }).request(
      "/v1/coven?limit=20",
      { headers: { authorization: `Bearer ${memberToken(auth0Key)}` } },
      testBindings(),
    );

    expect(response.status).toBe(200);
    const body = await response.json() as {
      data: Array<{ category: string; effective_date: string; verified_as_of: string }>;
    };
    expect(new Set(body.data.map((entry) => entry.category))).toEqual(
      new Set(["founder", "owner", "chief_executive"]),
    );
    expect(body.data.every((entry) => entry.effective_date && entry.verified_as_of)).toBe(true);
  });

  it("keeps qualification evidence tied to the selected Coven entry and excludes it publicly", async () => {
    const repository = createDeterministicContentRepository();
    const app = createApp({ dependencies: {
      auth0Keys: [auth0Key.publicJwk], accountResolver: async () => resolvedMemberAccount,
      contentRepository: repository, publicContentRepository: repository,
    } });
    const headers = { authorization: `Bearer ${memberToken(auth0Key)}` };
    const detail = await app.request(`/v1/coven/${fixtureIds.morrow}`, { headers }, testBindings());
    const body = await detail.json() as { data: { revision_id: string; qualifications: Array<{ category: string; evidence: Array<{ factor_label: string }> }> } };
    expect(body.data.revision_id).toBe("62000000-0000-4000-8000-000000000003");
    expect(body.data.qualifications[0]).toMatchObject({ category: "owner" });
    expect(body.data.qualifications[0]?.evidence[0]?.factor_label).toContain("owner");

    const evidence = await app.request(`/v1/coven/${fixtureIds.morrow}/evidence`, { headers }, testBindings());
    const evidenceText = JSON.stringify(await evidence.json());
    expect(evidenceText).toContain("morrow-energy");
    expect(evidenceText).not.toContain("VIG");

    const publicDetail = await app.request("/v1/public/coven/morrow-energy", undefined, testBindings());
    const publicText = JSON.stringify(await publicDetail.json());
    expect(publicDetail.status).toBe(200);
    expect(publicText).not.toMatch(/person_name|https:|revision_id|tenant/i);
  });
});
