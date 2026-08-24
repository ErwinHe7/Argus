import type { SimulationRepository } from "./repository-contract.ts";
import {
  SimulationConflictError,
  SimulationInputError,
  SimulationNotFoundError,
} from "./repository-contract.ts";
import type { RecurringPlan } from "./schemas.ts";
import {
  type SimulationDatabase,
  currentGeneration,
  executeTrades,
  idempotentMutation,
  quantityScale,
  recurringPlanView,
  recurringPlanViews,
  scoped,
  sha256,
  toNumber,
} from "./repository-shared.ts";

type DomainRepository = Pick<
  SimulationRepository,
  | "listRecurringPlans"
  | "createRecurringPlan"
  | "getRecurringPlan"
  | "patchRecurringPlan"
  | "transitionRecurringPlan"
  | "cancelRecurringPlan"
  | "deliverRecurringPlan"
>;

export function createRecurringRepository(
  database: SimulationDatabase,
  contribute: SimulationRepository["contribute"],
): DomainRepository {
  return {
    listRecurringPlans: (context, portfolioId, input) =>
      scoped(database, context, async (client) => {
        const generation = await currentGeneration(client, context.tenantId);
        const exists = await client.query(
          "select 1 from demo_portfolios where tenant_id=$1 and id=$2 and reset_generation=$3",
          [context.tenantId, portfolioId, generation],
        );
        if (exists.rowCount !== 1) throw new SimulationNotFoundError();
        const limit = Number(input.limit ?? 20);
        const after = typeof input.after === "string" ? input.after : null;
        const result = await client.query<{ id: string }>(
          `select id from recurring_plans where tenant_id=$1 and portfolio_id=$2
             and reset_generation=$3 and ($4::text is null or status=$4)
             and ($5::uuid is null or id > $5)
           order by id limit $6`,
          [
            context.tenantId,
            portfolioId,
            generation,
            input.status ?? null,
            after,
            limit + 1,
          ],
        );
        const ids = result.rows.slice(0, limit).map((row) => row.id);
        const items: RecurringPlan[] = await recurringPlanViews(
          client,
          context.tenantId,
          ids,
        );
        return {
          items,
          nextPosition:
            result.rows.length > limit ? (ids.at(-1) ?? null) : null,
        };
      }),
    createRecurringPlan: (context, portfolioId, input, key) =>
      idempotentMutation(
        database,
        context,
        "recurring-plan.create",
        key,
        { portfolioId, ...input },
        async (client, generation) => {
          const portfolio = await client.query(
            "select 1 from demo_portfolios where tenant_id=$1 and id=$2 and reset_generation=$3 and status='active'",
            [context.tenantId, portfolioId, generation],
          );
          const source = await client.query(
            "select 1 from demo_funding_sources where tenant_id=$1 and id=$2 and reset_generation=$3 and status='active' for update",
            [context.tenantId, input.source_id, generation],
          );
          if (portfolio.rowCount !== 1 || source.rowCount !== 1)
            throw new SimulationNotFoundError();
          const id = crypto.randomUUID();
          await client.query(
            `insert into recurring_plans(
            id,tenant_id,portfolio_id,plan_type,amount_minor,frequency,next_run_at,
            status,reset_generation,source_id
          ) values ($1,$2,$3,$4,$5,$6,$7,'active',$8,$9)`,
            [
              id,
              context.tenantId,
              portfolioId,
              input.type,
              input.amount.minor_units,
              input.frequency,
              input.first_run_at,
              generation,
              input.source_id,
            ],
          );
          for (const allocation of input.allocations) {
            const inserted = await client.query(
              `insert into recurring_plan_allocations(tenant_id,plan_id,asset_id,weight_bps)
             select $1,$2,asset.id,$4 from assets asset where asset.id=$3 and asset.status='active' and asset.is_demo`,
              [
                context.tenantId,
                id,
                allocation.asset_id,
                allocation.weight_bps,
              ],
            );
            if (inserted.rowCount !== 1) throw new SimulationNotFoundError();
          }
          const view = await recurringPlanView(client, context.tenantId, id);
          if (view === null) throw new SimulationNotFoundError();
          return view;
        },
      ),
    getRecurringPlan: (context, planId) =>
      scoped(database, context, (client) =>
        recurringPlanView(client, context.tenantId, planId),
      ),
    patchRecurringPlan: (context, planId, input, version) =>
      scoped(database, context, async (client) => {
        const generation = await currentGeneration(client, context.tenantId);
        const result = await client.query(
          `update recurring_plans set amount_minor=coalesce($5,amount_minor),
             frequency=coalesce($6,frequency),version=version+1
           where tenant_id=$1 and id=$2 and reset_generation=$3 and version=$4
             and status <> 'cancelled'`,
          [
            context.tenantId,
            planId,
            generation,
            version,
            input.amount?.minor_units ?? null,
            input.frequency ?? null,
          ],
        );
        if (result.rowCount !== 1) {
          const exists = await recurringPlanView(
            client,
            context.tenantId,
            planId,
          );
          if (exists !== null)
            throw new SimulationConflictError("version_conflict");
          return null;
        }
        if (input.allocations !== undefined) {
          await client.query(
            "delete from recurring_plan_allocations where tenant_id=$1 and plan_id=$2",
            [context.tenantId, planId],
          );
          for (const allocation of input.allocations) {
            const inserted = await client.query(
              `insert into recurring_plan_allocations(tenant_id,plan_id,asset_id,weight_bps)
               select $1,$2,asset.id,$4 from assets asset where asset.id=$3 and asset.status='active' and asset.is_demo`,
              [
                context.tenantId,
                planId,
                allocation.asset_id,
                allocation.weight_bps,
              ],
            );
            if (inserted.rowCount !== 1) throw new SimulationNotFoundError();
          }
        }
        return recurringPlanView(client, context.tenantId, planId);
      }),
    transitionRecurringPlan: (context, planId, transition, version) =>
      scoped(database, context, async (client) => {
        const generation = await currentGeneration(client, context.tenantId);
        const from = transition === "pause" ? "active" : "paused";
        const to = transition === "pause" ? "paused" : "active";
        const result = await client.query(
          `update recurring_plans set status=$5,version=version+1,
             next_run_at=case when $5='active' then
               greatest(now(),coalesce(last_scheduled_for,now())) +
                 case frequency when 'weekly' then interval '7 days' else interval '1 month' end
               else next_run_at end
           where tenant_id=$1 and id=$2 and reset_generation=$3 and version=$4 and status=$6`,
          [context.tenantId, planId, generation, version, to, from],
        );
        if (result.rowCount !== 1) {
          const existing = await recurringPlanView(
            client,
            context.tenantId,
            planId,
          );
          if (existing === null) return null;
          if (existing.status === to) return existing;
          throw new SimulationConflictError("invalid_transition");
        }
        return recurringPlanView(client, context.tenantId, planId);
      }),
    cancelRecurringPlan: (context, planId, version) =>
      scoped(database, context, async (client) => {
        const generation = await currentGeneration(client, context.tenantId);
        const result = await client.query(
          `update recurring_plans set status='cancelled',version=version+1
           where tenant_id=$1 and id=$2 and reset_generation=$3 and version=$4 and status <> 'cancelled'`,
          [context.tenantId, planId, generation, version],
        );
        if (result.rowCount === 1) return true;
        const existing = await recurringPlanView(
          client,
          context.tenantId,
          planId,
        );
        if (existing?.status === "cancelled") return true;
        if (existing !== null)
          throw new SimulationConflictError("version_conflict");
        return false;
      }),
    deliverRecurringPlan: async (
      context,
      planId,
      scheduledFor,
      resetGeneration,
    ) => {
      const plan = await scoped(database, context, async (client) => {
        const current = await currentGeneration(client, context.tenantId);
        if (current !== resetGeneration)
          throw new SimulationConflictError("demo_generation_conflict");
        const row = (
          await client.query<{
            id: string;
            portfolio_id: string;
            plan_type: "contribution" | "allocation";
            amount_minor: string;
            source_id: string;
            version: number;
            portfolio_version: number;
          }>(
            `select plan.id,plan.portfolio_id,plan.plan_type,
               plan.amount_minor::text,plan.source_id,plan.version,
               portfolio.version portfolio_version
             from recurring_plans plan
             join demo_portfolios portfolio on portfolio.tenant_id=plan.tenant_id
               and portfolio.id=plan.portfolio_id
               and portfolio.reset_generation=plan.reset_generation
               and portfolio.status='active'
             where plan.tenant_id=$1 and plan.id=$2
               and plan.reset_generation=$3 and plan.status='active'`,
            [context.tenantId, planId, current],
          )
        ).rows[0];
        if (row === undefined) throw new SimulationNotFoundError();
        return row;
      });
      const key = `recurring-${(await sha256({ planId, scheduledFor, resetGeneration })).slice(0, 40)}`;
      const result =
        plan.plan_type === "contribution"
          ? await contribute(
              context,
              plan.portfolio_id,
              {
                amount: {
                  minor_units: toNumber(plan.amount_minor),
                  currency: "USD",
                },
                source_id: plan.source_id,
                effective_at: scheduledFor,
              },
              key,
            )
          : await executeTrades(
              database,
              context,
              "recurring.delivery",
              key,
              {
                plan_id: planId,
                scheduled_for: scheduledFor,
                reset_generation: resetGeneration,
              },
              plan.portfolio_id,
              Number(plan.portfolio_version),
              "recurring",
              async (client, generation) => {
                if (generation !== resetGeneration)
                  throw new SimulationConflictError("demo_generation_conflict");
                const currentPlan = (
                  await client.query<{ amount_minor: string }>(
                    `select amount_minor::text from recurring_plans
                     where tenant_id=$1 and id=$2 and reset_generation=$3
                       and status='active' for update`,
                    [context.tenantId, planId, generation],
                  )
                ).rows[0];
                if (currentPlan === undefined)
                  throw new SimulationNotFoundError();
                const allocations = await client.query<{
                  asset_id: string;
                  symbol: string;
                  weight_bps: number;
                  quote_snapshot_id: string;
                  price_minor: string;
                }>(
                  `select allocation.asset_id,asset.symbol,allocation.weight_bps,
                     metric.id quote_snapshot_id,metric.price_minor::text
                   from recurring_plan_allocations allocation
                   join assets asset on asset.id=allocation.asset_id
                     and asset.status='active' and asset.is_demo
                   join lateral (
                     select id,price_minor from asset_metric_snapshots
                     where asset_id=asset.id and is_demo
                     order by observed_at desc,id desc limit 1
                   ) metric on true
                   where allocation.tenant_id=$1 and allocation.plan_id=$2
                   order by allocation.asset_id`,
                  [context.tenantId, planId],
                );
                if (allocations.rowCount === 0)
                  throw new SimulationInputError("empty_allocation");
                const amount = BigInt(currentPlan.amount_minor);
                const trades = allocations.rows.map((allocation) => {
                  const price = BigInt(allocation.price_minor);
                  const notional =
                    (amount * BigInt(allocation.weight_bps)) / 10_000n;
                  const units = (notional * quantityScale) / price;
                  if (units <= 0n)
                    throw new SimulationInputError("amount_below_demo_minimum");
                  return {
                    assetId: allocation.asset_id,
                    symbol: allocation.symbol,
                    side: "buy" as const,
                    quantityUnits: units,
                    priceMinor: toNumber(allocation.price_minor),
                    quoteSnapshotId: allocation.quote_snapshot_id,
                  };
                });
                return {
                  trades,
                  cashCreditMinor: toNumber(currentPlan.amount_minor),
                  summary: {
                    kind: "recurring_allocation",
                    plan_id: planId,
                    scheduled_for: scheduledFor,
                  },
                  afterCommand: async (db, commandId) => {
                    const inserted = await db.query(
                      `insert into recurring_plan_runs(
                         tenant_id,reset_generation,plan_id,scheduled_for,
                         command_id,status,attempted_at
                       ) values ($1,$2,$3,$4,$5,'completed',now())
                       on conflict (tenant_id,plan_id,reset_generation,scheduled_for)
                       do nothing`,
                      [
                        context.tenantId,
                        generation,
                        planId,
                        scheduledFor,
                        commandId,
                      ],
                    );
                    if (inserted.rowCount !== 1)
                      throw new SimulationConflictError("duplicate_delivery");
                    await db.query(
                      `update recurring_plans set last_scheduled_for=$4,
                         next_run_at=$4::timestamptz + case frequency
                           when 'weekly' then interval '7 days'
                           else interval '1 month' end,
                         version=version+1
                       where tenant_id=$1 and id=$2 and reset_generation=$3
                         and status='active'
                         and (last_scheduled_for is null or last_scheduled_for < $4)`,
                      [context.tenantId, planId, generation, scheduledFor],
                    );
                  },
                };
              },
            );
      if (plan.plan_type === "allocation")
        return {
          plan_id: planId,
          scheduled_for: scheduledFor,
          command_id: result.command_id,
          duplicate: false,
        };
      return scoped(database, context, async (client) => {
        const inserted = await client.query(
          `insert into recurring_plan_runs(tenant_id,reset_generation,plan_id,scheduled_for,command_id,status,attempted_at)
           values ($1,$2,$3,$4,$5,'completed',now())
           on conflict (tenant_id,plan_id,reset_generation,scheduled_for) do nothing`,
          [
            context.tenantId,
            resetGeneration,
            planId,
            scheduledFor,
            result.command_id,
          ],
        );
        await client.query(
          `update recurring_plans set last_scheduled_for=$4,
             next_run_at=$4::timestamptz + case frequency when 'weekly' then interval '7 days' else interval '1 month' end,
             version=version+1
           where tenant_id=$1 and id=$2 and reset_generation=$3 and status='active'
             and $5 and (last_scheduled_for is null or last_scheduled_for < $4)`,
          [
            context.tenantId,
            planId,
            resetGeneration,
            scheduledFor,
            inserted.rowCount === 1,
          ],
        );
        return {
          plan_id: planId,
          scheduled_for: scheduledFor,
          command_id: result.command_id,
          duplicate: inserted.rowCount !== 1,
        };
      });
    },
  };
}
