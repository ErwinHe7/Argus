import type { SimulationRepository } from "./repository-contract.ts";
import {
  SimulationConflictError,
  SimulationInputError,
  SimulationNotFoundError,
} from "./repository-contract.ts";
import type { RebalancePreview } from "./schemas.ts";
import {
  type SimulationDatabase,
  currentGeneration,
  demo,
  executeTrades,
  portfolioView,
  quantity,
  quantityScale,
  quantityUnits,
  quantityValue,
  scoped,
  toIso,
  toNumber,
} from "./repository-shared.ts";

type DomainRepository = Pick<
  SimulationRepository,
  "previewRebalance" | "commitRebalance"
>;

export function createRebalanceRepository(
  database: SimulationDatabase,
): DomainRepository {
  return {
    previewRebalance: (context, portfolioId, input) =>
      scoped(database, context, async (client) => {
        const generation = await currentGeneration(client, context.tenantId);
        const portfolio = await portfolioView(
          client,
          context.tenantId,
          portfolioId,
        );
        if (portfolio === null || portfolio.status !== "active")
          throw new SimulationNotFoundError();
        const total = BigInt(portfolio.latest_valuation.minor_units);
        const trades: Array<{
          asset_id: string;
          side: "buy" | "sell";
          quantity: ReturnType<typeof quantity>;
          notional: { minor_units: number; currency: "USD" };
          price: number;
          quoteId: string;
          observedAt: string;
        }> = [];
        const requestedTargets = new Map(
          input.target_allocation.map((target) => [
            target.asset_id,
            target.target_bps,
          ]),
        );
        const allocationAssets = new Set([
          ...requestedTargets.keys(),
          ...portfolio.positions.map((position) => position.asset_id),
        ]);
        for (const assetId of allocationAssets) {
          const quote = (
            await client.query(
              `select metric.id,metric.price_minor::text,metric.observed_at
               from assets asset join lateral (
                 select id,price_minor,observed_at from asset_metric_snapshots
                 where asset_id=asset.id and is_demo order by observed_at desc,id desc limit 1
               ) metric on true
               where asset.id=$1 and asset.status='active' and asset.is_demo`,
              [assetId],
            )
          ).rows[0];
          if (quote === undefined) throw new SimulationNotFoundError();
          const current = BigInt(
            portfolio.positions.find(
              (position) => position.asset_id === assetId,
            )?.market_value.minor_units ?? 0,
          );
          const desired =
            (total * BigInt(requestedTargets.get(assetId) ?? 0)) / 10_000n;
          const difference = desired - current;
          if (difference === 0n) continue;
          const price = toNumber(quote.price_minor);
          const units =
            ((difference < 0n ? -difference : difference) * quantityScale) /
            BigInt(price);
          if (units <= 0n) continue;
          trades.push({
            asset_id: assetId,
            side: difference > 0n ? "buy" : "sell",
            quantity: quantity(quantityValue(units)),
            notional: {
              minor_units: toNumber((units * BigInt(price)) / quantityScale),
              currency: "USD",
            },
            price,
            quoteId: quote.id,
            observedAt: toIso(quote.observed_at),
          });
        }
        if (trades.length < 1)
          throw new SimulationInputError("already_balanced");
        const previewId = crypto.randomUUID();
        const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString();
        await client.query(
          `insert into rebalance_previews(id,tenant_id,reset_generation,portfolio_id,input_version,expires_at,status)
           values ($1,$2,$3,$4,$5,$6,'active')`,
          [
            previewId,
            context.tenantId,
            generation,
            portfolioId,
            portfolio.version,
            expiresAt,
          ],
        );
        for (const target of input.target_allocation) {
          const inserted = await client.query(
            `insert into rebalance_preview_allocations(
               tenant_id,preview_id,asset_id,target_bps
             )
             select $1,$2,asset.id,$4 from assets asset
             where asset.id=$3 and asset.status='active' and asset.is_demo`,
            [context.tenantId, previewId, target.asset_id, target.target_bps],
          );
          if (inserted.rowCount !== 1) throw new SimulationNotFoundError();
        }
        for (const trade of trades)
          await client.query(
            `insert into rebalance_preview_trades(
              tenant_id,preview_id,asset_id,side,quantity,notional_minor,
              frozen_price_minor,quote_snapshot_id,observed_at
            ) values (
              $1,$2,$3,$4,$5,$6,$7,$8,
              (select observed_at from asset_metric_snapshots
               where id=$8 and asset_id=$3 and is_demo)
            )`,
            [
              context.tenantId,
              previewId,
              trade.asset_id,
              trade.side,
              trade.quantity.value,
              trade.notional.minor_units,
              trade.price,
              trade.quoteId,
            ],
          );
        return {
          id: previewId,
          portfolio_id: portfolioId,
          portfolio_version: portfolio.version,
          target_allocation: input.target_allocation,
          trades: trades.map(
            ({ asset_id, side, quantity: amount, notional }) => ({
              asset_id,
              side,
              quantity: amount,
              notional,
            }),
          ),
          expires_at: expiresAt,
          status: "active",
          demo: demo(new Date().toISOString()),
        } as RebalancePreview;
      }),
    commitRebalance: (context, portfolioId, input, key) =>
      executeTrades(
        database,
        context,
        "rebalance.commit",
        key,
        { portfolio_id: portfolioId, ...input },
        portfolioId,
        input.portfolio_version,
        "rebalance",
        async (client, generation, version) => {
          const preview = (
            await client.query<{ id: string; input_version: number }>(
              `select id,input_version from rebalance_previews
               where tenant_id=$1 and id=$2 and portfolio_id=$3 and reset_generation=$4
                 and status='active' and expires_at > now() for update`,
              [context.tenantId, input.preview_id, portfolioId, generation],
            )
          ).rows[0];
          if (preview === undefined)
            throw new SimulationConflictError("preview_stale");
          if (Number(preview.input_version) !== version)
            throw new SimulationConflictError("version_conflict");
          const result = await client.query(
            `select trade.asset_id,asset.symbol,trade.side,trade.quantity::text,
               trade.frozen_price_minor::text,trade.quote_snapshot_id
             from rebalance_preview_trades trade join assets asset on asset.id=trade.asset_id
             where trade.tenant_id=$1 and trade.preview_id=$2 order by trade.id`,
            [context.tenantId, preview.id],
          );
          const allocations = await client.query<{
            asset_id: string;
            target_bps: number;
          }>(
            `select asset_id,target_bps from rebalance_preview_allocations
             where tenant_id=$1 and preview_id=$2 order by asset_id`,
            [context.tenantId, preview.id],
          );
          if (
            allocations.rowCount === 0 ||
            allocations.rows.reduce(
              (sum, allocation) => sum + Number(allocation.target_bps),
              0,
            ) !== 10_000
          )
            throw new SimulationConflictError("preview_stale");
          return {
            trades: result.rows.map((trade) => ({
              assetId: trade.asset_id,
              symbol: trade.symbol,
              side: trade.side,
              quantityUnits: quantityUnits(trade.quantity),
              priceMinor: toNumber(trade.frozen_price_minor),
              quoteSnapshotId: trade.quote_snapshot_id,
            })),
            summary: {
              kind: "rebalance",
              preview_id: preview.id,
              trade_count: result.rows.length,
            },
            afterCommand: async (db, commandId) => {
              const updated = await db.query(
                `update rebalance_previews set status='executed',executed_command_id=$3
                 where tenant_id=$1 and id=$2 and status='active'`,
                [context.tenantId, preview.id, commandId],
              );
              if (updated.rowCount !== 1)
                throw new SimulationConflictError("preview_stale");
              await db.query(
                `delete from portfolio_target_allocations
                 where tenant_id=$1 and portfolio_id=$2`,
                [context.tenantId, portfolioId],
              );
              const targets = await db.query(
                `insert into portfolio_target_allocations(
                   tenant_id,portfolio_id,asset_id,target_bps,version
                 )
                 select allocation.tenant_id,$3,allocation.asset_id,
                   allocation.target_bps,$4+1
                 from rebalance_preview_allocations allocation
                 join assets asset on asset.id=allocation.asset_id
                   and asset.status='active' and asset.is_demo
                 where allocation.tenant_id=$1 and allocation.preview_id=$2`,
                [context.tenantId, preview.id, portfolioId, version],
              );
              if (targets.rowCount !== allocations.rowCount)
                throw new SimulationConflictError("preview_stale");
            },
          };
        },
      ),
  };
}
