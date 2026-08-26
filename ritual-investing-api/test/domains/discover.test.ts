import { describe, expect, it } from "vitest";

import { createApp } from "../../src/app";
import { createTestRsaKey } from "../support/jwt";
import { memberToken, resolvedMemberAccount, testBindings } from "../support/security-fixtures";
import { createDeterministicContentRepository, fixtureIds } from "../../src/domains/editorial/fixtures";
import { discoverItemSchema } from "../../src/domains/editorial/schemas";

describe("published discovery catalog", () => {
  const auth0Key = createTestRsaKey("discover-domain-key");

  it("returns deterministic Grimoires, fictional creators, and Circle templates", async () => {
    const app = createApp({ dependencies: {
      auth0Keys: [auth0Key.publicJwk],
      accountResolver: async () => resolvedMemberAccount,
      contentRepository: createDeterministicContentRepository(),
    } });
    const headers = { authorization: `Bearer ${memberToken(auth0Key)}` };
    const [grimoires, creators, templates] = await Promise.all([
      app.request("/v1/grimoires", { headers }, testBindings()),
      app.request("/v1/community/creators", { headers }, testBindings()),
      app.request("/v1/circle-templates", { headers }, testBindings()),
    ]);

    expect([grimoires.status, creators.status, templates.status]).toEqual([200, 200, 200]);
    const creatorBody = await creators.json() as { data: Array<{ is_fictional: boolean }> };
    expect(creatorBody.data.length).toBeGreaterThan(0);
    expect(creatorBody.data.every((creator) => creator.is_fictional === true)).toBe(true);
  });

  it("serves every U4 discovery read path with distinct detail contracts", async () => {
    const repository = createDeterministicContentRepository();
    const app = createApp({ dependencies: {
      auth0Keys: [auth0Key.publicJwk], accountResolver: async () => resolvedMemberAccount,
      contentRepository: repository, publicContentRepository: repository,
    } });
    const headers = { authorization: `Bearer ${memberToken(auth0Key)}` };
    const routes = [
      "/v1/discover?section=asset",
      `/v1/grimoires/${fixtureIds.quietPower}`,
      `/v1/circle-templates/${fixtureIds.softPower}`,
      "/v1/search?q=durable&kinds=asset,grimoire",
      "/v1/public/discover?limit=2",
    ];
    const responses = await Promise.all(routes.map((route) => app.request(
      route,
      route.startsWith("/v1/public/") ? undefined : { headers },
      testBindings(),
    )));
    expect(responses.map((response) => response.status)).toEqual([200, 200, 200, 200, 200]);
    const publicBody = JSON.stringify(await responses[4]!.json());
    expect(publicBody).not.toMatch(/revision_id|saved|tenant_id|author_staff_id|canonical_url/i);
  });

  it("validates all mixed variants with only their matching payload", async () => {
    const repository = createDeterministicContentRepository();
    const page = await repository.listMemberDiscover(
      { ...resolvedMemberAccount, subject: "auth0|member-1" },
      { limit: 50 },
    );
    const variants = new Map(page.items.map((item) => [item.kind, item]));

    expect([...variants.keys()]).toEqual(expect.arrayContaining([
      "asset",
      "coven",
      "grimoire",
      "circle_template",
    ]));
    for (const [kind, item] of variants) {
      expect(discoverItemSchema.safeParse(item).success, kind).toBe(true);
      const payloadKeys = ["asset", "coven", "grimoire", "circle_template"]
        .filter((key) => key in item);
      expect(payloadKeys).toEqual([kind]);
      const mismatched = { ...item, asset: variants.get("asset")!.asset };
      if (kind !== "asset") {
        expect(discoverItemSchema.safeParse(mismatched).success, kind).toBe(false);
      }
    }
  });

  it("returns authoritative saved state on Grimoire and Circle-template details", async () => {
    const repository = createDeterministicContentRepository();
    const grimoire = await repository.getGrimoire(
      { ...resolvedMemberAccount, subject: "auth0|member-1" },
      fixtureIds.quietPower,
    );
    const template = await repository.getCircleTemplate(
      { ...resolvedMemberAccount, subject: "auth0|member-1" },
      fixtureIds.softPower,
    );

    expect(grimoire).toMatchObject({
      id: fixtureIds.quietPower,
      revision_id: fixtureIds.quietPowerRevision,
      saved: false,
    });
    expect(template).toMatchObject({
      id: fixtureIds.softPower,
      revision_id: fixtureIds.softPowerRevision,
      saved: false,
    });
  });
});
