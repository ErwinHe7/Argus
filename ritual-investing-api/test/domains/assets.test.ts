import { describe, expect, it, vi } from "vitest";

import { createApp } from "../../src/app";
import { createTestRsaKey } from "../support/jwt";
import { fakeRateLimit, memberToken, resolvedMemberAccount, testBindings } from "../support/security-fixtures";
import { createDeterministicContentRepository, fixtureIds } from "../../src/domains/editorial/fixtures";
import { encodeCursor } from "../../src/domains/editorial/cursor";

describe("member Asset Codex", () => {
  const auth0Key = createTestRsaKey("asset-domain-key");

  it("lists the deterministic VIG, XLV, and WOMN research fixtures", async () => {
    const response = await createApp({
      dependencies: {
        auth0Keys: [auth0Key.publicJwk],
        accountResolver: async () => resolvedMemberAccount,
        contentRepository: createDeterministicContentRepository(),
      },
    }).request(
      "/v1/assets?limit=20",
      { headers: { authorization: `Bearer ${memberToken(auth0Key)}` } },
      testBindings(),
    );

    expect(response.status).toBe(200);
    const body = await response.json() as { data: Array<{ symbol: string }> };
    expect(body.data.map((asset) => asset.symbol)).toEqual(["VIG", "WOMN", "XLV"]);
  });

  it("rejects unsafe search syntax before content lookup", async () => {
    const accountResolver = vi.fn(async () => resolvedMemberAccount);
    const repository = createDeterministicContentRepository();
    const search = vi.spyOn(repository, "search");
    const response = await createApp({
      dependencies: {
        auth0Keys: [auth0Key.publicJwk],
        accountResolver,
        contentRepository: repository,
      },
    }).request(
      "/v1/search?q=status%3Apublished.*&kinds=asset",
      { headers: { authorization: `Bearer ${memberToken(auth0Key)}` } },
      testBindings(),
    );
    expect(response.status).toBe(422);
    expect(accountResolver).not.toHaveBeenCalled();
    expect(search).not.toHaveBeenCalled();
    for (const query of ["status", "status.", "tenant_id", "vig%5B.*%5D", "a".repeat(101)]) {
      const unsafe = await createApp({ dependencies: {
        auth0Keys: [auth0Key.publicJwk], accountResolver, contentRepository: repository,
      } }).request(`/v1/search?q=${query}&kinds=asset`, { headers: { authorization: `Bearer ${memberToken(auth0Key)}` } }, testBindings());
      expect(unsafe.status, query).toBe(422);
    }
    expect(accountResolver).not.toHaveBeenCalled();
    expect(search).not.toHaveBeenCalled();
  });

  it("returns allowlisted asset details and source lineage only from evidence routes", async () => {
    const app = createApp({ dependencies: {
      auth0Keys: [auth0Key.publicJwk], accountResolver: async () => resolvedMemberAccount,
      contentRepository: createDeterministicContentRepository(),
    } });
    const headers = { authorization: `Bearer ${memberToken(auth0Key)}` };
    const detail = await app.request(`/v1/assets/${fixtureIds.womn}`, { headers }, testBindings());
    const detailBody = await detail.json() as { data: { symbol: string; evidence: Array<{ factor_label: string }> } };
    expect(detailBody.data).toMatchObject({ symbol: "WOMN" });
    expect(detailBody.data.evidence[0]?.factor_label).toBe("Leadership breadth");
    expect(JSON.stringify(detailBody)).not.toContain("_change");
    expect(JSON.stringify(detailBody)).not.toContain("canonical_url");

    const evidence = await app.request(`/v1/assets/${fixtureIds.womn}/evidence`, { headers }, testBindings());
    expect((await evidence.json() as { data: Array<{ source: { url: string } }> }).data[0]?.source.url).toContain("/womn");
  });

  it("uses signed scoped cursors and returns stale cursor errors", async () => {
    const app = createApp({ dependencies: {
      auth0Keys: [auth0Key.publicJwk], accountResolver: async () => resolvedMemberAccount,
      contentRepository: createDeterministicContentRepository(),
    } });
    const headers = { authorization: `Bearer ${memberToken(auth0Key)}` };
    const first = await app.request("/v1/assets?limit=1", { headers }, testBindings());
    const cursor = (await first.json() as { meta: { next_cursor: string } }).meta.next_cursor;
    expect((await app.request(`/v1/assets?asset_type=etf&limit=1&cursor=${encodeURIComponent(cursor)}`, { headers }, testBindings())).status).toBe(422);
    const stale = await encodeCursor(testBindings().CURSOR_SIGNING_KEY!, "assets:all:all", "UNKNOWN|00000000-0000-4000-8000-000000000000");
    expect((await app.request(`/v1/assets?cursor=${encodeURIComponent(stale)}`, { headers }, testBindings())).status).toBe(422);
  });

  it("enforces search dual rate limits and compare media/body contracts", async () => {
    const limiter = fakeRateLimit();
    const app = createApp({ dependencies: {
      auth0Keys: [auth0Key.publicJwk], accountResolver: async () => resolvedMemberAccount,
      contentRepository: createDeterministicContentRepository(),
    } });
    const authorization = `Bearer ${memberToken(auth0Key)}`;
    const search = await app.request("/v1/search?q=VIG&kinds=asset", { headers: { authorization } }, testBindings(limiter));
    expect(search.status).toBe(200);
    expect(limiter.keys).toHaveLength(2);

    const media = await app.request("/v1/assets/compare", { method: "POST", headers: { authorization, "content-type": "text/plain" }, body: "nope" }, testBindings());
    expect(media.status).toBe(415);
    const missing = await app.request("/v1/assets/compare", { method: "POST", headers: { authorization, "content-type": "application/json" } }, testBindings());
    expect(missing.status).toBe(422);
    const malformed = await app.request("/v1/assets/compare", { method: "POST", headers: { authorization, "content-type": "application/json" }, body: "{" }, testBindings());
    expect(malformed.status).toBe(422);
    expect((await malformed.json() as { error: { message: string } }).error.message).toBe("The request is invalid.");
    expect(malformed.headers.get("cache-control")).toBe("private, no-store");
    const tooFew = await app.request("/v1/assets/compare", { method: "POST", headers: { authorization, "content-type": "application/json" }, body: JSON.stringify({ asset_ids: [fixtureIds.vig] }) }, testBindings());
    expect(tooFew.status).toBe(422);
    const extra = await app.request("/v1/assets/compare", { method: "POST", headers: { authorization, "content-type": "application/json" }, body: JSON.stringify({ asset_ids: [fixtureIds.vig, fixtureIds.xlv], fields: ["tenant_id"] }) }, testBindings());
    expect(extra.status).toBe(422);
    const oversized = await app.request("/v1/assets/compare", { method: "POST", headers: { authorization, "content-type": "application/json" }, body: JSON.stringify({ asset_ids: [fixtureIds.vig, fixtureIds.xlv], padding: "x".repeat(70_000) }) }, testBindings());
    expect(oversized.status).toBe(413);
  });
});
