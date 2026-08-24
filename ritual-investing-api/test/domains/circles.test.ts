import { randomUUID } from "node:crypto";

import pg from "pg";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";

import { createApp } from "../../src/app";
import { applyReviewedMigrations } from "../../scripts/migrate";
import { createTestRsaKey } from "../support/jwt";
import {
  fakeRateLimit,
  memberToken,
  resolvedMemberAccount,
  testBindings,
} from "../support/security-fixtures";

describe("private Circles and saves", () => {
  const auth0Key = createTestRsaKey("private-circle-key");
  const circleId = "018f3c2a-4b67-7a89-8abc-123456789071";
  const foreignId = "018f3c2a-4b67-7a89-8abc-123456789072";

  function app(repository: Record<string, unknown>) {
    return createApp({
      dependencies: {
        auth0Keys: [auth0Key.publicJwk],
        accountResolver: vi.fn(async () => resolvedMemberAccount),
        memberRepository: repository,
      },
    } as never);
  }

  const headers = () => ({ authorization: `Bearer ${memberToken(auth0Key)}` });

  it("makes foreign and unknown Circle IDs indistinguishable for reads and every mutation", async () => {
    const getCircle = vi.fn(async (_context: unknown, _id: string) => null);
    const application = app({
      getCircle,
      patchCircle: vi.fn(async () => null),
      archiveCircle: vi.fn(async () => false),
      putCircleAsset: vi.fn(async () => null),
      deleteCircleAsset: vi.fn(async () => null),
    });
    const requests = (id: string) => [
      application.request(
        `/v1/circles/${id}`,
        { headers: headers() },
        testBindings(),
      ),
      application.request(
        `/v1/circles/${id}`,
        {
          method: "PATCH",
          headers: {
            ...headers(),
            "content-type": "application/json",
            "if-match": '"v1"',
          },
          body: JSON.stringify({ title: "Private" }),
        },
        testBindings(),
      ),
      application.request(
        `/v1/circles/${id}`,
        { method: "DELETE", headers: { ...headers(), "if-match": '"v1"' } },
        testBindings(),
      ),
      application.request(
        `/v1/circles/${id}/assets/018f3c2a-4b67-7a89-8abc-123456789081`,
        {
          method: "PUT",
          headers: {
            ...headers(),
            "content-type": "application/json",
            "if-match": '"v1"',
          },
          body: JSON.stringify({ ordinal: 1 }),
        },
        testBindings(),
      ),
      application.request(
        `/v1/circles/${id}/assets/018f3c2a-4b67-7a89-8abc-123456789081`,
        { method: "DELETE", headers: { ...headers(), "if-match": '"v1"' } },
        testBindings(),
      ),
    ];
    for (const response of await Promise.all([
      ...requests(circleId),
      ...requests(foreignId),
    ])) {
      expect(response.status).toBe(404);
      expect(await response.json()).toMatchObject({
        error: { code: "not_found" },
      });
    }
  });

  it("rejects duplicate assets and more than fifty assets", async () => {
    const createCircle = vi.fn();
    const application = app({ createCircle });
    const asset = "018f3c2a-4b67-7a89-8abc-123456789081";
    const makeRequest = (assets: unknown[]) =>
      application.request(
        "/v1/circles",
        {
          method: "POST",
          headers: {
            ...headers(),
            "content-type": "application/json",
            "idempotency-key": "create-circle-01K3RITUALSAFE",
          },
          body: JSON.stringify({
            title: "Moon fund",
            description: "Private",
            assets,
          }),
        },
        testBindings(),
      );

    expect(
      (
        await makeRequest([
          { asset_id: asset, ordinal: 1 },
          { asset_id: asset, ordinal: 2 },
        ])
      ).status,
    ).toBe(422);
    expect(
      (await makeRequest([{ asset_id: asset, ordinal: 1, weight_bps: 9999 }]))
        .status,
    ).toBe(422);
    expect(
      (
        await makeRequest(
          Array.from({ length: 51 }, (_, index) => ({
            asset_id: `018f3c2a-4b67-7a89-8abc-${String(100000000000 + index)}`,
            ordinal: index + 1,
          })),
        )
      ).status,
    ).toBe(422);
    expect(createCircle).not.toHaveBeenCalled();
  });

  it("retries template copy with one key and returns the frozen revision", async () => {
    const copyTemplate = vi.fn(
      async (_context: unknown, _id: string, _key: string) => ({
        id: circleId,
        title: "Copied circle",
        description: "Private copy",
        private: true,
        source_template_id: "018f3c2a-4b67-7a89-8abc-123456789091",
        source_revision_id: "018f3c2a-4b67-7a89-8abc-123456789092",
        assets: [],
        version: 1,
        archived_at: null,
      }),
    );
    const application = app({ copyTemplate });
    const request = () =>
      application.request(
        "/v1/circle-templates/018f3c2a-4b67-7a89-8abc-123456789091/copies",
        {
          method: "POST",
          headers: {
            ...headers(),
            "content-type": "application/json",
            "idempotency-key": "copy-template-01K3RITUALSAFE",
          },
          body: JSON.stringify({ title: "Copied circle" }),
        },
        testBindings(),
      );

    const first = await request();
    const replay = await request();
    expect(first.status).toBe(201);
    expect(replay.status).toBe(201);
    expect(await replay.json()).toMatchObject({
      data: { source_revision_id: "018f3c2a-4b67-7a89-8abc-123456789092" },
    });
    expect(copyTemplate.mock.calls[0]?.[2]).toBe(
      copyTemplate.mock.calls[1]?.[2],
    );
  });

  it("implements retry-safe saves through the authenticated tenant context", async () => {
    const save = vi.fn(async () => ({
      saved: true,
      saved_at: "2026-08-24T04:00:00.000Z",
    }));
    const application = app({ save });
    const response = await application.request(
      "/v1/me/saved-assets/018f3c2a-4b67-7a89-8abc-123456789081",
      {
        method: "PUT",
        headers: { ...headers(), "content-type": "application/json" },
        body: JSON.stringify({ source_kind: "circle", source_id: circleId }),
      },
      testBindings(),
    );

    expect(response.status).toBe(200);
    expect(save).toHaveBeenCalledWith(
      expect.objectContaining({ tenantId: resolvedMemberAccount.tenantId }),
      "asset",
      expect.any(String),
      expect.any(Object),
    );
  });

  it("supports empty template-copy bodies and emits the copied Circle ETag", async () => {
    const copyTemplate = vi.fn(async () => ({
      id: circleId,
      title: "Frozen",
      description: "Copy",
      private: true,
      source_template_id: null,
      source_revision_id: null,
      assets: [],
      version: 1,
      archived_at: null,
    }));
    const application = app({ copyTemplate });
    const response = await application.request(
      "/v1/circle-templates/018f3c2a-4b67-7a89-8abc-123456789091/copies",
      {
        method: "POST",
        headers: {
          ...headers(),
          "idempotency-key": "copy-template-01K3RITUALSAFE",
        },
      },
      testBindings(),
    );
    expect(response.status).toBe(201);
    expect(response.headers.get("etag")).toBe('"v1"');
    expect(copyTemplate).toHaveBeenCalledWith(
      expect.any(Object),
      expect.any(String),
      expect.any(String),
      {},
    );
  });

  it("binds signed Circle cursors to the tenant and archived filter without N+1 repository calls", async () => {
    const listCircles = vi
      .fn()
      .mockResolvedValueOnce({
        items: [
          {
            id: circleId,
            title: "One",
            description: "",
            private: true,
            source_template_id: null,
            source_revision_id: null,
            assets: [],
            version: 1,
            archived_at: null,
          },
        ],
        nextPosition: circleId,
      })
      .mockResolvedValueOnce({ items: [], nextPosition: null });
    const application = app({ listCircles });
    const first = await application.request(
      "/v1/circles?limit=1",
      { headers: headers() },
      testBindings(),
    );
    expect(first.status).toBe(200);
    const cursor = ((await first.json()) as { meta: { next_cursor: string } })
      .meta.next_cursor;
    const second = await application.request(
      `/v1/circles?limit=1&cursor=${encodeURIComponent(cursor)}`,
      { headers: headers() },
      testBindings(),
    );
    expect(second.status).toBe(200);
    expect(listCircles).toHaveBeenCalledTimes(2);
    expect(listCircles.mock.calls[1]?.[1]).toMatchObject({
      after: circleId,
      archived: "exclude",
      limit: 1,
    });
    expect(
      (
        await application.request(
          `/v1/circles?archived=only&cursor=${encodeURIComponent(cursor)}`,
          { headers: headers() },
          testBindings(),
        )
      ).status,
    ).toBe(422);
  });

  it("runs exactly one read or write limiter chain on shared paths", async () => {
    const read = fakeRateLimit();
    const write = fakeRateLimit();
    const bindings = {
      ...testBindings(),
      RL_MEMBER_READ: read,
      RL_MEMBER_WRITE: write,
    };
    const application = app({
      listCircles: vi.fn(async () => ({ items: [], nextPosition: null })),
      createCircle: vi.fn(async () => ({
        id: circleId,
        title: "One",
        description: "",
        private: true,
        source_template_id: null,
        source_revision_id: null,
        assets: [],
        version: 1,
        archived_at: null,
      })),
    });
    expect(
      (
        await application.request(
          "/v1/circles",
          { headers: headers() },
          bindings,
        )
      ).status,
    ).toBe(200);
    expect(read.keys).toHaveLength(2);
    expect(write.keys).toHaveLength(0);
    expect(
      (
        await application.request(
          "/v1/circles",
          {
            method: "POST",
            headers: {
              ...headers(),
              "content-type": "application/json",
              "idempotency-key": "create-circle-01K3RITUALSAFE",
            },
            body: JSON.stringify({ title: "One" }),
          },
          bindings,
        )
      ).status,
    ).toBe(201);
    expect(read.keys).toHaveLength(2);
    expect(write.keys).toHaveLength(2);
  });

  it("rejects incomplete save attribution before tenant-scoped lookup", async () => {
    const save = vi.fn();
    const application = app({ save });
    const response = await application.request(
      "/v1/me/saved-assets/018f3c2a-4b67-7a89-8abc-123456789081",
      {
        method: "PUT",
        headers: { ...headers(), "content-type": "application/json" },
        body: JSON.stringify({ source_kind: "ritual" }),
      },
      testBindings(),
    );
    expect(response.status).toBe(422);
    expect(save).not.toHaveBeenCalled();
  });

  it("runs one write limiter chain for each save PUT and DELETE method", async () => {
    const write = fakeRateLimit();
    const read = fakeRateLimit();
    const bindings = {
      ...testBindings(),
      RL_MEMBER_READ: read,
      RL_MEMBER_WRITE: write,
    };
    const application = app({
      save: vi.fn(async () => ({
        saved: true,
        saved_at: "2026-08-24T04:00:00.000Z",
      })),
      unsave: vi.fn(async () => undefined),
    });
    const path = "/v1/me/saved-assets/018f3c2a-4b67-7a89-8abc-123456789081";
    expect(
      (
        await application.request(
          path,
          { method: "PUT", headers: headers() },
          bindings,
        )
      ).status,
    ).toBe(200);
    expect(write.keys).toHaveLength(2);
    expect(read.keys).toHaveLength(0);
    expect(
      (
        await application.request(
          path,
          { method: "DELETE", headers: headers() },
          bindings,
        )
      ).status,
    ).toBe(204);
    expect(write.keys).toHaveLength(4);
    expect(read.keys).toHaveLength(0);

    const readOnly = {
      authorization: `Bearer ${memberToken(auth0Key, { permissions: ["read:self"] })}`,
    };
    expect(
      (
        await application.request(
          path,
          { method: "PUT", headers: readOnly },
          testBindings(),
        )
      ).status,
    ).toBe(403);
  });
});

const postgresUrl = process.env.TEST_DATABASE_URL;
const describePostgres = postgresUrl === undefined ? describe.skip : describe;

describePostgres("private Circle PostgreSQL invariants", () => {
  const tenantA = randomUUID();
  const tenantB = randomUUID();
  const accountA = randomUUID();
  const accountB = randomUUID();
  const subjectA = `auth0|u5-a-${randomUUID()}`;
  const subjectB = `auth0|u5-b-${randomUUID()}`;
  const assetA = "20000000-0000-4000-8000-000000000001";
  const assetB = "20000000-0000-4000-8000-000000000002";
  const templateId = "50000000-0000-4000-8000-000000000002";
  let owner: pg.Client;

  beforeAll(async () => {
    await applyReviewedMigrations(postgresUrl!);
    owner = new pg.Client({ connectionString: postgresUrl! });
    await owner.connect();
    await owner.query(
      "insert into tenants(id,status) values($1,'active'),($2,'active')",
      [tenantA, tenantB],
    );
    await owner.query(
      "insert into accounts(id,tenant_id,auth0_subject,status) values($1,$2,$3,'active'),($4,$5,$6,'active')",
      [accountA, tenantA, subjectA, accountB, tenantB, subjectB],
    );
  }, 30_000);
  afterAll(async () => {
    await owner?.end();
  });

  async function runtime<
    T = { rows: Array<Record<string, unknown>>; rowCount: number },
  >(
    tenant: string,
    account: string,
    sql: string,
    parameters: unknown[] = [],
  ): Promise<T> {
    const client = new pg.Client({ connectionString: postgresUrl! });
    await client.connect();
    try {
      await client.query("begin");
      await client.query("set local role ritual_runtime");
      await client.query(
        "select set_config('ritual.tenant_id',$1,true),set_config('ritual.principal',$2,true),set_config('ritual.account_id',$3,true),set_config('ritual.revocation_epoch','0',true)",
        [tenant, `test|${account}`, account],
      );
      const result = await client.query(sql, parameters);
      await client.query("commit");
      return result as T;
    } catch (error) {
      await client.query("rollback");
      throw error;
    } finally {
      await client.end();
    }
  }

  it("enforces initial cap, uniqueness, child, and total-weight invariants inside PostgreSQL", async () => {
    const valid = JSON.stringify([
      { asset_id: assetA, ordinal: 1, weight_bps: 6000 },
      { asset_id: assetB, ordinal: 2, weight_bps: 4000 },
    ]);
    const first = await runtime<any>(
      tenantA,
      accountA,
      "select circle_id from ritual_private.create_circle($1,$2,'Weighted','',$3::jsonb)",
      [tenantA, "db-create-circle-01K3SAFE", valid],
    );
    const replay = await runtime<any>(
      tenantA,
      accountA,
      "select circle_id from ritual_private.create_circle($1,$2,'Weighted','',$3::jsonb)",
      [tenantA, "db-create-circle-01K3SAFE", valid],
    );
    expect(replay.rows[0].circle_id).toBe(first.rows[0].circle_id);
    await expect(
      runtime(
        tenantA,
        accountA,
        "select circle_id from ritual_private.create_circle($1,$2,'Different','',$3::jsonb)",
        [tenantA, "db-create-circle-01K3SAFE", valid],
      ),
    ).rejects.toThrow(/idempotency_conflict/);
    expect(
      (
        await runtime<any>(
          tenantA,
          accountA,
          "select count(*)::int as count from circles where tenant_id=$1",
          [tenantA],
        )
      ).rows[0].count,
    ).toBe(1);
    await expect(
      runtime(
        tenantA,
        accountA,
        "select circle_id from ritual_private.create_circle($1,$2,'Bad','',$3::jsonb)",
        [
          tenantA,
          "db-create-circle-duplicate",
          JSON.stringify([
            { asset_id: assetA, ordinal: 1 },
            { asset_id: assetA, ordinal: 2 },
          ]),
        ],
      ),
    ).rejects.toThrow(/duplicate_asset/);
    await expect(
      runtime(
        tenantA,
        accountA,
        "select circle_id from ritual_private.create_circle($1,$2,'Bad','',$3::jsonb)",
        [
          tenantA,
          "db-create-circle-weighted",
          JSON.stringify([{ asset_id: assetA, ordinal: 1, weight_bps: 9999 }]),
        ],
      ),
    ).rejects.toThrow(/invalid_weight_total/);
    await expect(
      runtime(
        tenantA,
        accountA,
        "select circle_id from ritual_private.create_circle($1,$2,'Bad','',$3::jsonb)",
        [
          tenantA,
          "db-create-circle-child",
          JSON.stringify([{ asset_id: randomUUID(), ordinal: 1 }]),
        ],
      ),
    ).rejects.toThrow(/invalid_child/);
    const tooMany = Array.from({ length: 51 }, (_, index) => ({
      asset_id: randomUUID(),
      ordinal: index + 1,
    }));
    await expect(
      runtime(
        tenantA,
        accountA,
        "select circle_id from ritual_private.create_circle($1,$2,'Bad','',$3::jsonb)",
        [tenantA, "db-create-circle-cap", JSON.stringify(tooMany)],
      ),
    ).rejects.toThrow(/asset_cap/);
  });

  it("makes foreign and unknown Circle reads and all mutations indistinguishable at the SQL boundary", async () => {
    const foreignCircle = randomUUID();
    const unknownCircle = randomUUID();
    await owner.query(
      "insert into circles(id,tenant_id,title,description) values($1,$2,'Foreign','')",
      [foreignCircle, tenantB],
    );
    for (const id of [foreignCircle, unknownCircle]) {
      expect(
        (
          await runtime<any>(
            tenantA,
            accountA,
            "select id from circles where tenant_id=$1 and id=$2",
            [tenantA, id],
          )
        ).rowCount,
      ).toBe(0);
      expect(
        (
          await runtime<any>(
            tenantA,
            accountA,
            "update circles set title='Nope' where tenant_id=$1 and id=$2 and version=1 returning id",
            [tenantA, id],
          )
        ).rowCount,
      ).toBe(0);
      expect(
        (
          await runtime<any>(
            tenantA,
            accountA,
            "update circles set archived_at=now() where tenant_id=$1 and id=$2 and version=1 returning id",
            [tenantA, id],
          )
        ).rowCount,
      ).toBe(0);
      expect(
        (
          await runtime<any>(
            tenantA,
            accountA,
            "select * from ritual_private.put_circle_asset($1,$2,$3,1,1,null,null)",
            [tenantA, id, assetA],
          )
        ).rowCount,
      ).toBe(0);
      expect(
        (
          await runtime<any>(
            tenantA,
            accountA,
            "select * from ritual_private.delete_circle_asset($1,$2,$3,1)",
            [tenantA, id, assetA],
          )
        ).rowCount,
      ).toBe(0);
    }
  });

  it("rolls back asset mutations that would break an all-or-none 10000 bps allocation", async () => {
    const assets = JSON.stringify([
      { asset_id: assetA, ordinal: 1, weight_bps: 6000 },
      { asset_id: assetB, ordinal: 2, weight_bps: 4000 },
    ]);
    const created = await runtime<any>(
      tenantA,
      accountA,
      "select circle_id from ritual_private.create_circle($1,$2,'Atomic weights','',$3::jsonb)",
      [tenantA, "db-atomic-circle-01K3SAFE", assets],
    );
    const circle = created.rows[0].circle_id;

    await expect(
      runtime(
        tenantA,
        accountA,
        "select * from ritual_private.delete_circle_asset($1,$2,$3,1)",
        [tenantA, circle, assetB],
      ),
    ).rejects.toThrow(/invalid_weight_total/);
    await expect(
      runtime(
        tenantA,
        accountA,
        "select * from ritual_private.put_circle_asset($1,$2,$3,1,3,null,null)",
        [tenantA, circle, "20000000-0000-4000-8000-000000000003"],
      ),
    ).rejects.toThrow(/invalid_weight_total/);

    const unchanged = await runtime<any>(
      tenantA,
      accountA,
      "select c.version,count(a.asset_id)::int as asset_count,sum(a.weight_bps)::int as total from circles c join circle_assets a on a.tenant_id=c.tenant_id and a.circle_id=c.id where c.tenant_id=$1 and c.id=$2 group by c.version",
      [tenantA, circle],
    );
    expect(unchanged.rows[0]).toMatchObject({
      version: 1,
      asset_count: 2,
      total: 10000,
    });
  });

  it("keeps consent decisions immutable and replays one exact database receipt", async () => {
    const insert = `insert into consent_records(tenant_id,policy_code,policy_version,decision) values($1,'terms','u5','accepted') on conflict(tenant_id,policy_code,policy_version,decision) do nothing returning id,recorded_at`;
    const first = await runtime<any>(tenantA, accountA, insert, [tenantA]);
    const second = await runtime<any>(tenantA, accountA, insert, [tenantA]);
    expect(first.rowCount).toBe(1);
    expect(second.rowCount).toBe(0);
    const receipt = await runtime<any>(
      tenantA,
      accountA,
      "select id,recorded_at from consent_records where tenant_id=$1 and policy_code='terms' and policy_version='u5' and decision='accepted'",
      [tenantA],
    );
    expect(receipt.rows).toHaveLength(1);
    expect(receipt.rows[0].id).toBe(first.rows[0].id);
    expect(new Date(receipt.rows[0].recorded_at).toISOString()).toBe(
      new Date(first.rows[0].recorded_at).toISOString(),
    );
    await expect(
      owner.query(
        "update consent_records set decision='withdrawn' where id=$1",
        [first.rows[0].id],
      ),
    ).rejects.toThrow(/immutable/i);
  });

  it("freezes template provenance and rejects foreign save source context", async () => {
    const copied = await runtime<any>(
      tenantA,
      accountA,
      "select circle_id from ritual_private.copy_circle_template($1,$2,$3,null)",
      [tenantA, templateId, "db-copy-template-01K3SAFE"],
    );
    const before = await runtime<any>(
      tenantA,
      accountA,
      "select source_revision_id from circles where tenant_id=$1 and id=$2",
      [tenantA, copied.rows[0].circle_id],
    );
    expect(before.rows[0].source_revision_id).toBe(
      "50000000-0000-4000-8000-000000000003",
    );
    const replacement = randomUUID();
    await owner.query(
      "insert into editorial_revisions(id,item_id,revision_number,state,author_staff_id,content_hash) select $1,'51000000-0000-4000-8000-000000000001',coalesce(max(revision_number),0)+1,'published','90000000-0000-4000-8000-000000000001',$2 from editorial_revisions where item_id='51000000-0000-4000-8000-000000000001'",
      [replacement, `u5-template-${replacement}`],
    );
    await owner.query(
      "insert into circle_template_revisions(revision_id,title,description) values($1,'Republished title','Republished description')",
      [replacement],
    );
    await owner.query(
      "insert into circle_template_assets(revision_id,asset_id,ordinal,weight_bps,note) select $1,asset_id,ordinal,weight_bps,note from circle_template_assets where revision_id='50000000-0000-4000-8000-000000000003'",
      [replacement],
    );
    await owner.query(
      "update editorial_items set current_published_revision_id=$1 where id='51000000-0000-4000-8000-000000000001'",
      [replacement],
    );
    const after = await runtime<any>(
      tenantA,
      accountA,
      "select source_revision_id,title from circles where tenant_id=$1 and id=$2",
      [tenantA, copied.rows[0].circle_id],
    );
    expect(after.rows[0]).toMatchObject({
      source_revision_id: "50000000-0000-4000-8000-000000000003",
      title: "Soft Power Portfolio",
    });
    await owner.query(
      "update editorial_items set current_published_revision_id='50000000-0000-4000-8000-000000000003' where id='51000000-0000-4000-8000-000000000001'",
    );
    const foreignSource = randomUUID();
    await owner.query(
      "insert into circles(id,tenant_id,title,description) values($1,$2,'Foreign source','')",
      [foreignSource, tenantB],
    );
    expect(
      (
        await runtime<any>(
          tenantA,
          accountA,
          "select * from ritual_private.save_member_item($1,'asset',$2,$3::jsonb)",
          [
            tenantA,
            assetA,
            JSON.stringify({ source_kind: "circle", source_id: foreignSource }),
          ],
        )
      ).rowCount,
    ).toBe(0);
  });
});
