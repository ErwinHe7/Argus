import type { SimulationRepository } from "./repository-contract.ts";
import {
  SimulationConflictError,
  SimulationInputError,
  SimulationNotFoundError,
} from "./repository-contract.ts";
import type { Intention } from "./schemas.ts";
import {
  type SimulationDatabase,
  currentGeneration,
  futureMirrorView,
  idempotentMutation,
  intentionView,
  scoped,
  sha256,
} from "./repository-shared.ts";

type DomainRepository = Pick<
  SimulationRepository,
  | "listIntentions"
  | "createIntention"
  | "getIntention"
  | "patchIntention"
  | "archiveIntention"
  | "buildFutureMirror"
  | "getLatestFutureMirror"
  | "getFutureMirror"
>;

export function createIntentionRepository(
  database: SimulationDatabase,
): DomainRepository {
  return {
    listIntentions: (context, input) =>
      scoped(database, context, async (client) => {
        const generation = await currentGeneration(client, context.tenantId);
        const limit = Number(input.limit ?? 20);
        const after = typeof input.after === "string" ? input.after : null;
        const result = await client.query<{ id: string }>(
          `select id from intentions where tenant_id=$1 and reset_generation=$2
             and ($3::text is null or status=$3)
             and ($4::uuid is null or id > $4)
           order by id limit $5`,
          [
            context.tenantId,
            generation,
            input.status ?? null,
            after,
            limit + 1,
          ],
        );
        const ids = result.rows.slice(0, limit).map((row) => row.id);
        const items: Intention[] = [];
        for (const id of ids) {
          const item = await intentionView(client, context.tenantId, id);
          if (item !== null) items.push(item);
        }
        return {
          items,
          nextPosition:
            result.rows.length > limit ? (ids.at(-1) ?? null) : null,
        };
      }),
    createIntention: (context, input, key) =>
      idempotentMutation(
        database,
        context,
        "intention.create",
        key,
        input,
        async (client, generation) => {
          const count = await client.query<{ count: number }>(
            "select count(*)::integer count from intentions where tenant_id=$1 and reset_generation=$2 and status='active'",
            [context.tenantId, generation],
          );
          if (Number(count.rows[0]?.count) >= 10)
            throw new SimulationInputError("demo_intention_cap");
          if (
            new Date(`${input.target_date}T00:00:00Z`).getTime() <= Date.now()
          )
            throw new SimulationInputError("target_date_in_past");
          const portfolio = await client.query(
            "select 1 from demo_portfolios where tenant_id=$1 and id=$2 and reset_generation=$3 and status='active'",
            [context.tenantId, input.portfolio_id, generation],
          );
          if (portfolio.rowCount !== 1) throw new SimulationNotFoundError();
          const id = crypto.randomUUID();
          await client.query(
            `insert into intentions(id,tenant_id,reset_generation,portfolio_id,title,target_minor,target_date,status,currency)
           values ($1,$2,$3,$4,$5,$6,$7,'active','USD')`,
            [
              id,
              context.tenantId,
              generation,
              input.portfolio_id,
              input.title,
              input.target.minor_units,
              input.target_date,
            ],
          );
          const view = await intentionView(client, context.tenantId, id);
          if (view === null) throw new SimulationNotFoundError();
          return view;
        },
      ),
    getIntention: (context, intentionId) =>
      scoped(database, context, (client) =>
        intentionView(client, context.tenantId, intentionId),
      ),
    patchIntention: (context, intentionId, input, version) =>
      scoped(database, context, async (client) => {
        const generation = await currentGeneration(client, context.tenantId);
        const result = await client.query(
          `update intentions set title=coalesce($5,title),target_minor=coalesce($6,target_minor),
             target_date=coalesce($7,target_date),status=coalesce($8,status),version=version+1
           where tenant_id=$1 and id=$2 and reset_generation=$3 and version=$4 and status <> 'archived'`,
          [
            context.tenantId,
            intentionId,
            generation,
            version,
            input.title ?? null,
            input.target?.minor_units ?? null,
            input.target_date ?? null,
            input.status ?? null,
          ],
        );
        if (result.rowCount !== 1) {
          const existing = await intentionView(
            client,
            context.tenantId,
            intentionId,
          );
          if (existing !== null)
            throw new SimulationConflictError("version_conflict");
          return null;
        }
        return intentionView(client, context.tenantId, intentionId);
      }),
    archiveIntention: (context, intentionId, version) =>
      scoped(database, context, async (client) => {
        const generation = await currentGeneration(client, context.tenantId);
        const result = await client.query(
          `update intentions set status='archived',version=version+1
           where tenant_id=$1 and id=$2 and reset_generation=$3 and version=$4 and status <> 'archived'`,
          [context.tenantId, intentionId, generation, version],
        );
        if (result.rowCount === 1) return true;
        const existing = await intentionView(
          client,
          context.tenantId,
          intentionId,
        );
        if (existing?.status === "archived") return true;
        if (existing !== null)
          throw new SimulationConflictError("version_conflict");
        return false;
      }),
    buildFutureMirror: (context, intentionId, input, key) =>
      idempotentMutation(
        database,
        context,
        "future-mirror.build",
        key,
        { intentionId, ...input },
        async (client, generation) => {
          const locked = await client.query(
            `select 1 from intentions
           where tenant_id=$1 and id=$2 and reset_generation=$3
             and status <> 'archived' for update`,
            [context.tenantId, intentionId, generation],
          );
          if (locked.rowCount !== 1) throw new SimulationNotFoundError();
          const intention = await intentionView(
            client,
            context.tenantId,
            intentionId,
          );
          if (intention === null || intention.status === "archived")
            throw new SimulationNotFoundError();
          const watermarkRow = (
            await client.query<{
              id: string;
              ledger_sequence: string;
              effective_at: Date;
            }>(
              `select transaction.id,transaction.ledger_sequence::text,transaction.effective_at
             from ledger_transactions transaction
             where transaction.tenant_id=$1 and transaction.portfolio_id=$2 and transaction.reset_generation=$3
             order by transaction.ledger_sequence desc limit 1`,
              [context.tenantId, intention.portfolio_id, generation],
            )
          ).rows[0];
          if (watermarkRow === undefined)
            throw new SimulationConflictError(
              "projection_requires_demo_activity",
            );
          const projectionGeneration = Number(
            (
              await client.query<{ value: number }>(
                "select coalesce(max(projection_generation),0)+1 value from projection_runs where tenant_id=$1 and intention_id=$2",
                [context.tenantId, intentionId],
              )
            ).rows[0]?.value,
          );
          const generatedAt = new Date().toISOString();
          const inputHash = await sha256({
            intention: {
              id: intention.id,
              portfolio_id: intention.portfolio_id,
              title: intention.title,
              target_minor: intention.target.minor_units,
              target_date: intention.target_date,
              status: intention.status,
              progress_minor: intention.progress.minor_units,
            },
            assumptions: input,
            ledger_watermark: watermarkRow.ledger_sequence,
            model: "ritual-demo-v1",
          });
          const runId = crypto.randomUUID();
          await client.query(
            `insert into projection_runs(
            id,tenant_id,intention_id,as_of_transaction_id,projection_generation,input_hash,
            model_version,generated_at,status,reset_generation,ledger_watermark,assumptions,uncertainty_copy
          ) values ($1,$2,$3,$4,$5,$6,'ritual-demo-v1',$7,'complete',$8,$9,$10::jsonb,$11)`,
            [
              runId,
              context.tenantId,
              intentionId,
              watermarkRow.id,
              projectionGeneration,
              inputHash,
              generatedAt,
              generation,
              watermarkRow.ledger_sequence,
              JSON.stringify(input),
              "Illustrative Demo ranges only; not advice and never a guarantee.",
            ],
          );
          const start = new Date(generatedAt);
          const end = new Date(`${intention.target_date}T00:00:00Z`);
          const months = Math.max(
            1,
            Math.min(
              120,
              (end.getUTCFullYear() - start.getUTCFullYear()) * 12 +
                end.getUTCMonth() -
                start.getUTCMonth(),
            ),
          );
          const bands = input.annual_return_bps;
          let low = intention.progress.minor_units;
          let mid = intention.progress.minor_units;
          let high = intention.progress.minor_units;
          for (let month = 1; month <= months; month += 1) {
            const monthly = input.monthly_contribution.minor_units;
            low = Math.max(
              0,
              Math.floor((low + monthly) * (1 + bands.low / 120_000)),
            );
            mid = Math.max(
              low,
              Math.floor((mid + monthly) * (1 + bands.mid / 120_000)),
            );
            high = Math.max(
              mid,
              Math.floor((high + monthly) * (1 + bands.high / 120_000)),
            );
            const date = new Date(
              Date.UTC(start.getUTCFullYear(), start.getUTCMonth() + month, 1),
            )
              .toISOString()
              .slice(0, 10);
            await client.query(
              `insert into projection_points(tenant_id,run_id,point_date,low_minor,mid_minor,high_minor)
             values ($1,$2,$3,$4,$5,$6)`,
              [context.tenantId, runId, date, low, mid, high],
            );
          }
          await client.query(
            `update intentions set current_projection_run_id=$3,current_projection_watermark=$4,
             current_projection_generation=$5
           where tenant_id=$1 and id=$2 and reset_generation=$6 and (
             current_projection_watermark < $4 or
             (current_projection_watermark = $4 and current_projection_generation < $5)
           )`,
            [
              context.tenantId,
              intentionId,
              runId,
              watermarkRow.ledger_sequence,
              projectionGeneration,
              generation,
            ],
          );
          const view = await futureMirrorView(
            client,
            context.tenantId,
            intentionId,
            runId,
          );
          if (view === null) throw new SimulationNotFoundError();
          return view;
        },
      ),
    getLatestFutureMirror: (context, intentionId) =>
      scoped(database, context, async (client) => {
        const pointer = (
          await client.query<{ current_projection_run_id: string | null }>(
            `select intention.current_projection_run_id from intentions intention
             join tenant_demo_states state on state.tenant_id=intention.tenant_id
               and state.reset_generation=intention.reset_generation
             where intention.tenant_id=$1 and intention.id=$2`,
            [context.tenantId, intentionId],
          )
        ).rows[0];
        return pointer?.current_projection_run_id === null ||
          pointer === undefined
          ? null
          : futureMirrorView(
              client,
              context.tenantId,
              intentionId,
              pointer.current_projection_run_id,
            );
      }),
    getFutureMirror: (context, intentionId, runId) =>
      scoped(database, context, (client) =>
        futureMirrorView(client, context.tenantId, intentionId, runId),
      ),
  };
}
