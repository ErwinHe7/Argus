import { randomUUID } from "node:crypto";

import { beforeAll, describe, expect, it } from "vitest";

import {
  createPostgresSimulationRepository,
  SimulationConflictError,
} from "../../src/domains/simulation/repository.ts";
import {
  createSimulationFixture,
  ownerQuery,
  pgPoolFactory,
  type SimulationFixture,
} from "../helpers/simulation-postgres.ts";

const databaseUrl = process.env.TEST_DATABASE_URL;

describe.skipIf(databaseUrl === undefined)(
  "simulation command PostgreSQL concurrency",
  () => {
    let fixture: SimulationFixture;

    beforeAll(async () => {
      fixture = await createSimulationFixture(databaseUrl!);
    });

    it("serializes stale order commits and posts exactly one immutable result", async () => {
      const repository = createPostgresSimulationRepository(
        databaseUrl!,
        pgPoolFactory,
      );
      await repository.contribute(
        fixture.context,
        fixture.portfolioId,
        {
          source_id: fixture.sourceId,
          amount: { minor_units: 10_000, currency: "USD" },
        },
        `seed-${randomUUID()}`,
      );
      const portfolio = await repository.getPortfolio(
        fixture.context,
        fixture.portfolioId,
      );
      const first = await repository.previewOrder(
        fixture.context,
        fixture.portfolioId,
        {
          asset_id: fixture.assetId,
          side: "buy",
          notional: { minor_units: 7_000, currency: "USD" },
        },
      );
      const second = await repository.previewOrder(
        fixture.context,
        fixture.portfolioId,
        {
          asset_id: fixture.assetId,
          side: "buy",
          notional: { minor_units: 7_000, currency: "USD" },
        },
      );
      const settled = await Promise.allSettled([
        repository.commitOrder(
          fixture.context,
          fixture.portfolioId,
          { preview_id: first.id, portfolio_version: portfolio!.version },
          `order-${randomUUID()}`,
        ),
        repository.commitOrder(
          fixture.context,
          fixture.portfolioId,
          { preview_id: second.id, portfolio_version: portfolio!.version },
          `order-${randomUUID()}`,
        ),
      ]);

      expect(
        settled.filter((result) => result.status === "fulfilled"),
      ).toHaveLength(1);
      const rejected = settled.find((result) => result.status === "rejected");
      expect(rejected).toMatchObject({
        reason: expect.any(SimulationConflictError),
      });
      const counts = await ownerQuery<{ orders: string; fills: string }>(
        databaseUrl!,
        `select
           (select count(*) from simulated_orders where tenant_id=$1)::text orders,
           (select count(*) from simulated_order_fills where tenant_id=$1)::text fills`,
        [fixture.tenantId],
      );
      expect(counts.rows[0]).toEqual({ orders: "2", fills: "1" });
    });

    it("returns one terminal response for concurrent identical keys and rejects hash drift", async () => {
      const repository = createPostgresSimulationRepository(
        databaseUrl!,
        pgPoolFactory,
      );
      const key = `same-${randomUUID()}`;
      const request = {
        source_id: fixture.sourceId,
        amount: { minor_units: 1_000, currency: "USD" as const },
      };
      const settled = await Promise.allSettled([
        repository.contribute(
          fixture.context,
          fixture.portfolioId,
          request,
          key,
        ),
        repository.contribute(
          fixture.context,
          fixture.portfolioId,
          request,
          key,
        ),
      ]);
      const success = settled.find((result) => result.status === "fulfilled");
      expect(success).toBeDefined();
      const replay = await repository.contribute(
        fixture.context,
        fixture.portfolioId,
        request,
        key,
      );
      expect(replay).toEqual(
        success!.status === "fulfilled" ? success!.value : undefined,
      );
      await expect(
        repository.contribute(
          fixture.context,
          fixture.portfolioId,
          {
            ...request,
            amount: { minor_units: 1_001, currency: "USD" },
          },
          key,
        ),
      ).rejects.toMatchObject({ code: "idempotency_conflict" });
      const postings = await ownerQuery<{ count: string }>(
        databaseUrl!,
        `select count(*)::text count from simulation_commands command
         join idempotency_records record on record.tenant_id=command.tenant_id
           and record.id=command.idempotency_id
         where command.tenant_id=$1 and record.idempotency_key=$2`,
        [fixture.tenantId, key],
      );
      expect(postings.rows[0]?.count).toBe("1");
    });

    it("replays a stable business rejection immediately without a ledger effect", async () => {
      const repository = createPostgresSimulationRepository(
        databaseUrl!,
        pgPoolFactory,
      );
      const portfolio = await repository.getPortfolio(
        fixture.context,
        fixture.portfolioId,
      );
      const preview = await repository.previewOrder(
        fixture.context,
        fixture.portfolioId,
        {
          asset_id: fixture.assetId,
          side: "buy",
          notional: { minor_units: 100, currency: "USD" },
        },
      );
      await repository.contribute(
        fixture.context,
        fixture.portfolioId,
        {
          source_id: fixture.sourceId,
          amount: { minor_units: 100, currency: "USD" },
        },
        `advance-${randomUUID()}`,
      );
      const key = `rejected-${randomUUID()}`;
      const commit = () =>
        repository.commitOrder(
          fixture.context,
          fixture.portfolioId,
          { preview_id: preview.id, portfolio_version: portfolio!.version },
          key,
        );
      await expect(commit()).rejects.toMatchObject({
        code: "version_conflict",
      });
      await expect(commit()).rejects.toMatchObject({
        code: "version_conflict",
      });
      const rejectedOrders = await repository.listOrders(fixture.context, {
        status: "rejected",
      });
      const rejectedOrder = await ownerQuery<{ id: string }>(
        databaseUrl!,
        `select simulated_order.id from simulated_orders simulated_order
         join simulation_commands command
           on command.tenant_id=simulated_order.tenant_id
          and command.id=simulated_order.command_id
         join idempotency_records record
           on record.tenant_id=command.tenant_id
          and record.id=command.idempotency_id
         where record.tenant_id=$1 and record.idempotency_key=$2`,
        [fixture.tenantId, key],
      );
      const listedOrder = rejectedOrders.items.find(
        (order) => order.id === rejectedOrder.rows[0]!.id,
      );
      expect(listedOrder).toMatchObject({
        status: "rejected",
        fill: null,
      });
      const detail = await repository.getOrder(
        fixture.context,
        rejectedOrder.rows[0]!.id,
      );
      expect(detail?.id).toBe(rejectedOrder.rows[0]!.id);
      const otherTenant = await createSimulationFixture(databaseUrl!);
      expect(
        await repository.getOrder(
          otherTenant.context,
          rejectedOrder.rows[0]!.id,
        ),
      ).toBeNull();
      const terminal = await ownerQuery<{
        state: string;
        commands: string;
        transactions: string;
      }>(
        databaseUrl!,
        `select record.state,
           (select count(*) from simulation_commands command
             where command.tenant_id=record.tenant_id
               and command.idempotency_id=record.id)::text commands,
           (select count(*) from ledger_transactions transaction
             join simulation_commands command on command.tenant_id=transaction.tenant_id
               and command.id=transaction.command_id
             where command.tenant_id=record.tenant_id
               and command.idempotency_id=record.id)::text transactions
         from idempotency_records record
         where record.tenant_id=$1 and record.idempotency_key=$2`,
        [fixture.tenantId, key],
      );
      expect(terminal.rows[0]).toEqual({
        state: "rejected",
        commands: "1",
        transactions: "0",
      });
    });

    it("deduplicates reordered recurring allocation deliveries by scheduled time", async () => {
      const repository = createPostgresSimulationRepository(
        databaseUrl!,
        pgPoolFactory,
      );
      const portfolio = await repository.getPortfolio(
        fixture.context,
        fixture.portfolioId,
      );
      const plan = await repository.createRecurringPlan(
        fixture.context,
        fixture.portfolioId,
        {
          type: "allocation",
          amount: { minor_units: 2_000, currency: "USD" },
          frequency: "weekly",
          source_id: fixture.sourceId,
          allocations: [{ asset_id: fixture.assetId, weight_bps: 10_000 }],
          first_run_at: new Date(Date.now() + 60_000).toISOString(),
        },
        `plan-${randomUUID()}`,
      );
      const olderSchedule = new Date(Date.now() + 120_000).toISOString();
      const newerSchedule = new Date(Date.now() + 600_000).toISOString();
      const newer = await repository.deliverRecurringPlan(
        fixture.context,
        plan.id,
        newerSchedule,
        1,
      );
      const older = await repository.deliverRecurringPlan(
        fixture.context,
        plan.id,
        olderSchedule,
        1,
      );
      const replay = await repository.deliverRecurringPlan(
        fixture.context,
        plan.id,
        olderSchedule,
        1,
      );
      expect(replay.command_id).toBe(older.command_id);
      const afterDelivery = await repository.getRecurringPlan(
        fixture.context,
        plan.id,
      );
      const paused = await repository.transitionRecurringPlan(
        fixture.context,
        plan.id,
        "pause",
        afterDelivery!.version,
      );
      const resumed = await repository.transitionRecurringPlan(
        fixture.context,
        plan.id,
        "resume",
        paused!.version,
      );
      expect(Date.parse(resumed!.next_run_at)).toBeGreaterThan(
        Date.parse(newerSchedule),
      );
      const effects = await ownerQuery<{
        runs: string;
        commands: string;
        transactions: string;
        positions: string;
      }>(
        databaseUrl!,
        `select
           (select count(*) from recurring_plan_runs where tenant_id=$1
             and plan_id=$2)::text runs,
           (select count(*) from simulation_commands where tenant_id=$1
             and id=$3 and command_type='recurring')::text commands,
           (select count(*) from ledger_transactions where tenant_id=$1
             and command_id=$3)::text transactions,
           (select count(*) from portfolio_positions where tenant_id=$1
             and portfolio_id=$4 and asset_id=$5)::text positions`,
        [
          fixture.tenantId,
          plan.id,
          newer.command_id,
          fixture.portfolioId,
          fixture.assetId,
        ],
      );
      expect(effects.rows[0]).toEqual({
        runs: "2",
        commands: "1",
        transactions: "1",
        positions: "1",
      });
      expect(portfolio).not.toBeNull();
    });

    it("serializes deterministic Future Mirror generations and permits bounded large outputs", async () => {
      const repository = createPostgresSimulationRepository(
        databaseUrl!,
        pgPoolFactory,
      );
      const targetDate = new Date();
      targetDate.setUTCFullYear(targetDate.getUTCFullYear() + 10);
      const intention = await repository.createIntention(
        fixture.context,
        {
          title: "Long Demo horizon",
          target: { minor_units: 1_000_000_000, currency: "USD" },
          target_date: targetDate.toISOString().slice(0, 10),
          portfolio_id: fixture.portfolioId,
        },
        `mirror-intention-${randomUUID()}`,
      );
      const assumptions = {
        name: "Bounded large Demo",
        monthly_contribution: {
          minor_units: 1_000_000_000,
          currency: "USD" as const,
        },
        annual_return_bps: { low: 0, mid: 1_000, high: 5_000 },
      };
      const [first, second] = await Promise.all([
        repository.buildFutureMirror(
          fixture.context,
          intention.id,
          assumptions,
          `mirror-${randomUUID()}`,
        ),
        repository.buildFutureMirror(
          fixture.context,
          intention.id,
          assumptions,
          `mirror-${randomUUID()}`,
        ),
      ]);
      expect(first.input_hash).toBe(second.input_hash);
      expect(
        Math.max(...first.points.map((point) => point.high.minor_units)),
      ).toBeGreaterThan(1_000_000_000);
      const generations = await ownerQuery<{
        projection_generation: number;
        input_hash: string;
      }>(
        databaseUrl!,
        `select projection_generation,input_hash from projection_runs
         where tenant_id=$1 and intention_id=$2
         order by projection_generation`,
        [fixture.tenantId, intention.id],
      );
      expect(generations.rows.map((row) => row.projection_generation)).toEqual([
        1, 2,
      ]);
      expect(new Set(generations.rows.map((row) => row.input_hash)).size).toBe(
        1,
      );
      await expect(
        ownerQuery(
          databaseUrl!,
          `update intentions intention
           set current_projection_run_id=run.id,
               current_projection_watermark=run.ledger_watermark,
               current_projection_generation=run.projection_generation
           from projection_runs run
           where intention.tenant_id=$1 and intention.id=$2
             and run.tenant_id=intention.tenant_id
             and run.intention_id=intention.id
             and run.projection_generation=1`,
          [fixture.tenantId, intention.id],
        ),
      ).rejects.toThrow(/regress/);
    });
  },
);
