import type { SimulationRepository } from "./repository-contract.ts";
import {
  SimulationConflictError,
  SimulationInProgressError,
  SimulationInputError,
  SimulationNotFoundError,
} from "./repository-contract.ts";
import type {
  FundingSource,
  PortfolioView,
  SimulationResult,
} from "./schemas.ts";
import {
  type SimulationDatabase,
  claim,
  currentGeneration,
  demo,
  idempotentMutation,
  portfolioView,
  scoped,
  sha256,
  toIso,
  toNumber,
} from "./repository-shared.ts";

type DomainRepository = Pick<
  SimulationRepository,
  | "listPortfolios"
  | "createPortfolio"
  | "getPortfolio"
  | "patchPortfolio"
  | "archivePortfolio"
  | "listHoldings"
  | "listActivity"
  | "listSnapshots"
  | "listFundingSources"
  | "createFundingSource"
  | "deleteFundingSource"
  | "contribute"
>;

export function createPortfolioRepository(
  database: SimulationDatabase,
): DomainRepository {
  return {
    listPortfolios: (context, limit, after) =>
      scoped(database, context, async (client) => {
        const generation = await currentGeneration(client, context.tenantId);
        const ids = await client.query<{ id: string }>(
          `select id from demo_portfolios
           where tenant_id=$1 and reset_generation=$2 and status='active'
             and ($3::uuid is null or id > $3)
           order by id limit $4`,
          [context.tenantId, generation, after ?? null, limit + 1],
        );
        const pageIds = ids.rows.slice(0, limit).map((row) => row.id);
        const items: PortfolioView[] = [];
        for (const id of pageIds) {
          const item = await portfolioView(client, context.tenantId, id);
          if (item !== null) items.push(item);
        }
        return {
          items,
          nextPosition:
            ids.rows.length > limit ? (pageIds.at(-1) ?? null) : null,
        };
      }),
    createPortfolio: (context, input, key) =>
      idempotentMutation(
        database,
        context,
        "portfolio.create",
        key,
        input,
        async (client, generation) => {
          const count = await client.query<{ count: number }>(
            "select count(*)::integer count from demo_portfolios where tenant_id=$1 and reset_generation=$2 and status='active'",
            [context.tenantId, generation],
          );
          if (Number(count.rows[0]?.count) >= 5)
            throw new SimulationInputError("demo_portfolio_cap");
          const portfolioId = crypto.randomUUID();
          await client.query(
            `insert into demo_portfolios(id,tenant_id,reset_generation,name,currency,status)
             values ($1,$2,$3,$4,$5,'active')`,
            [
              portfolioId,
              context.tenantId,
              generation,
              input.name,
              input.currency,
            ],
          );
          for (const target of input.target_allocation ?? []) {
            const inserted = await client.query(
              `insert into portfolio_target_allocations(tenant_id,portfolio_id,asset_id,target_bps)
               select $1,$2,asset.id,$4 from assets asset where asset.id=$3 and asset.status='active' and asset.is_demo`,
              [
                context.tenantId,
                portfolioId,
                target.asset_id,
                target.target_bps,
              ],
            );
            if (inserted.rowCount !== 1) throw new SimulationNotFoundError();
          }
          const view = await portfolioView(
            client,
            context.tenantId,
            portfolioId,
          );
          if (view === null) throw new SimulationNotFoundError();
          return view;
        },
      ),
    getPortfolio: (context, portfolioId) =>
      scoped(database, context, (client) =>
        portfolioView(client, context.tenantId, portfolioId),
      ),
    patchPortfolio: (context, portfolioId, input, version) =>
      scoped(database, context, async (client) => {
        const generation = await currentGeneration(client, context.tenantId);
        const updated = await client.query(
          `update demo_portfolios set name=coalesce($5,name),version=version+1
           where tenant_id=$1 and id=$2 and reset_generation=$3 and version=$4 and status='active'`,
          [
            context.tenantId,
            portfolioId,
            generation,
            version,
            input.name ?? null,
          ],
        );
        if (updated.rowCount !== 1) {
          const exists = await client.query(
            "select 1 from demo_portfolios where tenant_id=$1 and id=$2 and reset_generation=$3",
            [context.tenantId, portfolioId, generation],
          );
          if (exists.rowCount === 1)
            throw new SimulationConflictError("version_conflict");
          return null;
        }
        if (input.target_allocation !== undefined) {
          await client.query(
            "delete from portfolio_target_allocations where tenant_id=$1 and portfolio_id=$2",
            [context.tenantId, portfolioId],
          );
          for (const target of input.target_allocation) {
            const inserted = await client.query(
              `insert into portfolio_target_allocations(tenant_id,portfolio_id,asset_id,target_bps,version)
               select $1,$2,asset.id,$4,$5+1 from assets asset where asset.id=$3 and asset.status='active' and asset.is_demo`,
              [
                context.tenantId,
                portfolioId,
                target.asset_id,
                target.target_bps,
                version,
              ],
            );
            if (inserted.rowCount !== 1) throw new SimulationNotFoundError();
          }
        }
        return portfolioView(client, context.tenantId, portfolioId);
      }),
    archivePortfolio: (context, portfolioId, version) =>
      scoped(database, context, async (client) => {
        const generation = await currentGeneration(client, context.tenantId);
        const blocked = await client.query(
          `select 1 from demo_portfolios portfolio
           where portfolio.tenant_id=$1 and portfolio.id=$2 and portfolio.reset_generation=$3
             and (portfolio.is_default or exists (
               select 1 from recurring_plans plan where plan.tenant_id=portfolio.tenant_id
                 and plan.portfolio_id=portfolio.id and plan.reset_generation=$3 and plan.status='active'
             ))`,
          [context.tenantId, portfolioId, generation],
        );
        if (blocked.rowCount === 1)
          throw new SimulationConflictError("portfolio_archive_blocked");
        const result = await client.query(
          `update demo_portfolios set status='archived',version=version+1
           where tenant_id=$1 and id=$2 and reset_generation=$3 and version=$4 and status='active'`,
          [context.tenantId, portfolioId, generation, version],
        );
        if (result.rowCount === 1) return true;
        const exists = await client.query(
          "select 1 from demo_portfolios where tenant_id=$1 and id=$2 and reset_generation=$3",
          [context.tenantId, portfolioId, generation],
        );
        if (exists.rowCount === 1)
          throw new SimulationConflictError("version_conflict");
        return false;
      }),
    listHoldings: (context, portfolioId, limit, after) =>
      scoped(database, context, async (client) => {
        const view = await portfolioView(client, context.tenantId, portfolioId);
        if (view === null) throw new SimulationNotFoundError();
        const filtered = view.positions.filter(
          (item) => after === undefined || item.asset_id > after,
        );
        return {
          items: filtered.slice(0, limit),
          nextPosition:
            filtered.length > limit
              ? (filtered[limit - 1]?.asset_id ?? null)
              : null,
        };
      }),
    listActivity: (context, portfolioId, input) =>
      scoped(database, context, async (client) => {
        const generation = await currentGeneration(client, context.tenantId);
        const limit = Number(input.limit ?? 20);
        const after = typeof input.after === "string" ? input.after : null;
        const from = typeof input.from === "string" ? input.from : null;
        const to = typeof input.to === "string" ? input.to : null;
        const exists = await client.query(
          "select 1 from demo_portfolios where tenant_id=$1 and id=$2 and reset_generation=$3",
          [context.tenantId, portfolioId, generation],
        );
        if (exists.rowCount !== 1) throw new SimulationNotFoundError();
        const result = await client.query(
          `select transaction.id,transaction.entry_type,transaction.effective_at,
             transaction.description_code,transaction.ledger_sequence,
             coalesce(sum(cash.amount_minor),0)::text cash_minor
           from ledger_transactions transaction
           left join cash_ledger_entries cash on cash.tenant_id=transaction.tenant_id and cash.transaction_id=transaction.id
           where transaction.tenant_id=$1 and transaction.portfolio_id=$2 and transaction.reset_generation=$3
             and ($4::bigint is null or transaction.ledger_sequence < $4)
             and ($5::timestamptz is null or transaction.effective_at >= $5)
             and ($6::timestamptz is null or transaction.effective_at < $6)
           group by transaction.id
           order by transaction.ledger_sequence desc limit $7`,
          [
            context.tenantId,
            portfolioId,
            generation,
            after,
            from,
            to,
            limit + 1,
          ],
        );
        const rows = result.rows.slice(0, limit).map((row) => ({
          id: row.id,
          type: row.entry_type,
          effective_at: toIso(row.effective_at),
          description_code: row.description_code,
          cash: { minor_units: toNumber(row.cash_minor), currency: "USD" },
          ledger_watermark: Number(row.ledger_sequence),
          demo: demo(toIso(row.effective_at)),
        }));
        return {
          items: rows,
          nextPosition:
            result.rows.length > limit
              ? String(rows.at(-1)?.ledger_watermark)
              : null,
        };
      }),
    listSnapshots: (context, portfolioId, input) =>
      scoped(database, context, async (client) => {
        const generation = await currentGeneration(client, context.tenantId);
        const limit = Math.min(Number(input.limit ?? 20), 50);
        const after = typeof input.after === "string" ? input.after : null;
        const from = typeof input.from === "string" ? input.from : null;
        const to = typeof input.to === "string" ? input.to : null;
        const exists = await client.query(
          `select 1 from demo_portfolios
           where tenant_id=$1 and id=$2 and reset_generation=$3`,
          [context.tenantId, portfolioId, generation],
        );
        if (exists.rowCount !== 1) throw new SimulationNotFoundError();
        const result = await client.query(
          `select id,as_of_transaction_id,ledger_watermark,as_of,cash_minor,market_value_minor
           from portfolio_balance_snapshots
           where tenant_id=$1 and portfolio_id=$2 and reset_generation=$3
             and ($4::bigint is null or ledger_watermark < $4)
             and ($5::timestamptz is null or as_of >= $5)
             and ($6::timestamptz is null or as_of < $6)
           order by ledger_watermark desc limit $7`,
          [
            context.tenantId,
            portfolioId,
            generation,
            after,
            from,
            to,
            limit + 1,
          ],
        );
        const rows = result.rows.slice(0, limit).map((row) => ({
          id: row.id,
          as_of_transaction_id: row.as_of_transaction_id,
          ledger_watermark: Number(row.ledger_watermark),
          as_of: toIso(row.as_of),
          cash: { minor_units: toNumber(row.cash_minor), currency: "USD" },
          market_value: {
            minor_units: toNumber(row.market_value_minor),
            currency: "USD",
          },
          demo: demo(toIso(row.as_of)),
        }));
        return {
          items: rows,
          nextPosition:
            result.rows.length > limit
              ? String(rows.at(-1)?.ledger_watermark)
              : null,
        };
      }),
    listFundingSources: (context) =>
      scoped(database, context, async (client) => {
        const generation = await currentGeneration(client, context.tenantId);
        const result = await client.query(
          `select id,fixture_key,display_label,fictional_last4,status from demo_funding_sources
           where tenant_id=$1 and reset_generation=$2 order by id`,
          [context.tenantId, generation],
        );
        return result.rows.map((row) => ({
          ...row,
          demo: demo(new Date().toISOString()),
        })) as FundingSource[];
      }),
    createFundingSource: (context, input, key) =>
      idempotentMutation(
        database,
        context,
        "funding-source.create",
        key,
        input,
        async (client, generation) => {
          const fixtures = {
            moon_reserve: ["Moon Reserve (fictional)", "1108"],
            constellation_savings: [
              "Constellation Savings (fictional)",
              "2042",
            ],
          } as const;
          const [label, last4] = fixtures[input.fixture_key];
          const result = await client.query(
            `insert into demo_funding_sources(tenant_id,reset_generation,fixture_key,display_label,fictional_last4,status)
           values ($1,$2,$3,$4,$5,'active')
           on conflict (tenant_id,reset_generation,fixture_key)
           do update set status='active'
           returning id,fixture_key,display_label,fictional_last4,status`,
            [context.tenantId, generation, input.fixture_key, label, last4],
          );
          return {
            ...result.rows[0],
            demo: demo(new Date().toISOString()),
          } as FundingSource;
        },
      ),
    deleteFundingSource: (context, sourceId) =>
      scoped(database, context, async (client) => {
        const generation = await currentGeneration(client, context.tenantId);
        const dependent = await client.query(
          `select 1 from recurring_plans where tenant_id=$1 and source_id=$2
             and reset_generation=$3 and status='active'`,
          [context.tenantId, sourceId, generation],
        );
        if (dependent.rowCount === 1)
          throw new SimulationConflictError("funding_source_in_use");
        const result = await client.query(
          `update demo_funding_sources set status='inactive'
           where tenant_id=$1 and id=$2 and reset_generation=$3`,
          [context.tenantId, sourceId, generation],
        );
        return result.rowCount === 1;
      }),
    async contribute(context, portfolioId, input, idempotencyKey) {
      const claimed = await claim<SimulationResult>(
        database,
        context,
        "portfolio.contribution",
        idempotencyKey,
        { portfolio_id: portfolioId, ...input },
      );
      if (claimed.terminal !== null) return claimed.terminal;
      return scoped(database, context, async (client) => {
        const state = await client.query<{ reset_generation: number }>(
          "select reset_generation from tenant_demo_states where tenant_id=$1 for update",
          [context.tenantId],
        );
        if (Number(state.rows[0]?.reset_generation) !== claimed.generation)
          throw new SimulationConflictError("demo_generation_conflict");
        const existing = await client.query<{
          state: string;
          claim_owner: string | null;
          terminal_response: SimulationResult | null;
        }>(
          `select state,claim_owner,terminal_response from idempotency_records
           where tenant_id=$1 and id=$2 for update`,
          [context.tenantId, claimed.id],
        );
        const idempotency = existing.rows[0];
        if (idempotency?.state !== "processing") {
          if (
            idempotency?.terminal_response !== null &&
            idempotency?.terminal_response !== undefined
          )
            return idempotency.terminal_response;
          throw new SimulationConflictError("terminal_result_missing");
        }
        if (idempotency.claim_owner !== claimed.owner)
          throw new SimulationInProgressError();

        const portfolio = await client.query<{
          currency: string;
          version: number;
          status: string;
        }>(
          `select currency,version,status from demo_portfolios
           where tenant_id=$1 and id=$2 and reset_generation=$3 for update`,
          [context.tenantId, portfolioId, claimed.generation],
        );
        const aggregate = portfolio.rows[0];
        if (aggregate === undefined || aggregate.status !== "active")
          throw new SimulationNotFoundError();
        if (aggregate.currency !== input.amount.currency)
          throw new SimulationInputError("currency_mismatch");
        const source = await client.query(
          `select 1 from demo_funding_sources
           where tenant_id=$1 and id=$2 and reset_generation=$3 and status='active'`,
          [context.tenantId, input.source_id, claimed.generation],
        );
        if (source.rowCount !== 1) throw new SimulationNotFoundError();

        const commandId = crypto.randomUUID();
        const transactionId = crypto.randomUUID();
        const effectiveAt = input.effective_at ?? new Date().toISOString();
        await client.query(
          `insert into simulation_commands(
            id,tenant_id,reset_generation,portfolio_id,idempotency_id,command_type,status,committed_at
          ) values ($1,$2,$3,$4,$5,'contribution','committed',now())`,
          [
            commandId,
            context.tenantId,
            claimed.generation,
            portfolioId,
            claimed.id,
          ],
        );
        const transaction = await client.query<{ ledger_sequence: string }>(
          `insert into ledger_transactions(
            id,tenant_id,reset_generation,portfolio_id,command_id,entry_type,effective_at,description_code
          ) values ($1,$2,$3,$4,$5,'contribution',$6,'demo_contribution')
          returning ledger_sequence`,
          [
            transactionId,
            context.tenantId,
            claimed.generation,
            portfolioId,
            commandId,
            effectiveAt,
          ],
        );
        await client.query(
          `insert into cash_ledger_entries(tenant_id,transaction_id,currency,amount_minor)
           values ($1,$2,$3,$4)`,
          [
            context.tenantId,
            transactionId,
            input.amount.currency,
            input.amount.minor_units,
          ],
        );
        const nextVersion = Number(aggregate.version) + 1;
        const watermark = Number(transaction.rows[0]?.ledger_sequence);
        const totals = await client.query<{ cash_minor: string }>(
          `select coalesce(sum(entry.amount_minor),0)::text cash_minor
           from ledger_transactions transaction
           join cash_ledger_entries entry
             on entry.tenant_id=transaction.tenant_id and entry.transaction_id=transaction.id
           where transaction.tenant_id=$1 and transaction.portfolio_id=$2
             and transaction.reset_generation=$3`,
          [context.tenantId, portfolioId, claimed.generation],
        );
        const generation = await client.query<{ value: number }>(
          `select coalesce(max(projection_generation),0)+1 value
           from portfolio_balance_snapshots where tenant_id=$1 and portfolio_id=$2`,
          [context.tenantId, portfolioId],
        );
        const snapshotId = crypto.randomUUID();
        await client.query(
          `insert into portfolio_balance_snapshots(
            id,tenant_id,portfolio_id,as_of_transaction_id,ledger_watermark,
            reset_generation,projection_generation,as_of,cash_minor,market_value_minor,source_hash
          ) values ($1,$2,$3,$4,$5,$6,$7,now(),$8,0,$9)`,
          [
            snapshotId,
            context.tenantId,
            portfolioId,
            transactionId,
            watermark,
            claimed.generation,
            Number(generation.rows[0]?.value),
            totals.rows[0]?.cash_minor ?? "0",
            await sha256({ transaction_id: transactionId, watermark }),
          ],
        );
        const advanced = await client.query(
          `update demo_portfolios
           set version=$3,current_snapshot_id=$4,current_ledger_watermark=$5
           where tenant_id=$1 and id=$2 and reset_generation=$6
             and version=$7 and current_ledger_watermark < $5`,
          [
            context.tenantId,
            portfolioId,
            nextVersion,
            snapshotId,
            watermark,
            claimed.generation,
            aggregate.version,
          ],
        );
        if (advanced.rowCount !== 1)
          throw new SimulationConflictError("version_conflict");
        const observedAt = toIso(effectiveAt);
        const result: SimulationResult = {
          command_id: commandId,
          status: "committed",
          portfolio_version: nextVersion,
          ledger_transaction_ids: [transactionId],
          summary: { kind: "contribution", amount: input.amount },
          projection_links: [],
          demo: demo(observedAt),
        };
        const completed = await client.query(
          `update idempotency_records
           set state='completed',command_id=$3,response_hash=$4,terminal_response=$5::jsonb,
               lease_until=null
           where tenant_id=$1 and id=$2 and state='processing' and claim_owner=$6`,
          [
            context.tenantId,
            claimed.id,
            commandId,
            await sha256(result),
            JSON.stringify(result),
            claimed.owner,
          ],
        );
        if (completed.rowCount !== 1) throw new SimulationInProgressError();
        return result;
      });
    },
  };
}
