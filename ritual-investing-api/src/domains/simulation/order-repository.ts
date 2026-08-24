import type { SimulationRepository } from "./repository-contract.ts";
import {
  SimulationConflictError,
  SimulationInputError,
  SimulationNotFoundError,
} from "./repository-contract.ts";
import type { OrderView } from "./schemas.ts";
import {
  type SimulationDatabase,
  currentGeneration,
  demo,
  executeTrades,
  orderView,
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
  "previewOrder" | "commitOrder" | "listOrders" | "getOrder"
>;

export function createOrderRepository(
  database: SimulationDatabase,
): DomainRepository {
  return {
    previewOrder: (context, portfolioId, input) =>
      scoped(database, context, async (client) => {
        const generation = await currentGeneration(client, context.tenantId);
        const portfolio = (
          await client.query<{ version: number }>(
            `select version from demo_portfolios
             where tenant_id=$1 and id=$2 and reset_generation=$3 and status='active'`,
            [context.tenantId, portfolioId, generation],
          )
        ).rows[0];
        if (portfolio === undefined) throw new SimulationNotFoundError();
        const quote = (
          await client.query<{
            asset_id: string;
            symbol: string;
            quote_snapshot_id: string;
            price_minor: string;
            observed_at: Date;
          }>(
            `select asset.id asset_id,asset.symbol,metric.id quote_snapshot_id,
               metric.price_minor::text,metric.observed_at
             from assets asset
             join lateral (
               select id,price_minor,observed_at from asset_metric_snapshots
               where asset_id=asset.id and is_demo order by observed_at desc,id desc limit 1
             ) metric on true
             where asset.id=$1 and asset.status='active' and asset.is_demo`,
            [input.asset_id],
          )
        ).rows[0];
        if (quote === undefined) throw new SimulationNotFoundError();
        const price = toNumber(quote.price_minor);
        const units =
          input.quantity === undefined
            ? (BigInt(input.notional!.minor_units) * quantityScale) /
              BigInt(price)
            : quantityUnits(input.quantity.value);
        const notional = toNumber((units * BigInt(price)) / quantityScale);
        if (units <= 0n || notional <= 0)
          throw new SimulationInputError("amount_below_demo_minimum");
        const id = crypto.randomUUID();
        const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString();
        await client.query(
          `insert into order_previews(
            id,tenant_id,reset_generation,portfolio_id,asset_id,side,
            requested_notional_minor,requested_quantity,frozen_price_minor,
            quote_snapshot_id,input_version,observed_at,expires_at,status
          ) values (
            $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,
            (select observed_at from asset_metric_snapshots
             where id=$10 and asset_id=$5 and is_demo),
            $12,'active'
          )`,
          [
            id,
            context.tenantId,
            generation,
            portfolioId,
            quote.asset_id,
            input.side,
            input.notional?.minor_units ?? null,
            input.quantity?.value ?? null,
            price,
            quote.quote_snapshot_id,
            Number(portfolio.version),
            expiresAt,
          ],
        );
        return {
          id,
          portfolio_id: portfolioId,
          asset_id: quote.asset_id,
          symbol: quote.symbol,
          side: input.side,
          notional: { minor_units: notional, currency: "USD" },
          quantity: quantity(quantityValue(units)),
          frozen_price: { minor_units: price, currency: "USD" },
          quote_snapshot_id: quote.quote_snapshot_id,
          portfolio_version: Number(portfolio.version),
          observed_at: toIso(quote.observed_at),
          expires_at: expiresAt,
          status: "active",
          demo: demo(toIso(quote.observed_at)),
        };
      }),
    commitOrder: (context, portfolioId, input, key) =>
      executeTrades(
        database,
        context,
        "order.commit",
        key,
        { portfolio_id: portfolioId, ...input },
        portfolioId,
        input.portfolio_version,
        "order",
        async (client, generation, version) => {
          const preview = (
            await client.query<{
              id: string;
              asset_id: string;
              symbol: string;
              side: "buy" | "sell";
              requested_notional_minor: string | null;
              requested_quantity: string | null;
              frozen_price_minor: string;
              quote_snapshot_id: string;
              input_version: number;
            }>(
              `select preview.id,preview.asset_id,asset.symbol,preview.side,
                 preview.requested_notional_minor::text,preview.requested_quantity::text,
                 preview.frozen_price_minor::text,preview.quote_snapshot_id,preview.input_version
               from order_previews preview join assets asset on asset.id=preview.asset_id
               where preview.tenant_id=$1 and preview.id=$2 and preview.portfolio_id=$3
                 and preview.reset_generation=$4 and preview.status='active'
                 and preview.expires_at > now() for update of preview`,
              [context.tenantId, input.preview_id, portfolioId, generation],
            )
          ).rows[0];
          if (preview === undefined)
            throw new SimulationConflictError("preview_stale");
          if (Number(preview.input_version) !== version)
            throw new SimulationConflictError("version_conflict");
          const price = toNumber(preview.frozen_price_minor);
          const units =
            preview.requested_quantity === null
              ? (BigInt(preview.requested_notional_minor!) * quantityScale) /
                BigInt(price)
              : quantityUnits(preview.requested_quantity);
          const orderId = crypto.randomUUID();
          return {
            trades: [
              {
                assetId: preview.asset_id,
                symbol: preview.symbol,
                side: preview.side,
                quantityUnits: units,
                priceMinor: price,
                quoteSnapshotId: preview.quote_snapshot_id,
              },
            ],
            summary: {
              kind: "order",
              order_id: orderId,
              preview_id: preview.id,
              side: preview.side,
              asset_id: preview.asset_id,
            },
            afterCommand: async (db, commandId, effectiveAt) => {
              await db.query(
                `insert into simulated_orders(
                  id,tenant_id,portfolio_id,command_id,asset_id,side,order_type,
                  requested_notional_minor,requested_quantity,status,quote_snapshot_id
                ) values ($1,$2,$3,$4,$5,$6,'market',$7,$8,'accepted',$9)`,
                [
                  orderId,
                  context.tenantId,
                  portfolioId,
                  commandId,
                  preview.asset_id,
                  preview.side,
                  preview.requested_notional_minor,
                  preview.requested_quantity,
                  preview.quote_snapshot_id,
                ],
              );
              await db.query(
                `insert into simulated_order_fills(tenant_id,order_id,quantity,price_minor,filled_at)
                 values ($1,$2,$3,$4,$5)`,
                [
                  context.tenantId,
                  orderId,
                  quantityValue(units),
                  price,
                  effectiveAt,
                ],
              );
              await db.query(
                `update order_previews set status='executed',executed_command_id=$3
                 where tenant_id=$1 and id=$2 and status='active'`,
                [context.tenantId, preview.id, commandId],
              );
            },
          };
        },
      ),
    listOrders: (context, input) =>
      scoped(database, context, async (client) => {
        const limit = Number(input.limit ?? 20);
        const portfolioId =
          typeof input.portfolio_id === "string" ? input.portfolio_id : null;
        const after = typeof input.after === "string" ? input.after : null;
        if (portfolioId !== null) {
          const exists = await portfolioView(
            client,
            context.tenantId,
            portfolioId,
          );
          if (exists === null) throw new SimulationNotFoundError();
        }
        const result = await client.query<{ id: string }>(
          `select orders.id from simulated_orders orders
           join simulation_commands command on command.tenant_id=orders.tenant_id and command.id=orders.command_id
           join tenant_demo_states state on state.tenant_id=orders.tenant_id and state.reset_generation=command.reset_generation
           where orders.tenant_id=$1 and ($2::uuid is null or orders.portfolio_id=$2)
             and ($3::text is null or orders.status=$3)
             and ($4::uuid is null or orders.id > $4)
           order by orders.id limit $5`,
          [
            context.tenantId,
            portfolioId,
            input.status ?? null,
            after,
            limit + 1,
          ],
        );
        const ids = result.rows.slice(0, limit).map((row) => row.id);
        const items: OrderView[] = [];
        for (const id of ids) {
          const item = await orderView(client, context.tenantId, id);
          if (item !== null) items.push(item);
        }
        return {
          items,
          nextPosition:
            result.rows.length > limit ? (ids.at(-1) ?? null) : null,
        };
      }),
    getOrder: (context, orderId) =>
      scoped(database, context, (client) =>
        orderView(client, context.tenantId, orderId),
      ),
  };
}
