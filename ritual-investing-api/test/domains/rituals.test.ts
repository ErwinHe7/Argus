import { describe, expect, it, vi } from "vitest";

import { createApp } from "../../src/app";
import { createTestRsaKey } from "../support/jwt";
import { fakeRateLimit, memberToken, resolvedMemberAccount, testBindings } from "../support/security-fixtures";
import {
  createDeterministicContentRepository,
  deterministicPublicationControl,
  fixtureIds,
} from "../../src/domains/editorial/fixtures";

describe("member Daily Ritual", () => {
  const auth0Key = createTestRsaKey("ritual-domain-key");

  it("returns one frozen assignment for the member local day", async () => {
    const app = createApp({ dependencies: {
      auth0Keys: [auth0Key.publicJwk],
      accountResolver: async () => resolvedMemberAccount,
      contentRepository: createDeterministicContentRepository(),
    } });
    const request = () => app.request(
      "/v1/rituals/daily?date=2026-08-20&mode=tarot",
      { headers: { authorization: `Bearer ${memberToken(auth0Key)}` } },
      testBindings(),
    );

    const first = await request();
    const second = await request();
    expect(first.status).toBe(200);
    expect(second.status).toBe(200);
    const firstBody = await first.json() as { data: Record<string, unknown> };
    const secondBody = await second.json() as { data: Record<string, unknown> };
    expect(secondBody.data).toEqual(firstBody.data);
    expect(firstBody.data).toMatchObject({
      date: "2026-08-20",
      mode: "tarot",
      state: "assigned",
    });
    expect(JSON.stringify(firstBody)).not.toMatch(/tenant_id|birth_time|birthplace/i);
    expect((firstBody.data.ideas as unknown[])).toHaveLength(3);
    expect((firstBody.data.evidence as unknown[]).length).toBeGreaterThan(0);
    expect(firstBody.data.demo).toMatchObject({ is_demo: true, observed_at: expect.any(String) });
  });

  it("freezes revisions across republish and withdrawal while future assignments follow the pointer", async () => {
    const publication = deterministicPublicationControl();
    const repository = createDeterministicContentRepository(publication);
    const app = createApp({ dependencies: {
      auth0Keys: [auth0Key.publicJwk],
      accountResolver: async () => resolvedMemberAccount,
      contentRepository: repository,
    } });
    const headers = { authorization: `Bearer ${memberToken(auth0Key)}` };
    const first = await app.request("/v1/rituals/daily?date=2026-08-20&mode=tarot", { headers }, testBindings());
    const original = (await first.json() as { data: { assignment_id: string; revision: { id: string } } }).data;

    publication.ritualRevisionId = "10000000-0000-4000-8000-000000000099";
    const frozen = await app.request(`/v1/rituals/${original.assignment_id}`, { headers }, testBindings());
    expect((await frozen.json() as { data: { revision: { id: string } } }).data.revision.id).toBe(original.revision.id);
    const future = await app.request("/v1/rituals/daily?date=2026-08-21&mode=tarot", { headers }, testBindings());
    expect((await future.json() as { data: { revision: { id: string } } }).data.revision.id).toBe(publication.ritualRevisionId);

    publication.ritualAvailable = false;
    expect((await app.request(`/v1/rituals/${original.assignment_id}`, { headers }, testBindings())).status).toBe(200);
    expect((await app.request("/v1/rituals/daily?date=2026-08-22&mode=tarot", { headers }, testBindings())).status).toBe(404);
  });

  it("keeps reveal/complete retries idempotent, versioned, and non-regressing", async () => {
    const repository = createDeterministicContentRepository();
    const app = createApp({ dependencies: {
      auth0Keys: [auth0Key.publicJwk], accountResolver: async () => resolvedMemberAccount,
      contentRepository: repository,
    } });
    const headers = { authorization: `Bearer ${memberToken(auth0Key)}` };
    const assigned = await app.request("/v1/rituals/daily?date=2026-08-20", { headers }, testBindings());
    const id = (await assigned.json() as { data: { assignment_id: string } }).data.assignment_id;
    const prematureComplete = await app.request(`/v1/rituals/${id}/complete`, { method: "POST", headers: { ...headers, "if-match": '"v1"' } }, testBindings());
    expect(prematureComplete.status).toBe(409);

    const reveal = await app.request(`/v1/rituals/${id}/reveal`, { method: "POST", headers: { ...headers, "if-match": '"v1"' } }, testBindings());
    expect(reveal.headers.get("etag")).toBe('"v2"');
    const revealRetry = await app.request(`/v1/rituals/${id}/reveal`, { method: "POST", headers: { ...headers, "if-match": '"v1"' } }, testBindings());
    expect(revealRetry.headers.get("etag")).toBe('"v2"');

    const complete = await app.request(`/v1/rituals/${id}/complete`, { method: "POST", headers: { ...headers, "if-match": '"v2"' } }, testBindings());
    expect(complete.headers.get("etag")).toBe('"v3"');
    const retry = await app.request(`/v1/rituals/${id}/complete`, { method: "POST", headers: { ...headers, "if-match": '"v2"' } }, testBindings());
    const retryBody = await retry.json() as { data: { state: string; version: number } };
    expect(retryBody.data).toMatchObject({ state: "completed", version: 3 });
    const lateReveal = await app.request(`/v1/rituals/${id}/reveal`, { method: "POST", headers: { ...headers, "if-match": '"v1"' } }, testBindings());
    expect((await lateReveal.json() as { data: { state: string } }).data.state).toBe("completed");
  });

  it("routes history ahead of the UUID object route and scopes cursors to filters", async () => {
    const repository = createDeterministicContentRepository();
    const app = createApp({ dependencies: {
      auth0Keys: [auth0Key.publicJwk], accountResolver: async () => resolvedMemberAccount,
      contentRepository: repository,
    } });
    const headers = { authorization: `Bearer ${memberToken(auth0Key)}` };
    await app.request("/v1/rituals/daily?date=2026-08-20&mode=tarot", { headers }, testBindings());
    await app.request("/v1/rituals/daily?date=2026-08-21&mode=tarot", { headers }, testBindings());
    const history = await app.request("/v1/rituals/history?mode=tarot&limit=1", { headers }, testBindings());
    expect(history.status).toBe(200);
    const cursor = (await history.json() as { meta: { next_cursor: string } }).meta.next_cursor;
    const crossFilter = await app.request(`/v1/rituals/history?mode=astrology&limit=1&cursor=${encodeURIComponent(cursor)}`, { headers }, testBindings());
    expect(crossFilter.status).toBe(422);
    expect((await app.request("/v1/rituals/history?from=2026-01-01", { headers }, testBindings())).status).toBe(422);
  });

  it("returns the same not-found shape for foreign-tenant assignments", async () => {
    const repository = createDeterministicContentRepository();
    const tenantB = { ...resolvedMemberAccount, accountId: "018f3c2a-4b67-7a89-8abc-123456789002", tenantId: "018f3c2a-4b67-7a89-8abc-123456789098" };
    const app = createApp({ dependencies: {
      auth0Keys: [auth0Key.publicJwk],
      accountResolver: async (subject) => subject.endsWith("member-2") ? tenantB : resolvedMemberAccount,
      contentRepository: repository,
    } });
    const tokenA = memberToken(auth0Key);
    const tokenB = memberToken(auth0Key, { sub: "auth0|member-2" });
    const created = await app.request("/v1/rituals/daily?date=2026-08-20", { headers: { authorization: `Bearer ${tokenA}` } }, testBindings());
    const id = (await created.json() as { data: { assignment_id: string } }).data.assignment_id;
    const foreign = await app.request(`/v1/rituals/${id}`, { headers: { authorization: `Bearer ${tokenB}` } }, testBindings());
    const missing = await app.request(`/v1/rituals/${fixtureIds.assignment}`, { headers: { authorization: `Bearer ${tokenB}` } }, testBindings());
    expect([foreign.status, missing.status]).toEqual([404, 404]);
    expect((await foreign.json() as { error: { code: string } }).error.code).toBe((await missing.json() as { error: { code: string } }).error.code);
  });

  it("validates precise astrology and Rowan prompt inputs before account or repository resolution", async () => {
    const accountResolver = vi.fn(async () => resolvedMemberAccount);
    const repository = createDeterministicContentRepository();
    const resolveRowan = vi.spyOn(repository, "resolveRowan");
    const app = createApp({ dependencies: { auth0Keys: [auth0Key.publicJwk], accountResolver, contentRepository: repository } });
    const headers = { authorization: `Bearer ${memberToken(auth0Key)}` };
    expect((await app.request("/v1/rituals/daily?mode=astrology&birth_time=12%3A00", { headers }, testBindings())).status).toBe(422);
    expect((await app.request("/v1/rowan/counsel?surface=asset_codex&context_code=asset&prompt=buy", { headers }, testBindings())).status).toBe(422);
    expect(accountResolver).not.toHaveBeenCalled();
    expect(resolveRowan).not.toHaveBeenCalled();
  });

  it("enforces Rowan surface ownership/context and rejects unresolved template tokens", async () => {
    const repository = createDeterministicContentRepository();
    const app = createApp({ dependencies: {
      auth0Keys: [auth0Key.publicJwk], accountResolver: async () => resolvedMemberAccount,
      contentRepository: repository,
    } });
    const headers = { authorization: `Bearer ${memberToken(auth0Key)}` };
    const valid = await app.request(`/v1/rowan/counsel?surface=asset_codex&context_code=asset&resource_id=${fixtureIds.vig}`, { headers }, testBindings());
    expect(valid.status).toBe(200);
    expect((await valid.json() as { data: { surface: string } }).data.surface).toBe("asset_codex");
    expect((await app.request("/v1/rowan/counsel?surface=asset_codex&context_code=daily", { headers }, testBindings())).status).toBe(404);
    expect((await app.request("/v1/rowan/counsel?surface=coven&context_code=coven&resource_id=00000000-0000-4000-8000-000000000099", { headers }, testBindings())).status).toBe(404);

    const unsafeRepository = createDeterministicContentRepository();
    unsafeRepository.resolveRowan = async () => ({
      script_revision_id: fixtureIds.rowanRevision,
      surface: "daily_ritual",
      body: "Review {{prompt}} now",
      risk_footer: "Demo",
    });
    const unsafe = await createApp({ dependencies: {
      auth0Keys: [auth0Key.publicJwk], accountResolver: async () => resolvedMemberAccount,
      contentRepository: unsafeRepository,
    } }).request("/v1/rowan/counsel?surface=daily_ritual&context_code=daily", { headers }, testBindings());
    expect(unsafe.status).toBe(503);
    expect(JSON.stringify(await unsafe.json())).not.toContain("{{prompt}}");
  });

  it("enforces dual member limiter checks and fails closed without identity/storage bindings", async () => {
    const limiter = fakeRateLimit();
    const app = createApp({ dependencies: {
      auth0Keys: [auth0Key.publicJwk], accountResolver: async () => resolvedMemberAccount,
      contentRepository: createDeterministicContentRepository(),
    } });
    const response = await app.request("/v1/rituals/daily?date=2026-08-20", { headers: { authorization: `Bearer ${memberToken(auth0Key)}` } }, testBindings(limiter));
    expect(response.status).toBe(200);
    expect(limiter.keys).toHaveLength(2);

    const unavailable = await createApp({ dependencies: { auth0Keys: [auth0Key.publicJwk] } }).request(
      "/v1/rituals/daily?date=2026-08-20",
      { headers: { authorization: `Bearer ${memberToken(auth0Key)}` } },
      testBindings(),
    );
    expect(unavailable.status).toBe(503);
  });
});
