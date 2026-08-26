import type { SimulationRepository } from "./repository-contract.ts";
import {
  SimulationConflictError,
  SimulationInProgressError,
  SimulationNotFoundError,
} from "./repository-contract.ts";
import type { DemoEntitlement, DemoPlan } from "./schemas.ts";
import {
  type SimulationDatabase,
  claimReset,
  checkoutView,
  demo,
  entitlementView,
  idempotentMutation,
  scoped,
  sha256,
} from "./repository-shared.ts";

type DomainRepository = Pick<
  SimulationRepository,
  | "listDemoPlans"
  | "getEntitlement"
  | "createCheckout"
  | "getCheckout"
  | "confirmCheckout"
  | "restoreEntitlement"
  | "downgradeEntitlement"
  | "resetDemo"
>;

export function createEntitlementRepository(
  database: SimulationDatabase,
): DomainRepository {
  return {
    listDemoPlans: (context) =>
      scoped(database, context, async (client) => {
        const result = await client.query(
          `select case when code='demo' then 'free' else code end code,
             display_name,price_copy,feature_codes
           from demo_plans where code in ('demo','premium_demo') and status='active'
           order by code`,
        );
        return result.rows.map((row) => ({
          ...row,
          demo: demo(new Date().toISOString()),
        })) as DemoPlan[];
      }),
    getEntitlement: (context) =>
      scoped(database, context, (client) =>
        entitlementView(client, context.tenantId),
      ),
    createCheckout: (context, planCode, key) =>
      idempotentMutation(
        database,
        context,
        "demo-checkout.create",
        key,
        { plan_code: planCode },
        async (client, generation) => {
          const plan = (
            await client.query<{ id: string }>(
              "select id from demo_plans where code='premium_demo' and status='active'",
            )
          ).rows[0];
          if (plan === undefined) throw new SimulationNotFoundError();
          const idempotency = (
            await client.query<{ id: string }>(
              `select id from idempotency_records where tenant_id=$1 and reset_generation=$2
               and operation='demo-checkout.create' and idempotency_key=$3`,
              [context.tenantId, generation, key],
            )
          ).rows[0];
          if (idempotency === undefined) throw new SimulationInProgressError();
          const sessionId = crypto.randomUUID();
          const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString();
          await client.query(
            `insert into demo_checkout_sessions(
            id,tenant_id,plan_id,status,expires_at,idempotency_id,reset_generation
          ) values ($1,$2,$3,'open',$4,$5,$6)`,
            [
              sessionId,
              context.tenantId,
              plan.id,
              expiresAt,
              idempotency.id,
              generation,
            ],
          );
          const view = await checkoutView(client, context.tenantId, sessionId);
          if (view === null) throw new SimulationNotFoundError();
          return view;
        },
      ),
    getCheckout: (context, sessionId) =>
      scoped(database, context, (client) =>
        checkoutView(client, context.tenantId, sessionId),
      ),
    confirmCheckout: (context, sessionId, version, key) =>
      idempotentMutation(
        database,
        context,
        "demo-checkout.confirm",
        key,
        { session_id: sessionId, version },
        async (client, generation) => {
          const session = (
            await client.query<{ plan_id: string }>(
              `update demo_checkout_sessions set status='completed',version=version+1
             where tenant_id=$1 and id=$2 and reset_generation=$3 and version=$4
               and status='open' and expires_at > now() returning plan_id`,
              [context.tenantId, sessionId, generation, version],
            )
          ).rows[0];
          if (session === undefined) {
            const existing = await checkoutView(
              client,
              context.tenantId,
              sessionId,
            );
            if (existing === null) throw new SimulationNotFoundError();
            throw new SimulationConflictError(
              existing.status === "open"
                ? "version_conflict"
                : "checkout_not_open",
            );
          }
          await client.query(
            `update tenant_entitlements set status='revoked',ends_at=now(),version=version+1
           where tenant_id=$1 and reset_generation=$2 and status='active'`,
            [context.tenantId, generation],
          );
          const entitlementId = crypto.randomUUID();
          await client.query(
            `insert into tenant_entitlements(id,tenant_id,plan_id,status,source,starts_at,reset_generation)
           values ($1,$2,$3,'active','demo',now(),$4)`,
            [entitlementId, context.tenantId, session.plan_id, generation],
          );
          await client.query(
            `insert into entitlement_events(tenant_id,entitlement_id,event_type,occurred_at)
           values ($1,$2,'grant',now())`,
            [context.tenantId, entitlementId],
          );
          return entitlementView(client, context.tenantId);
        },
      ),
    restoreEntitlement: (context, key) =>
      idempotentMutation(
        database,
        context,
        "entitlement.restore",
        key,
        {},
        async (client, generation) => {
          let current: DemoEntitlement | null = null;
          try {
            current = await entitlementView(client, context.tenantId);
          } catch (error) {
            if (!(error instanceof SimulationNotFoundError)) throw error;
          }
          if (current !== null) {
            await client.query(
              `insert into entitlement_events(tenant_id,entitlement_id,event_type,occurred_at)
             values ($1,$2,'restore',now())`,
              [context.tenantId, current.id],
            );
            return current;
          }
          const latest = (
            await client.query<{ plan_id: string }>(
              `select plan_id from tenant_entitlements where tenant_id=$1 and reset_generation=$2
             order by starts_at desc limit 1`,
              [context.tenantId, generation],
            )
          ).rows[0];
          const plan =
            latest ??
            (
              await client.query<{ plan_id: string }>(
                "select id plan_id from demo_plans where code='demo' and status='active'",
              )
            ).rows[0];
          if (plan === undefined) throw new SimulationNotFoundError();
          const id = crypto.randomUUID();
          await client.query(
            `insert into tenant_entitlements(id,tenant_id,plan_id,status,source,starts_at,reset_generation)
           values ($1,$2,$3,'active','demo',now(),$4)`,
            [id, context.tenantId, plan.plan_id, generation],
          );
          await client.query(
            "insert into entitlement_events(tenant_id,entitlement_id,event_type,occurred_at) values ($1,$2,'restore',now())",
            [context.tenantId, id],
          );
          return entitlementView(client, context.tenantId);
        },
      ),
    downgradeEntitlement: (context, version, key) =>
      idempotentMutation(
        database,
        context,
        "entitlement.downgrade",
        key,
        { version },
        async (client, generation) => {
          const current = await entitlementView(client, context.tenantId);
          if (current.version !== version)
            throw new SimulationConflictError("version_conflict");
          if (current.plan_code === "free") return current;
          const free = (
            await client.query<{ id: string }>(
              "select id from demo_plans where code='demo' and status='active'",
            )
          ).rows[0];
          if (free === undefined) throw new SimulationNotFoundError();
          await client.query(
            `update tenant_entitlements set status='revoked',ends_at=now(),version=version+1
           where tenant_id=$1 and id=$2 and reset_generation=$3 and version=$4 and status='active'`,
            [context.tenantId, current.id, generation, version],
          );
          const id = crypto.randomUUID();
          await client.query(
            `insert into tenant_entitlements(id,tenant_id,plan_id,status,source,starts_at,reset_generation)
           values ($1,$2,$3,'active','demo',now(),$4)`,
            [id, context.tenantId, free.id, generation],
          );
          await client.query(
            "insert into entitlement_events(tenant_id,entitlement_id,event_type,occurred_at) values ($1,$2,'downgrade',now())",
            [context.tenantId, id],
          );
          return entitlementView(client, context.tenantId);
        },
      ),
    resetDemo: async (context, seedVersion, key) => {
      const request = { confirmation: "RESET_DEMO", seed_version: seedVersion };
      const claimed = await claimReset<Record<string, unknown>>(
        database,
        context,
        key,
        request,
      );
      if (claimed.terminal !== null) return claimed.terminal;
      return scoped(database, context, async (client) => {
        const state = (
          await client.query<{ reset_generation: number }>(
            "select reset_generation from tenant_demo_states where tenant_id=$1 for update",
            [context.tenantId],
          )
        ).rows[0];
        if (Number(state?.reset_generation) !== claimed.generation)
          throw new SimulationConflictError("demo_generation_conflict");
        const seed = (
          await client.query<{ id: string }>(
            "select id from demo_seed_versions where version=$1",
            [seedVersion],
          )
        ).rows[0];
        if (seed === undefined) throw new SimulationNotFoundError();
        const nextGeneration = claimed.generation + 1;
        await client.query(
          `update tenant_demo_states set seed_version_id=$2,reset_generation=$3,
             version=version+1,reset_at=now() where tenant_id=$1`,
          [context.tenantId, seed.id, nextGeneration],
        );
        const portfolioId = crypto.randomUUID();
        await client.query(
          `insert into demo_portfolios(id,tenant_id,reset_generation,name,currency,status,is_default)
           values ($1,$2,$3,'Demo Portfolio','USD','active',true)`,
          [portfolioId, context.tenantId, nextGeneration],
        );
        for (const fixture of [
          ["moon_reserve", "Moon Reserve (fictional)", "1108"],
          [
            "constellation_savings",
            "Constellation Savings (fictional)",
            "2042",
          ],
        ])
          await client.query(
            `insert into demo_funding_sources(tenant_id,reset_generation,fixture_key,display_label,fictional_last4,status)
             values ($1,$2,$3,$4,$5,'active')`,
            [context.tenantId, nextGeneration, ...fixture],
          );
        const free = (
          await client.query<{ id: string }>(
            "select id from demo_plans where code='demo' and status='active'",
          )
        ).rows[0];
        if (free === undefined) throw new SimulationNotFoundError();
        const entitlementId = crypto.randomUUID();
        await client.query(
          `insert into tenant_entitlements(id,tenant_id,plan_id,status,source,starts_at,reset_generation)
           values ($1,$2,$3,'active','demo',now(),$4)`,
          [entitlementId, context.tenantId, free.id, nextGeneration],
        );
        await client.query(
          `insert into demo_reset_events(tenant_id,prior_generation,reset_generation,seed_version_id,idempotency_id)
           values ($1,$2,$3,$4,$5)`,
          [
            context.tenantId,
            claimed.generation,
            nextGeneration,
            seed.id,
            claimed.id,
          ],
        );
        const result = {
          reset_generation: nextGeneration,
          default_portfolio: {
            id: portfolioId,
            name: "Demo Portfolio",
            currency: "USD",
            status: "active",
            version: 1,
          },
          entitlement: {
            id: entitlementId,
            plan_code: "free",
            status: "active",
            source: "demo",
            version: 1,
          },
          demo: demo(new Date().toISOString()),
        };
        const terminal = await client.query(
          `update idempotency_records set state='completed',response_hash=$3,
             terminal_response=$4::jsonb,lease_until=null
           where tenant_id=$1 and id=$2 and state='processing' and claim_owner=$5`,
          [
            context.tenantId,
            claimed.id,
            await sha256(result),
            JSON.stringify(result),
            claimed.owner,
          ],
        );
        if (terminal.rowCount !== 1) throw new SimulationInProgressError();
        return result;
      });
    },
  };
}
