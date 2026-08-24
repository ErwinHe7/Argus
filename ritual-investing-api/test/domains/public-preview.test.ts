import { describe, expect, it, vi } from "vitest";

import { createApp } from "../../src/app";
import { fakeRateLimit, testBindings } from "../support/security-fixtures";
import { createDeterministicContentRepository } from "../../src/domains/editorial/fixtures";
import { deterministicPublicationControl } from "../../src/domains/editorial/fixtures";
import type { ProjectionCache } from "../../src/domains/editorial/route-support";

describe("public editorial previews", () => {
  it("returns only the published Daily Ritual preview allowlist", async () => {
    const response = await createApp({
      dependencies: {
        publicContentRepository: createDeterministicContentRepository(),
        now: () => new Date("2026-08-24T12:00:00.000Z"),
      },
    }).request(
      "/v1/public/rituals/daily?date=2026-08-20&mode=tarot",
      undefined,
      testBindings(),
    );

    expect(response.status).toBe(200);
    const body = await response.json() as { data: Record<string, unknown> };
    expect(body.data).toMatchObject({
      date: "2026-08-20",
      mode: "tarot",
      title: "Direction, not urgency.",
    });
    expect(JSON.stringify(body)).not.toMatch(
      /tenant|saved|source_url|canonical_url|guidance|draft|person_name/i,
    );
    expect(response.headers.get("etag")).toMatch(/^"pub-/);
    expect(response.headers.get("cache-control")).toContain("public");
  });

  it("throttles before a public repository can run", async () => {
    const limiter = fakeRateLimit([false]);
    const loadDaily = vi.fn();
    const response = await createApp({
      dependencies: { publicContentRepository: { loadDaily } },
    } as never).request(
      "/v1/public/rituals/daily?date=2026-08-20&mode=tarot",
      undefined,
      testBindings(limiter),
    );

    expect(response.status).toBe(429);
    expect(response.headers.get("retry-after")).toBe("60");
    expect(loadDaily).not.toHaveBeenCalled();
  });

  it("uses host-safe revision cache keys, avoids heavy loads on hits, and fails open when cache access fails", async () => {
    const repository = createDeterministicContentRepository();
    const load = vi.spyOn(repository, "listDiscover");
    const entries = new Map<string, Response>();
    const seen: string[] = [];
    const cache: ProjectionCache = {
      async match(request) {
        seen.push(request.url);
        return entries.get(request.url)?.clone();
      },
      async put(request, response) {
        entries.set(request.url, response.clone());
      },
    };
    const app = createApp({ dependencies: { publicContentRepository: repository, projectionCache: cache } });

    const first = await app.request(
      "https://attacker.invalid/v1/public/discover?limit=1",
      { headers: { authorization: "Bearer ignored", cookie: "tenant_canary=secret" } },
      testBindings(),
    );
    const second = await app.request(
      "https://another.invalid/v1/public/discover?limit=1",
      undefined,
      testBindings(),
    );

    expect([first.status, second.status]).toEqual([200, 200]);
    expect(load).toHaveBeenCalledTimes(1);
    expect(seen).toHaveLength(2);
    expect(new URL(seen[0]!).origin).toBe("https://api.ritual-investing.test");
    expect(seen[1]).toBe(seen[0]);
    expect(JSON.stringify(await second.json())).not.toContain("tenant_canary");

    const failingCache: ProjectionCache = {
      async match() { throw new Error("cache_down"); },
      async put() { throw new Error("cache_down"); },
    };
    const fresh = await createApp({ dependencies: {
      publicContentRepository: repository,
      projectionCache: failingCache,
    } }).request("/v1/public/discover?limit=1", undefined, testBindings());
    expect(fresh.status).toBe(200);
    expect(load).toHaveBeenCalledTimes(2);
  });

  it("binds signed public cursors and caches to the publication revision", async () => {
    const publication = deterministicPublicationControl();
    const repository = createDeterministicContentRepository(publication);
    const list = vi.spyOn(repository, "listDiscover");
    const app = createApp({ dependencies: { publicContentRepository: repository } });
    const first = await app.request("/v1/public/discover?limit=1", undefined, testBindings());
    const body = await first.json() as { meta: { next_cursor: string } };
    expect(body.meta.next_cursor.split(".")).toHaveLength(2);

    const tampered = `${body.meta.next_cursor.slice(0, -1)}x`;
    expect((await app.request(`/v1/public/discover?limit=1&cursor=${encodeURIComponent(tampered)}`, undefined, testBindings())).status).toBe(422);
    expect((await app.request(`/v1/public/coven?limit=1&cursor=${encodeURIComponent(body.meta.next_cursor)}`, undefined, testBindings())).status).toBe(422);

    publication.catalogRevisionId = "10000000-0000-4000-8000-000000000099";
    const stale = await app.request(
      `/v1/public/discover?limit=1&cursor=${encodeURIComponent(body.meta.next_cursor)}`,
      undefined,
      testBindings(),
    );
    expect(stale.status).toBe(422);
    expect(list).toHaveBeenCalledTimes(1);

    const etag = first.headers.get("etag")!;
    const unchanged = await app.request("/v1/public/discover?limit=1", { headers: { "if-none-match": etag } }, testBindings());
    expect(unchanged.status).toBe(200);
    publication.catalogAvailable = false;
    const withdrawn = await app.request("/v1/public/discover?limit=1", undefined, testBindings());
    expect(withdrawn.status).toBe(200);
    expect((await withdrawn.json() as { data: unknown[] }).data).toEqual([]);
    expect(withdrawn.headers.get("etag")).not.toBe(etag);
  });

  it("rejects a repository tenant canary at the strict public serializer boundary", async () => {
    const repository = createDeterministicContentRepository();
    const original = repository.loadDaily.bind(repository);
    repository.loadDaily = async (input, revisionId) => ({
      ...await original(input, revisionId),
      tenant_id: "tenant-canary",
    } as never);
    const response = await createApp({ dependencies: {
      publicContentRepository: repository,
      now: () => new Date("2026-08-24T12:00:00.000Z"),
    } }).request("/v1/public/rituals/daily?date=2026-08-24", undefined, testBindings());
    expect(response.status).toBe(503);
    expect(JSON.stringify(await response.json())).not.toContain("tenant-canary");
  });

  it("fails closed when the restricted public database binding is absent", async () => {
    const response = await createApp().request(
      "/v1/public/rituals/daily?date=2026-08-24",
      undefined,
      testBindings(),
    );
    expect(response.status).toBe(503);
  });
});
