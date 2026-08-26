import { randomUUID } from "node:crypto";

import pg from "pg";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

import { createApp } from "../../src/app";
import type { DatabasePoolFactory } from "../../src/db/client";
import {
  createPostgresMemberContentRepository,
  createPostgresPublicContentRepository,
} from "../../src/domains/editorial/postgres-repository";
import { applyReviewedMigrations } from "../../scripts/migrate";
import { createTestRsaKey } from "../support/jwt";
import { memberToken, testBindings } from "../support/security-fixtures";

const postgresUrl = process.env.TEST_DATABASE_URL;
const describePostgres = postgresUrl === undefined ? describe.skip : describe;

describePostgres("PostgreSQL editorial projections", () => {
  const auth0Key = createTestRsaKey("editorial-postgres-key");
  const tenantA = randomUUID();
  const accountA = randomUUID();
  const tenantB = randomUUID();
  const accountB = randomUUID();
  const subjectA = `auth0|u4-a-${randomUUID()}`;
  const subjectB = `auth0|u4-b-${randomUUID()}`;
  let owner: pg.Client;
  const nodePoolFactory: DatabasePoolFactory = (databaseUrl) => {
    const pool = new pg.Pool({ connectionString: databaseUrl, max: 1 });
    return {
      async connect() {
        return (await pool.connect()) as never;
      },
      async end() {
        await pool.end();
      },
    };
  };

  beforeAll(async () => {
    await applyReviewedMigrations(postgresUrl!);
    owner = new pg.Client({ connectionString: postgresUrl! });
    await owner.connect();
    await owner.query(
      `insert into tenants(id, status) values ($1, 'active'), ($2, 'active')`,
      [tenantA, tenantB],
    );
    await owner.query(
      `insert into accounts(id, tenant_id, auth0_subject, status) values
       ($1, $2, $3, 'active'), ($4, $5, $6, 'active')`,
      [accountA, tenantA, subjectA, accountB, tenantB, subjectB],
    );
    await owner.query(
      `insert into preferences(tenant_id, ritual_mode, timezone) values
       ($1, 'tarot', 'Pacific/Pago_Pago'), ($2, 'tarot', 'UTC')`,
      [tenantA, tenantB],
    );
    await owner.query(
      `insert into astrology_profiles(tenant_id, birth_date, derived_profile_code, algorithm_version)
       values ($1, '1990-01-01', 'lunar_patient', 'v1')`,
      [tenantA],
    );
  });

  afterAll(async () => {
    if (owner === undefined) return;
    await owner.query("delete from tenants where id = any($1::uuid[])", [
      [tenantA, tenantB],
    ]);
    await owner.end();
  });

  function app() {
    return createApp({
      dependencies: {
        auth0Keys: [auth0Key.publicJwk],
        accountResolver: async (subject) =>
          subject === subjectA
            ? {
                accountId: accountA,
                tenantId: tenantA,
                accountStatus: "active",
                tenantStatus: "active",
                revocationEpoch: 0,
              }
            : subject === subjectB
              ? {
                  accountId: accountB,
                  tenantId: tenantB,
                  accountStatus: "active",
                  tenantStatus: "active",
                  revocationEpoch: 0,
                }
              : null,
        contentRepository: createPostgresMemberContentRepository(
          postgresUrl!,
          nodePoolFactory,
        ),
        publicContentRepository: createPostgresPublicContentRepository(
          postgresUrl!,
          nodePoolFactory,
        ),
        now: () => new Date("2026-08-24T12:00:00.000Z"),
      },
    });
  }

  function bindings() {
    return {
      ...testBindings(),
      RUNTIME_DATABASE_URL: postgresUrl!,
      PUBLIC_DATABASE_URL: postgresUrl!,
    };
  }

  it("derives the omitted local day from the account IANA timezone and freezes Rowan", async () => {
    const expected = await owner.query<{ local_date: string }>(
      "select to_char(clock_timestamp() at time zone 'Pacific/Pago_Pago', 'YYYY-MM-DD') as local_date",
    );
    const authorization = `Bearer ${memberToken(auth0Key, { sub: subjectA })}`;
    const first = await app().request(
      "/v1/rituals/daily?mode=tarot",
      { headers: { authorization } },
      bindings(),
    );
    expect(first.status).toBe(200);
    const detail = (
      (await first.json()) as {
        data: {
          assignment_id: string;
          date: string;
          rowan: { script_revision_id: string; surface: string };
        };
      }
    ).data;
    expect(detail.date).toBe(expected.rows[0]!.local_date);
    expect(detail.rowan).toMatchObject({
      script_revision_id: "10000000-0000-4000-8000-000000000002",
      surface: "daily_ritual",
    });

    const second = await app().request(
      "/v1/rituals/daily?mode=tarot",
      { headers: { authorization } },
      bindings(),
    );
    expect(
      ((await second.json()) as { data: { assignment_id: string } }).data
        .assignment_id,
    ).toBe(detail.assignment_id);
  });

  it("uses only the allowlisted derived astrology code and never returns precise birth data", async () => {
    const authorization = `Bearer ${memberToken(auth0Key, { sub: subjectA })}`;
    const response = await app().request(
      "/v1/rituals/daily?mode=astrology",
      { headers: { authorization } },
      bindings(),
    );
    expect(response.status).toBe(200);
    const text = JSON.stringify(await response.json());
    expect(text).not.toMatch(
      /"(?:birth_date|birth_time|birthplace|location)":/i,
    );
  });

  it("keeps assignment reads tenant-scoped and historical withdrawn revisions loadable", async () => {
    const authorizationA = `Bearer ${memberToken(auth0Key, { sub: subjectA })}`;
    const authorizationB = `Bearer ${memberToken(auth0Key, { sub: subjectB })}`;
    const created = await app().request(
      "/v1/rituals/daily?date=2026-08-20&mode=tarot",
      { headers: { authorization: authorizationA } },
      bindings(),
    );
    const assignmentId = (
      (await created.json()) as { data: { assignment_id: string } }
    ).data.assignment_id;
    const foreign = await app().request(
      `/v1/rituals/${assignmentId}`,
      { headers: { authorization: authorizationB } },
      bindings(),
    );
    expect(foreign.status).toBe(404);

    const withdrawnRevision = "10000000-0000-4000-8000-000000000099";
    await owner.query(
      `insert into editorial_revisions(id, item_id, revision_number, state, author_staff_id, content_hash, created_at)
       values ($1, '11000000-0000-4000-8000-000000000001', 99, 'withdrawn',
         '90000000-0000-4000-8000-000000000001', 'u4-withdrawn-history-fixture', '2026-08-20T12:30:00Z')
       on conflict (id) do nothing`,
      [withdrawnRevision],
    );
    await owner.query(
      `insert into ritual_scenario_revisions(revision_id, title, interpretation, guidance, market_label, art_media_id, observation_at, uncertainty)
       select $1, title, interpretation, guidance, market_label, art_media_id, observation_at, uncertainty
       from ritual_scenario_revisions where revision_id = '10000000-0000-4000-8000-000000000001'
       on conflict (revision_id) do nothing`,
      [withdrawnRevision],
    );
    await owner.query(
      `insert into ritual_scenario_ideas(revision_id, asset_id, ordinal, appearance_reason, risk_summary)
       select $1, asset_id, ordinal, appearance_reason, risk_summary from ritual_scenario_ideas
       where revision_id = '10000000-0000-4000-8000-000000000001'
       on conflict (revision_id, asset_id) do nothing`,
      [withdrawnRevision],
    );
    await owner.query(
      `insert into ritual_scenario_evidence(revision_id, claim_id, ordinal, factor_label)
       select $1, claim_id, ordinal, factor_label from ritual_scenario_evidence
       where revision_id = '10000000-0000-4000-8000-000000000001'
       on conflict (revision_id, claim_id) do nothing`,
      [withdrawnRevision],
    );
    await owner.query(
      "update daily_ritual_assignments set revision_id = $1 where id = $2 and tenant_id = $3",
      [withdrawnRevision, assignmentId, tenantA],
    );

    const historical = await app().request(
      `/v1/rituals/${assignmentId}`,
      { headers: { authorization: authorizationA } },
      bindings(),
    );
    expect(historical.status).toBe(200);
    expect(
      ((await historical.json()) as { data: { revision: { id: string } } }).data
        .revision.id,
    ).toBe(withdrawnRevision);
    expect(
      (
        await owner.query(
          "select 1 from ritual_public.daily_ritual_preview_v1 where revision_id = $1",
          [withdrawnRevision],
        )
      ).rowCount,
    ).toBe(0);
  });

  it("serves only safe v1 projections through the restricted public role", async () => {
    const daily = await app().request(
      "/v1/public/rituals/daily?date=2026-08-24&mode=tarot",
      undefined,
      bindings(),
    );
    const discover = await app().request(
      "/v1/public/discover?limit=2",
      undefined,
      bindings(),
    );
    expect([daily.status, discover.status]).toEqual([200, 200]);
    expect(JSON.stringify(await daily.json())).not.toMatch(
      /guidance|canonical_url|tenant_id|saved/i,
    );

    expect(
      (
        await owner.query(
          "select count(*)::int as count from staff_principals where id::text like '90000000-%' and status = 'disabled' and last_verified_at is null",
        )
      ).rows[0]?.count,
    ).toBe(2);

    for (const legacy of [
      "daily_ritual_preview",
      "asset_codex_preview",
      "coven_preview",
    ]) {
      await owner.query("begin");
      await owner.query("set local role ritual_public");
      await expect(
        owner.query(`select 1 from ritual_public.${legacy} limit 1`),
      ).rejects.toMatchObject({ code: "42501" });
      await owner.query("rollback");
    }
    for (const forbidden of [
      "public.editorial_items",
      "public.daily_ritual_assignments",
      "ritual_catalog.assets_v1",
    ]) {
      await owner.query("begin");
      await owner.query("set local role ritual_public");
      await expect(
        owner.query(`select 1 from ${forbidden} limit 1`),
      ).rejects.toMatchObject({ code: "42501" });
      await owner.query("rollback");
    }
  });

  it("keeps multiple Coven qualifications in one row with qualification-specific evidence", async () => {
    await owner.query(
      `insert into evidence_sources(id, canonical_url, title, publisher, retrieved_at, source_kind, status)
       values ('31000000-0000-4000-8000-000000000099',
         'https://research.ritual-investing.test/demo/coven/aurora-owner',
         'Aurora owner qualification fixture', 'Ritual Research Fixtures',
         '2026-08-21T12:00:00Z', 'deterministic_demo', 'active')
       on conflict (id) do nothing`,
    );
    await owner.query(
      `insert into evidence_claims(id, source_id, claim_type, summary, observed_at, uncertainty, status)
       values ('30000000-0000-4000-8000-000000000099',
         '31000000-0000-4000-8000-000000000099', 'coven_owner',
         'A distinct fictional owner qualification.', '2026-08-21T12:00:00Z',
         'Fixture-only evidence.', 'active')
       on conflict (id) do nothing`,
    );
    await owner.query(
      `insert into coven_qualifications(id, entry_id, category, person_name, valid_from)
       values ('64000000-0000-4000-8000-000000000099',
         '60000000-0000-4000-8000-000000000001', 'owner', 'Maya Rowan', '2026-02-01')
       on conflict (id) do nothing`,
    );
    await owner.query(
      `insert into coven_verifications(id, qualification_id, status, effective_as_of, verified_at, verified_by)
       values ('65000000-0000-4000-8000-000000000099',
         '64000000-0000-4000-8000-000000000099', 'verified', '2026-08-21',
         '2026-08-21T12:00:00Z', '90000000-0000-4000-8000-000000000002')
       on conflict (id) do nothing`,
    );
    await owner.query(
      `update coven_qualifications set current_verification_id = '65000000-0000-4000-8000-000000000099'
       where id = '64000000-0000-4000-8000-000000000099'`,
    );
    await owner.query(
      `insert into coven_verification_evidence(verification_id, claim_id, ordinal)
       values ('65000000-0000-4000-8000-000000000099', '30000000-0000-4000-8000-000000000099', 1)
       on conflict (verification_id, claim_id) do nothing`,
    );

    const result = await owner.query<{
      payload: {
        qualifications: Array<{
          category: string;
          evidence: Array<{ claim_id: string }>;
        }>;
      };
    }>(
      "select payload from ritual_catalog.coven_v1 where id = '60000000-0000-4000-8000-000000000001'",
    );
    expect(result.rowCount).toBe(1);
    expect(
      result.rows[0]!.payload.qualifications.map(
        (qualification) => qualification.category,
      ),
    ).toEqual(["founder", "owner"]);
    expect(
      result.rows[0]!.payload.qualifications[0]!.evidence.map(
        (claim) => claim.claim_id,
      ),
    ).toEqual(["30000000-0000-4000-8000-000000000004"]);
    expect(
      result.rows[0]!.payload.qualifications[1]!.evidence.map(
        (claim) => claim.claim_id,
      ),
    ).toEqual(["30000000-0000-4000-8000-000000000099"]);
  });

  it("loads only a member-saved historical Asset Codex revision after republish", async () => {
    const assetId = "20000000-0000-4000-8000-000000000001";
    const itemId = "21000000-0000-4000-8000-000000000011";
    const originalRevision = "21000000-0000-4000-8000-000000000001";
    const replacementRevision = randomUUID();
    await owner.query(
      `insert into saved_assets(tenant_id,asset_id,revision_id,source_kind)
       values($1,$2,$3,'direct') on conflict(tenant_id,asset_id) do update set revision_id=excluded.revision_id`,
      [tenantA, assetId, originalRevision],
    );
    await owner.query(
      `insert into editorial_revisions(id,item_id,revision_number,state,author_staff_id,content_hash)
       select $1,$2,coalesce(max(revision_number),0)+1,'published','90000000-0000-4000-8000-000000000001',$3
       from editorial_revisions where item_id=$2`,
      [replacementRevision, itemId, `u5-codex-${replacementRevision}`],
    );
    await owner.query(
      `insert into asset_codex_revisions(revision_id,thesis,appearance_reason,metrics_as_of,limitations)
       values($1,'Replacement thesis','Replacement appearance','2026-08-24T12:00:00Z','Replacement limits')`,
      [replacementRevision],
    );
    await owner.query(
      `insert into asset_codex_risks(revision_id,ordinal,title,detail,severity)
       select $1,ordinal,title,detail,severity from asset_codex_risks where revision_id=$2`,
      [replacementRevision, originalRevision],
    );
    await owner.query(
      `insert into asset_codex_evidence(revision_id,claim_id,ordinal)
       select $1,claim_id,ordinal from asset_codex_evidence where revision_id=$2`,
      [replacementRevision, originalRevision],
    );
    await owner.query(
      "update editorial_items set current_published_revision_id=$1 where id=$2",
      [replacementRevision, itemId],
    );

    const repository = createPostgresMemberContentRepository(
      postgresUrl!,
      nodePoolFactory,
    );
    const memberA = {
      accountId: accountA,
      tenantId: tenantA,
      accountStatus: "active" as const,
      tenantStatus: "active" as const,
      revocationEpoch: 0,
      subject: subjectA,
    };
    const memberB = {
      accountId: accountB,
      tenantId: tenantB,
      accountStatus: "active" as const,
      tenantStatus: "active" as const,
      revocationEpoch: 0,
      subject: subjectB,
    };
    const frozen = await repository.getAsset(memberA, assetId);
    const current = await repository.getAsset(memberB, assetId);
    expect(frozen).toMatchObject({
      revision_id: originalRevision,
      saved: true,
    });
    expect(current).toMatchObject({
      revision_id: replacementRevision,
      saved: false,
      thesis: "Replacement thesis",
    });

    await owner.query(
      "update editorial_items set current_published_revision_id=$1 where id=$2",
      [originalRevision, itemId],
    );
  });
});
