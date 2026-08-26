import { randomUUID } from "node:crypto";

import pg from "pg";
import { beforeAll, describe, expect, it } from "vitest";

import { createPostgresSimulationRepository } from "../../src/domains/simulation/repository.ts";
import {
  createSimulationFixture,
  ownerQuery,
  pgPoolFactory,
  type SimulationFixture,
} from "../helpers/simulation-postgres.ts";

const databaseUrl = process.env.TEST_DATABASE_URL;

describe.skipIf(databaseUrl === undefined)(
  "immutable simulated ledger reconciliation",
  () => {
    let fixture: SimulationFixture;

    beforeAll(async () => {
      fixture = await createSimulationFixture(databaseUrl!);
    });

    it("reconciles cash, quantity, average cost, and the sortable projection watermark", async () => {
      const repository = createPostgresSimulationRepository(
        databaseUrl!,
        pgPoolFactory,
      );
      await repository.contribute(
        fixture.context,
        fixture.portfolioId,
        {
          source_id: fixture.sourceId,
          amount: { minor_units: 100_000, currency: "USD" },
        },
        `seed-${randomUUID()}`,
      );
      const intention = await repository.createIntention(
        fixture.context,
        {
          title: "Over-target Demo intention",
          target: { minor_units: 5_000, currency: "USD" },
          target_date: new Date(Date.now() + 180 * 24 * 60 * 60 * 1000)
            .toISOString()
            .slice(0, 10),
          portfolio_id: fixture.portfolioId,
        },
        `intention-${randomUUID()}`,
      );
      expect(intention.progress_bps).toBe(10_000);
      let portfolio = await repository.getPortfolio(
        fixture.context,
        fixture.portfolioId,
      );
      const buy = await repository.previewOrder(
        fixture.context,
        fixture.portfolioId,
        {
          asset_id: fixture.assetId,
          side: "buy",
          quantity: { value: "10", scale: 12 },
        },
      );
      await expect(
        ownerQuery(
          databaseUrl!,
          "update order_previews set input_version=input_version+1 where id=$1",
          [buy.id],
        ),
      ).rejects.toThrow(/immutable/);
      await repository.commitOrder(
        fixture.context,
        fixture.portfolioId,
        { preview_id: buy.id, portfolio_version: portfolio!.version },
        `buy-${randomUUID()}`,
      );
      await ownerQuery(
        databaseUrl!,
        `insert into asset_metric_snapshots(
           asset_id,observed_at,price_minor,source_label,is_demo
         ) values ($1,now()+interval '1 second',2000,'ritual-demo-second',true)`,
        [fixture.assetId],
      );
      portfolio = await repository.getPortfolio(
        fixture.context,
        fixture.portfolioId,
      );
      const partialSell = await repository.previewOrder(
        fixture.context,
        fixture.portfolioId,
        {
          asset_id: fixture.assetId,
          side: "sell",
          quantity: { value: "4", scale: 12 },
        },
      );
      await repository.commitOrder(
        fixture.context,
        fixture.portfolioId,
        { preview_id: partialSell.id, portfolio_version: portfolio!.version },
        `sell-${randomUUID()}`,
      );

      const reconciled = await ownerQuery<{
        ledger_cash: string;
        snapshot_cash: string;
        ledger_quantity: string;
        projection_quantity: string;
        ledger_basis: string;
        projection_basis: string;
        max_watermark: string;
        current_watermark: string;
        snapshot_watermark: string;
      }>(
        databaseUrl!,
        `select
           (select sum(entry.amount_minor)::text from ledger_transactions transaction
             join cash_ledger_entries entry on entry.tenant_id=transaction.tenant_id
               and entry.transaction_id=transaction.id
             where transaction.tenant_id=$1 and transaction.portfolio_id=$2
               and transaction.reset_generation=1) ledger_cash,
           snapshot.cash_minor::text snapshot_cash,
           (select sum(entry.quantity)::text from ledger_transactions transaction
             join position_ledger_entries entry on entry.tenant_id=transaction.tenant_id
               and entry.transaction_id=transaction.id
             where transaction.tenant_id=$1 and transaction.portfolio_id=$2
               and transaction.reset_generation=1 and entry.asset_id=$3) ledger_quantity,
           position.quantity::text projection_quantity,
           (select sum(entry.cost_basis_delta_minor)::text from ledger_transactions transaction
             join position_ledger_entries entry on entry.tenant_id=transaction.tenant_id
               and entry.transaction_id=transaction.id
             where transaction.tenant_id=$1 and transaction.portfolio_id=$2
               and transaction.reset_generation=1 and entry.asset_id=$3) ledger_basis,
           position.cost_basis_minor::text projection_basis,
           (select max(ledger_sequence)::text from ledger_transactions
             where tenant_id=$1 and portfolio_id=$2 and reset_generation=1) max_watermark,
           portfolio.current_ledger_watermark::text current_watermark,
           snapshot.ledger_watermark::text snapshot_watermark
         from demo_portfolios portfolio
         join portfolio_positions position on position.tenant_id=portfolio.tenant_id
           and position.portfolio_id=portfolio.id and position.asset_id=$3
         join portfolio_balance_snapshots snapshot on snapshot.tenant_id=portfolio.tenant_id
           and snapshot.portfolio_id=portfolio.id and snapshot.id=portfolio.current_snapshot_id
         where portfolio.tenant_id=$1 and portfolio.id=$2`,
        [fixture.tenantId, fixture.portfolioId, fixture.assetId],
      );
      expect(reconciled.rows[0]).toMatchObject({
        ledger_cash: "98000",
        snapshot_cash: "98000",
        ledger_quantity: "6.000000000000",
        projection_quantity: "6.000000000000",
        ledger_basis: "6000",
        projection_basis: "6000",
      });
      expect(reconciled.rows[0]?.current_watermark).toBe(
        reconciled.rows[0]?.max_watermark,
      );
      expect(reconciled.rows[0]?.snapshot_watermark).toBe(
        reconciled.rows[0]?.max_watermark,
      );

      const snapshots = await ownerQuery<{
        id: string;
        ledger_watermark: string;
      }>(
        databaseUrl!,
        `select id,ledger_watermark::text from portfolio_balance_snapshots
         where tenant_id=$1 and portfolio_id=$2
         order by ledger_watermark desc limit 2`,
        [fixture.tenantId, fixture.portfolioId],
      );
      await expect(
        ownerQuery(
          databaseUrl!,
          `update demo_portfolios
           set current_snapshot_id=$3,current_ledger_watermark=$4
           where tenant_id=$1 and id=$2`,
          [
            fixture.tenantId,
            fixture.portfolioId,
            snapshots.rows[1]!.id,
            snapshots.rows[1]!.ledger_watermark,
          ],
        ),
      ).rejects.toThrow(/regress/);

      await expect(
        ownerQuery(
          databaseUrl!,
          `update portfolio_positions
           set ledger_watermark=ledger_watermark+1
           where tenant_id=$1 and portfolio_id=$2 and asset_id=$3`,
          [fixture.tenantId, fixture.portfolioId, fixture.assetId],
        ),
      ).rejects.toThrow(/transaction sequence/);

      portfolio = await repository.getPortfolio(
        fixture.context,
        fixture.portfolioId,
      );
      const close = await repository.previewOrder(
        fixture.context,
        fixture.portfolioId,
        {
          asset_id: fixture.assetId,
          side: "sell",
          quantity: { value: "6", scale: 12 },
        },
      );
      await repository.commitOrder(
        fixture.context,
        fixture.portfolioId,
        { preview_id: close.id, portfolio_version: portfolio!.version },
        `close-${randomUUID()}`,
      );
      const closed = await ownerQuery<{
        ledger_quantity: string;
        ledger_basis: string;
        positions: string;
      }>(
        databaseUrl!,
        `select
           coalesce(sum(entry.quantity),0)::text ledger_quantity,
           coalesce(sum(entry.cost_basis_delta_minor),0)::text ledger_basis,
           (select count(*) from portfolio_positions where tenant_id=$1
             and portfolio_id=$2 and asset_id=$3)::text positions
         from ledger_transactions transaction
         join position_ledger_entries entry on entry.tenant_id=transaction.tenant_id
           and entry.transaction_id=transaction.id
         where transaction.tenant_id=$1 and transaction.portfolio_id=$2
           and transaction.reset_generation=1 and entry.asset_id=$3`,
        [fixture.tenantId, fixture.portfolioId, fixture.assetId],
      );
      expect(closed.rows[0]).toEqual({
        ledger_quantity: "0.000000000000",
        ledger_basis: "0",
        positions: "0",
      });
    });

    it("rolls back a partial command at the deferred ledger boundary", async () => {
      const client = new pg.Client({ connectionString: databaseUrl! });
      await client.connect();
      const idempotencyId = randomUUID();
      const commandId = randomUUID();
      try {
        await client.query("begin");
        await client.query(
          `insert into idempotency_records(
             id,tenant_id,reset_generation,operation,idempotency_key,request_hash,state,
             claim_owner,lease_until,expires_at
           ) values ($1,$2,1,'failure.injection',$3,$4,'processing','test',
             now()+interval '1 minute',now()+interval '1 day')`,
          [
            idempotencyId,
            fixture.tenantId,
            `partial-${randomUUID()}`,
            "a".repeat(64),
          ],
        );
        await client.query(
          `insert into simulation_commands(
             id,tenant_id,reset_generation,portfolio_id,idempotency_id,command_type,
             status,committed_at
           ) values ($1,$2,1,$3,$4,'order','committed',now())`,
          [commandId, fixture.tenantId, fixture.portfolioId, idempotencyId],
        );
        await client.query(
          `update idempotency_records set state='completed',command_id=$3,
             terminal_response='{}'::jsonb where tenant_id=$1 and id=$2`,
          [fixture.tenantId, idempotencyId, commandId],
        );
        await expect(client.query("commit")).rejects.toThrow();
      } finally {
        await client.query("rollback").catch(() => undefined);
        await client.end();
      }
      const persisted = await ownerQuery<{ commands: string; records: string }>(
        databaseUrl!,
        `select
           (select count(*) from simulation_commands where tenant_id=$1 and id=$2)::text commands,
           (select count(*) from idempotency_records where tenant_id=$1 and id=$3)::text records`,
        [fixture.tenantId, commandId, idempotencyId],
      );
      expect(persisted.rows[0]).toEqual({ commands: "0", records: "0" });
    });

    it("rolls back a ledger transaction whose posting shape is incomplete", async () => {
      const client = new pg.Client({ connectionString: databaseUrl! });
      await client.connect();
      const idempotencyId = randomUUID();
      const commandId = randomUUID();
      const transactionId = randomUUID();
      try {
        await client.query("begin");
        await client.query(
          `insert into idempotency_records(
             id,tenant_id,reset_generation,operation,idempotency_key,
             request_hash,state,claim_owner,lease_until,expires_at
           ) values ($1,$2,1,'failure.missing-posting',$3,$4,'processing',
             'test',now()+interval '1 minute',now()+interval '1 day')`,
          [
            idempotencyId,
            fixture.tenantId,
            `missing-posting-${randomUUID()}`,
            "b".repeat(64),
          ],
        );
        await client.query(
          `insert into simulation_commands(
             id,tenant_id,reset_generation,portfolio_id,idempotency_id,
             command_type,status,committed_at
           ) values ($1,$2,1,$3,$4,'contribution','committed',now())`,
          [commandId, fixture.tenantId, fixture.portfolioId, idempotencyId],
        );
        await client.query(
          `insert into ledger_transactions(
             id,tenant_id,reset_generation,portfolio_id,command_id,
             entry_type,effective_at,description_code
           ) values ($1,$2,1,$3,$4,'contribution',now(),'missing_posting')`,
          [transactionId, fixture.tenantId, fixture.portfolioId, commandId],
        );
        await client.query(
          `update idempotency_records set state='completed',command_id=$3,
             terminal_response='{}'::jsonb
           where tenant_id=$1 and id=$2`,
          [fixture.tenantId, idempotencyId, commandId],
        );
        await expect(client.query("commit")).rejects.toThrow(
          /posting shape is incomplete/,
        );
      } finally {
        await client.query("rollback").catch(() => undefined);
        await client.end();
      }
      const persisted = await ownerQuery<{
        commands: string;
        transactions: string;
      }>(
        databaseUrl!,
        `select
           (select count(*) from simulation_commands
             where tenant_id=$1 and id=$2)::text commands,
           (select count(*) from ledger_transactions
             where tenant_id=$1 and id=$3)::text transactions`,
        [fixture.tenantId, commandId, transactionId],
      );
      expect(persisted.rows[0]).toEqual({ commands: "0", transactions: "0" });
    });

    it("rolls back an accepted order whose fill boundary is incomplete", async () => {
      const client = new pg.Client({ connectionString: databaseUrl! });
      await client.connect();
      const idempotencyId = randomUUID();
      const commandId = randomUUID();
      const transactionId = randomUUID();
      const orderId = randomUUID();
      try {
        await client.query("begin");
        await client.query(
          `insert into idempotency_records(
             id,tenant_id,reset_generation,operation,idempotency_key,
             request_hash,state,claim_owner,lease_until,expires_at
           ) values ($1,$2,1,'failure.missing-fill',$3,$4,'processing',
             'test',now()+interval '1 minute',now()+interval '1 day')`,
          [
            idempotencyId,
            fixture.tenantId,
            `missing-fill-${randomUUID()}`,
            "c".repeat(64),
          ],
        );
        await client.query(
          `insert into simulation_commands(
             id,tenant_id,reset_generation,portfolio_id,idempotency_id,
             command_type,status,committed_at
           ) values ($1,$2,1,$3,$4,'order','committed',now())`,
          [commandId, fixture.tenantId, fixture.portfolioId, idempotencyId],
        );
        await client.query(
          `insert into ledger_transactions(
             id,tenant_id,reset_generation,portfolio_id,command_id,
             entry_type,effective_at,description_code
           ) values ($1,$2,1,$3,$4,'order',now(),'missing_fill')`,
          [transactionId, fixture.tenantId, fixture.portfolioId, commandId],
        );
        await client.query(
          `insert into cash_ledger_entries(
             tenant_id,transaction_id,currency,amount_minor
           ) values ($1,$2,'USD',-100)`,
          [fixture.tenantId, transactionId],
        );
        await client.query(
          `insert into position_ledger_entries(
             tenant_id,transaction_id,asset_id,quantity,unit_price_minor,
             cost_basis_delta_minor
           ) values ($1,$2,$3,0.1,1000,100)`,
          [fixture.tenantId, transactionId, fixture.assetId],
        );
        await client.query(
          `insert into simulated_orders(
             id,tenant_id,portfolio_id,command_id,asset_id,side,order_type,
             requested_notional_minor,status
           ) values ($1,$2,$3,$4,$5,'buy','market',100,'accepted')`,
          [
            orderId,
            fixture.tenantId,
            fixture.portfolioId,
            commandId,
            fixture.assetId,
          ],
        );
        await client.query(
          `update idempotency_records set state='completed',command_id=$3,
             terminal_response='{}'::jsonb
           where tenant_id=$1 and id=$2`,
          [fixture.tenantId, idempotencyId, commandId],
        );
        await expect(client.query("commit")).rejects.toThrow(
          /accepted order requires one fill/,
        );
      } finally {
        await client.query("rollback").catch(() => undefined);
        await client.end();
      }
      const persisted = await ownerQuery<{
        orders: string;
        transactions: string;
      }>(
        databaseUrl!,
        `select
           (select count(*) from simulated_orders
             where tenant_id=$1 and id=$2)::text orders,
           (select count(*) from ledger_transactions
             where tenant_id=$1 and id=$3)::text transactions`,
        [fixture.tenantId, orderId, transactionId],
      );
      expect(persisted.rows[0]).toEqual({ orders: "0", transactions: "0" });
    });

    it("liquidates omitted holdings, freezes targets, and rolls target changes back with postings", async () => {
      const isolated = await createSimulationFixture(databaseUrl!);
      const repository = createPostgresSimulationRepository(
        databaseUrl!,
        pgPoolFactory,
      );
      const secondAssetId = randomUUID();
      await ownerQuery(
        databaseUrl!,
        `insert into assets(id,slug,symbol,name,asset_type,currency,exchange,is_demo,status)
         values ($1,$2,$3,'Second Demo Asset','etf','USD','DEMO',true,'active')`,
        [
          secondAssetId,
          `demo-${secondAssetId}`,
          `R${secondAssetId.replaceAll("-", "").slice(0, 8).toUpperCase()}`,
        ],
      );
      await ownerQuery(
        databaseUrl!,
        `insert into asset_metric_snapshots(
           asset_id,observed_at,price_minor,source_label,is_demo
         ) values ($1,now(),1000,'rebalance-second',true)`,
        [secondAssetId],
      );
      await repository.contribute(
        isolated.context,
        isolated.portfolioId,
        {
          source_id: isolated.sourceId,
          amount: { minor_units: 100_000, currency: "USD" },
        },
        `rebalance-seed-${randomUUID()}`,
      );
      let portfolio = await repository.getPortfolio(
        isolated.context,
        isolated.portfolioId,
      );
      const buy = await repository.previewOrder(
        isolated.context,
        isolated.portfolioId,
        {
          asset_id: isolated.assetId,
          side: "buy",
          quantity: { value: "10", scale: 0 },
        },
      );
      await repository.commitOrder(
        isolated.context,
        isolated.portfolioId,
        { preview_id: buy.id, portfolio_version: portfolio!.version },
        `rebalance-buy-${randomUUID()}`,
      );
      portfolio = await repository.getPortfolio(
        isolated.context,
        isolated.portfolioId,
      );
      const preview = await repository.previewRebalance(
        isolated.context,
        isolated.portfolioId,
        {
          target_allocation: [{ asset_id: secondAssetId, target_bps: 10_000 }],
        },
      );
      expect(preview.trades).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ asset_id: isolated.assetId, side: "sell" }),
          expect.objectContaining({ asset_id: secondAssetId, side: "buy" }),
        ]),
      );
      await expect(
        ownerQuery(
          databaseUrl!,
          `update rebalance_preview_allocations
           set target_bps=9999 where tenant_id=$1 and preview_id=$2`,
          [isolated.tenantId, preview.id],
        ),
      ).rejects.toThrow(/immutable/);
      await repository.commitRebalance(
        isolated.context,
        isolated.portfolioId,
        { preview_id: preview.id, portfolio_version: portfolio!.version },
        `rebalance-commit-${randomUUID()}`,
      );
      const committed = await ownerQuery<{
        held_assets: string[];
        target_assets: string[];
        target_total: string;
        ledger_count: string;
      }>(
        databaseUrl!,
        `select
           (select array_agg(asset_id::text order by asset_id) from portfolio_positions
             where tenant_id=$1 and portfolio_id=$2 and quantity > 0) held_assets,
           (select array_agg(asset_id::text order by asset_id) from portfolio_target_allocations
             where tenant_id=$1 and portfolio_id=$2) target_assets,
           (select sum(target_bps)::text from portfolio_target_allocations
             where tenant_id=$1 and portfolio_id=$2) target_total,
           (select count(*)::text from ledger_transactions
             where tenant_id=$1 and portfolio_id=$2) ledger_count`,
        [isolated.tenantId, isolated.portfolioId],
      );
      expect(committed.rows[0]).toMatchObject({
        held_assets: [secondAssetId],
        target_assets: [secondAssetId],
        target_total: "10000",
      });

      portfolio = await repository.getPortfolio(
        isolated.context,
        isolated.portfolioId,
      );
      const rejectedPreview = await repository.previewRebalance(
        isolated.context,
        isolated.portfolioId,
        {
          target_allocation: [
            { asset_id: isolated.assetId, target_bps: 10_000 },
          ],
        },
      );
      await ownerQuery(
        databaseUrl!,
        "update assets set status='inactive' where id=$1",
        [isolated.assetId],
      );
      await expect(
        repository.commitRebalance(
          isolated.context,
          isolated.portfolioId,
          {
            preview_id: rejectedPreview.id,
            portfolio_version: portfolio!.version,
          },
          `rebalance-rejected-${randomUUID()}`,
        ),
      ).rejects.toMatchObject({ code: "preview_stale" });
      const rolledBack = await ownerQuery<{
        target_assets: string[];
        ledger_count: string;
      }>(
        databaseUrl!,
        `select
           (select array_agg(asset_id::text order by asset_id) from portfolio_target_allocations
             where tenant_id=$1 and portfolio_id=$2) target_assets,
           (select count(*)::text from ledger_transactions
             where tenant_id=$1 and portfolio_id=$2) ledger_count`,
        [isolated.tenantId, isolated.portfolioId],
      );
      expect(rolledBack.rows[0]).toEqual({
        target_assets: [secondAssetId],
        ledger_count: committed.rows[0]!.ledger_count,
      });
    });
  },
);
