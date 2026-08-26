import { randomUUID } from "node:crypto";

import pg from "pg";

import type { DatabasePoolFactory } from "../../src/db/client.ts";
import type { MemberContext } from "../../src/domains/accounts/repository.ts";

export const pgPoolFactory: DatabasePoolFactory = (databaseUrl) =>
  new pg.Pool({
    connectionString: databaseUrl,
    max: 1,
  }) as unknown as ReturnType<DatabasePoolFactory>;

export type SimulationFixture = {
  context: MemberContext;
  tenantId: string;
  accountId: string;
  portfolioId: string;
  sourceId: string;
  assetId: string;
  quoteId: string;
  seedVersion: number;
};

export async function createSimulationFixture(
  databaseUrl: string,
): Promise<SimulationFixture> {
  const tenantId = randomUUID();
  const accountId = randomUUID();
  const portfolioId = randomUUID();
  const sourceId = randomUUID();
  const assetId = randomUUID();
  const quoteId = randomUUID();
  const seedId = randomUUID();
  const subject = `auth0|simulation-${tenantId}`;
  const seedVersion = Number.parseInt(tenantId.slice(0, 6), 16) + 100;
  const slug = `demo-${assetId}`;
  const symbol = `D${assetId.replaceAll("-", "").slice(0, 8).toUpperCase()}`;
  const client = new pg.Client({ connectionString: databaseUrl });
  await client.connect();
  try {
    await client.query("begin");
    await client.query("insert into tenants(id,status) values ($1,'active')", [
      tenantId,
    ]);
    await client.query(
      `insert into accounts(id,tenant_id,auth0_subject,status)
       values ($1,$2,$3,'active')`,
      [accountId, tenantId, subject],
    );
    await client.query(
      `insert into profiles(tenant_id,display_name,locale)
       values ($1,'Simulation Member','en-US')`,
      [tenantId],
    );
    await client.query(
      `insert into preferences(tenant_id,theme_mode,ritual_mode,timezone,locale)
       values ($1,'system','tarot','UTC','en-US')`,
      [tenantId],
    );
    await client.query(
      `insert into onboarding_states(tenant_id,current_step,completed_steps)
       values ($1,'welcome','[]'::jsonb)`,
      [tenantId],
    );
    await client.query(
      "insert into notification_preferences(tenant_id) values ($1)",
      [tenantId],
    );
    await client.query(
      `insert into demo_seed_versions(id,version,fixture_hash,published_at,is_current)
       values ($1,$2,$3,now(),false)`,
      [seedId, seedVersion, `fixture-${tenantId}`],
    );
    await client.query(
      `insert into tenant_demo_states(tenant_id,seed_version_id,reset_generation)
       values ($1,$2,1)`,
      [tenantId, seedId],
    );
    await client.query(
      `insert into demo_portfolios(
         id,tenant_id,reset_generation,name,currency,status,is_default
       ) values ($1,$2,1,'Test Demo Portfolio','USD','active',true)`,
      [portfolioId, tenantId],
    );
    await client.query(
      `insert into demo_funding_sources(
         id,tenant_id,reset_generation,fixture_key,display_label,fictional_last4,status
       ) values ($1,$2,1,'moon_reserve','Moon Reserve (fictional)','1108','active')`,
      [sourceId, tenantId],
    );
    await client.query(
      `insert into assets(id,slug,symbol,name,asset_type,currency,exchange,is_demo,status)
       values ($1,$2,$3,'Demo Asset','etf','USD','DEMO',true,'active')`,
      [assetId, slug, symbol],
    );
    await client.query(
      `insert into asset_metric_snapshots(
         id,asset_id,observed_at,price_minor,source_label,is_demo
       ) values ($1,$2,now(),1000,'ritual-demo-fixture',true)`,
      [quoteId, assetId],
    );
    await client.query(
      `insert into demo_plans(code,display_name,price_copy,feature_codes,status)
       values ('demo','Free Demo','Fictional free access','["demo"]'::jsonb,'active')
       on conflict (code) do update set status='active'`,
    );
    const plan = await client.query<{ id: string }>(
      "select id from demo_plans where code='demo'",
    );
    await client.query(
      `insert into tenant_entitlements(
         tenant_id,plan_id,status,source,starts_at,reset_generation
       ) values ($1,$2,'active','demo',now(),1)`,
      [tenantId, plan.rows[0]!.id],
    );
    await client.query("commit");
  } catch (error) {
    await client.query("rollback").catch(() => undefined);
    throw error;
  } finally {
    await client.end();
  }

  return {
    context: {
      subject,
      accountId,
      tenantId,
      accountStatus: "active",
      tenantStatus: "active",
      revocationEpoch: 0,
    },
    tenantId,
    accountId,
    portfolioId,
    sourceId,
    assetId,
    quoteId,
    seedVersion,
  };
}

export async function ownerQuery<
  T extends pg.QueryResultRow = pg.QueryResultRow,
>(
  databaseUrl: string,
  text: string,
  values: unknown[] = [],
): Promise<pg.QueryResult<T>> {
  const client = new pg.Client({ connectionString: databaseUrl });
  await client.connect();
  try {
    return await client.query<T>(text, values);
  } finally {
    await client.end();
  }
}
