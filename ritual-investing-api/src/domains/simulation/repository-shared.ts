import type { PoolClient } from "@neondatabase/serverless";

import {
  withScopedRuntimeClient,
  type DatabasePoolFactory,
} from "../../db/client.ts";
import { createRequestDatabaseContext } from "../../db/request-context.ts";
import type { MemberContext } from "../accounts/repository.ts";
import type {
  CheckoutSession,
  DemoEntitlement,
  FutureMirror,
  Intention,
  OrderView,
  PortfolioView,
  RecurringPlan,
  SimulationResult,
} from "./schemas.ts";
import {
  SimulationConflictError,
  SimulationInProgressError,
  SimulationInputError,
  SimulationNotFoundError,
} from "./repository-contract.ts";

export function requestContext(context: MemberContext) {
  return createRequestDatabaseContext({
    accountId: context.accountId,
    tenantId: context.tenantId,
    accountStatus: context.accountStatus,
    tenantStatus: context.tenantStatus,
    revocationEpoch: context.revocationEpoch,
    principal: context.subject,
  });
}

export type SimulationDatabase = {
  url: string;
  poolFactory: DatabasePoolFactory | undefined;
};

export function scoped<T>(
  database: SimulationDatabase,
  context: MemberContext,
  callback: (client: PoolClient) => Promise<T>,
) {
  return withScopedRuntimeClient(
    database.url,
    requestContext(context),
    callback,
    database.poolFactory,
  );
}

export function canonicalize(value: unknown): string {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(canonicalize).join(",")}]`;
  const entries = Object.entries(value as Record<string, unknown>)
    .filter(([, entry]) => entry !== undefined)
    .sort(([left], [right]) => (left < right ? -1 : left > right ? 1 : 0));
  return `{${entries
    .map(([key, entry]) => `${JSON.stringify(key)}:${canonicalize(entry)}`)
    .join(",")}}`;
}

export async function sha256(value: unknown): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(canonicalize(value)),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export type Claim<T> = {
  id: string;
  generation: number;
  requestHash: string;
  owner: string;
  terminal: T | null;
};

export function terminalRejectionCode(value: unknown): string {
  if (
    typeof value === "object" &&
    value !== null &&
    "error" in value &&
    typeof value.error === "object" &&
    value.error !== null &&
    "code" in value.error &&
    typeof value.error.code === "string"
  )
    return value.error.code;
  return "terminal_result_missing";
}

export async function claim<T>(
  database: SimulationDatabase,
  context: MemberContext,
  operation: string,
  key: string,
  request: unknown,
): Promise<Claim<T>> {
  const requestHash = await sha256(request);
  const owner = crypto.randomUUID();
  return scoped(database, context, async (client) => {
    const state = await client.query<{ reset_generation: number }>(
      "select reset_generation from tenant_demo_states where tenant_id=$1 for update",
      [context.tenantId],
    );
    const generation = Number(state.rows[0]?.reset_generation);
    if (!Number.isInteger(generation)) throw new SimulationNotFoundError();
    await client.query(
      `insert into idempotency_records(
        tenant_id,reset_generation,operation,idempotency_key,request_hash,state,
        claim_owner,lease_until,expires_at
      ) values ($1,$2,$3,$4,$5,'processing',$6,now()+interval '30 seconds',now()+interval '24 hours')
      on conflict (tenant_id,reset_generation,operation,idempotency_key) do nothing`,
      [context.tenantId, generation, operation, key, requestHash, owner],
    );
    const selected = await client.query<{
      id: string;
      request_hash: string;
      state: "processing" | "completed" | "rejected";
      claim_owner: string | null;
      lease_until: Date | null;
      terminal_response: T | null;
    }>(
      `select id,request_hash,state,claim_owner,lease_until,terminal_response
       from idempotency_records
       where tenant_id=$1 and reset_generation=$2 and operation=$3 and idempotency_key=$4
       for update`,
      [context.tenantId, generation, operation, key],
    );
    const record = selected.rows[0];
    if (record === undefined) throw new SimulationInProgressError();
    if (record.request_hash !== requestHash)
      throw new SimulationConflictError("idempotency_conflict");
    if (record.state !== "processing") {
      if (record.terminal_response === null)
        throw new SimulationConflictError("terminal_result_missing");
      if (record.state === "rejected")
        throw new SimulationConflictError(
          terminalRejectionCode(record.terminal_response),
        );
      return {
        id: record.id,
        generation,
        requestHash,
        owner,
        terminal: record.terminal_response,
      };
    }
    if (
      record.claim_owner !== owner &&
      record.lease_until !== null &&
      record.lease_until.getTime() > Date.now()
    )
      throw new SimulationInProgressError();
    if (record.claim_owner !== owner) {
      const recovered = await client.query(
        `update idempotency_records
         set claim_owner=$5,lease_until=now()+interval '30 seconds'
         where tenant_id=$1 and reset_generation=$2 and operation=$3 and idempotency_key=$4
           and state='processing' and lease_until <= now()`,
        [context.tenantId, generation, operation, key, owner],
      );
      if (recovered.rowCount !== 1) throw new SimulationInProgressError();
    }
    return { id: record.id, generation, requestHash, owner, terminal: null };
  });
}

export async function claimReset<T>(
  database: SimulationDatabase,
  context: MemberContext,
  key: string,
  request: unknown,
): Promise<Claim<T>> {
  const requestHash = await sha256(request);
  const owner = crypto.randomUUID();
  return scoped(database, context, async (client) => {
    const generation = await currentGeneration(client, context.tenantId, true);
    const existing = await client.query<{
      id: string;
      reset_generation: number;
      request_hash: string;
      state: "processing" | "completed" | "rejected";
      claim_owner: string | null;
      lease_until: Date | null;
      terminal_response: T | null;
    }>(
      `select id,reset_generation,request_hash,state,claim_owner,lease_until,terminal_response
       from idempotency_records
       where tenant_id=$1 and operation='demo.reset' and idempotency_key=$2
       order by reset_generation desc limit 1 for update`,
      [context.tenantId, key],
    );
    const prior = existing.rows[0];
    if (prior !== undefined) {
      if (prior.request_hash !== requestHash)
        throw new SimulationConflictError("idempotency_conflict");
      if (prior.state === "completed" && prior.terminal_response !== null)
        return {
          id: prior.id,
          generation: Number(prior.reset_generation),
          requestHash,
          owner,
          terminal: prior.terminal_response,
        };
      if (prior.state === "rejected")
        throw new SimulationConflictError(
          terminalRejectionCode(prior.terminal_response),
        );
      if (
        prior.lease_until !== null &&
        prior.lease_until.getTime() > Date.now()
      )
        throw new SimulationInProgressError();
      const recovered = await client.query(
        `update idempotency_records set claim_owner=$3,lease_until=now()+interval '30 seconds'
         where tenant_id=$1 and id=$2 and state='processing' and lease_until <= now()`,
        [context.tenantId, prior.id, owner],
      );
      if (recovered.rowCount !== 1) throw new SimulationInProgressError();
      return {
        id: prior.id,
        generation: Number(prior.reset_generation),
        requestHash,
        owner,
        terminal: null,
      };
    }
    const inserted = await client.query<{ id: string }>(
      `insert into idempotency_records(
        tenant_id,reset_generation,operation,idempotency_key,request_hash,state,
        claim_owner,lease_until,expires_at
      ) values ($1,$2,'demo.reset',$3,$4,'processing',$5,now()+interval '30 seconds',now()+interval '24 hours')
      returning id`,
      [context.tenantId, generation, key, requestHash, owner],
    );
    return {
      id: inserted.rows[0]!.id,
      generation,
      requestHash,
      owner,
      terminal: null,
    };
  });
}

export const demo = (observedAt: string) => ({
  is_demo: true as const,
  observed_at: observedAt,
  source_label: "Ritual deterministic Demo",
  limitations: [
    "No money moves and no external financial provider is contacted.",
    "Demo outcomes are not advice or a guarantee.",
  ],
});

export function toIso(value: Date | string): string {
  return new Date(value).toISOString();
}

export function quantity(value: string | number) {
  const canonical = String(value)
    .replace(/(\.\d*?[1-9])0+$/, "$1")
    .replace(/\.0+$/, "");
  const decimal = canonical.split(".")[1];
  return { value: canonical, scale: decimal?.length ?? 0 };
}

export function toNumber(value: string | number | bigint): number {
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed))
    throw new SimulationInputError("demo_cap_exceeded");
  return parsed;
}

export async function currentGeneration(
  client: PoolClient,
  tenantId: string,
  lock = false,
) {
  const result = await client.query<{ reset_generation: number }>(
    `select reset_generation from tenant_demo_states where tenant_id=$1${lock ? " for update" : ""}`,
    [tenantId],
  );
  const generation = Number(result.rows[0]?.reset_generation);
  if (!Number.isInteger(generation)) throw new SimulationNotFoundError();
  return generation;
}

export async function portfolioView(
  client: PoolClient,
  tenantId: string,
  portfolioId: string,
): Promise<PortfolioView | null> {
  const result = await client.query<{
    id: string;
    name: string;
    currency: "USD";
    status: "active" | "archived";
    is_default: boolean;
    version: number;
    current_snapshot_id: string | null;
    as_of_transaction_id: string | null;
    current_ledger_watermark: string;
    cash_minor: string;
    market_value_minor: string;
    positions: Array<{
      asset_id: string;
      symbol: string;
      quantity: string;
      market_value_minor: number;
      as_of_transaction_id: string;
      ledger_watermark: number;
    }>;
    targets: Array<{ asset_id: string; target_bps: number }>;
  }>(
    `select portfolio.id,portfolio.name,portfolio.currency,portfolio.status,
       portfolio.is_default,portfolio.version,portfolio.current_snapshot_id,
       portfolio.current_ledger_watermark,snapshot.as_of_transaction_id,
       coalesce(snapshot.cash_minor,0)::text cash_minor,
       coalesce(snapshot.market_value_minor,0)::text market_value_minor,
       coalesce((
         select json_agg(json_build_object(
           'asset_id',position.asset_id,'symbol',asset.symbol,
           'quantity',position.quantity::text,
           'market_value_minor',round(position.quantity * coalesce(metric.price_minor,0))::bigint,
           'as_of_transaction_id',position.as_of_transaction_id,
           'ledger_watermark',position.ledger_watermark
         ) order by position.asset_id)
         from portfolio_positions position
         join assets asset on asset.id=position.asset_id
         left join lateral (
           select price_minor from asset_metric_snapshots
           where asset_id=position.asset_id and is_demo order by observed_at desc,id desc limit 1
         ) metric on true
         where position.tenant_id=portfolio.tenant_id and position.portfolio_id=portfolio.id
       ),'[]') positions,
       coalesce((
         select json_agg(json_build_object('asset_id',target.asset_id,'target_bps',target.target_bps) order by target.asset_id)
         from portfolio_target_allocations target
         where target.tenant_id=portfolio.tenant_id and target.portfolio_id=portfolio.id
       ),'[]') targets
     from demo_portfolios portfolio
     join tenant_demo_states state on state.tenant_id=portfolio.tenant_id
     left join portfolio_balance_snapshots snapshot
       on snapshot.tenant_id=portfolio.tenant_id and snapshot.portfolio_id=portfolio.id
      and snapshot.id=portfolio.current_snapshot_id
     where portfolio.tenant_id=$1 and portfolio.id=$2
       and portfolio.reset_generation=state.reset_generation`,
    [tenantId, portfolioId],
  );
  const row = result.rows[0];
  if (row === undefined) return null;
  const positions = row.positions.map((position) => ({
    asset_id: position.asset_id,
    symbol: position.symbol,
    quantity: quantity(position.quantity),
    market_value: {
      minor_units: toNumber(position.market_value_minor),
      currency: "USD" as const,
    },
    as_of_transaction_id: position.as_of_transaction_id,
    ledger_watermark: Number(position.ledger_watermark),
  }));
  const cash = toNumber(row.cash_minor);
  const marketValue = toNumber(row.market_value_minor);
  return {
    id: row.id,
    name: row.name,
    currency: row.currency,
    status: row.status,
    is_default: row.is_default,
    cash: { minor_units: cash, currency: "USD" },
    positions,
    target_allocation: row.targets,
    latest_valuation: { minor_units: cash + marketValue, currency: "USD" },
    as_of_transaction_id: row.as_of_transaction_id,
    ledger_watermark: Number(row.current_ledger_watermark),
    version: Number(row.version),
    demo: demo(new Date().toISOString()),
  };
}

export async function orderView(
  client: PoolClient,
  tenantId: string,
  orderId: string,
): Promise<OrderView | null> {
  return (await orderViews(client, tenantId, [orderId]))[0] ?? null;
}

export async function orderViews(
  client: PoolClient,
  tenantId: string,
  orderIds: readonly string[],
): Promise<OrderView[]> {
  if (orderIds.length === 0) return [];
  const result = await client.query(
    `select orders.id,orders.portfolio_id,orders.command_id,orders.asset_id,asset.symbol,
       orders.side,orders.status,orders.requested_notional_minor,orders.requested_quantity,
       fill.quantity fill_quantity,fill.price_minor,fill.filled_at
     from simulated_orders orders
     join assets asset on asset.id=orders.asset_id
     join tenant_demo_states state on state.tenant_id=orders.tenant_id
     join simulation_commands command on command.tenant_id=orders.tenant_id and command.id=orders.command_id
       and command.reset_generation=state.reset_generation
     left join simulated_order_fills fill on fill.tenant_id=orders.tenant_id and fill.order_id=orders.id
     where orders.tenant_id=$1 and orders.id=any($2::uuid[])`,
    [tenantId, orderIds],
  );
  const byId = new Map(
    result.rows.map((row) => [row.id, orderRow(row)] as const),
  );
  return orderIds.flatMap((id) => {
    const view = byId.get(id);
    return view === undefined ? [] : [view];
  });
}

function orderRow(row: any): OrderView {
  const observedAt =
    row.filled_at === null ? new Date().toISOString() : toIso(row.filled_at);
  return {
    id: row.id,
    portfolio_id: row.portfolio_id,
    command_id: row.command_id,
    asset_id: row.asset_id,
    symbol: row.symbol,
    side: row.side,
    status: row.status,
    quantity:
      row.requested_quantity === null ? null : quantity(row.requested_quantity),
    notional:
      row.requested_notional_minor === null
        ? null
        : {
            minor_units: toNumber(row.requested_notional_minor),
            currency: "USD",
          },
    fill:
      row.fill_quantity === null
        ? null
        : {
            quantity: quantity(row.fill_quantity),
            price: { minor_units: toNumber(row.price_minor), currency: "USD" },
            filled_at: observedAt,
          },
    demo: demo(observedAt),
  } as OrderView;
}

export async function recurringPlanView(
  client: PoolClient,
  tenantId: string,
  planId: string,
): Promise<RecurringPlan | null> {
  return (await recurringPlanViews(client, tenantId, [planId]))[0] ?? null;
}

export async function recurringPlanViews(
  client: PoolClient,
  tenantId: string,
  planIds: readonly string[],
): Promise<RecurringPlan[]> {
  if (planIds.length === 0) return [];
  const result = await client.query(
    `select plan.id,plan.portfolio_id,plan.plan_type,plan.amount_minor::text,
       plan.frequency,plan.next_run_at,plan.status,plan.version,
       coalesce((select json_agg(json_build_object('asset_id',allocation.asset_id,'weight_bps',allocation.weight_bps) order by allocation.asset_id)
         from recurring_plan_allocations allocation where allocation.tenant_id=plan.tenant_id and allocation.plan_id=plan.id),'[]') allocations,
       coalesce((select json_agg(run_view order by run_view.scheduled_for desc)
         from (select id,scheduled_for,status from recurring_plan_runs
           where tenant_id=plan.tenant_id and plan_id=plan.id order by scheduled_for desc limit 10) run_view),'[]') recent_runs
     from recurring_plans plan
     join tenant_demo_states state on state.tenant_id=plan.tenant_id and state.reset_generation=plan.reset_generation
     where plan.tenant_id=$1 and plan.id=any($2::uuid[])`,
    [tenantId, planIds],
  );
  const byId = new Map(
    result.rows.map((row) => [row.id, recurringPlanRow(row)] as const),
  );
  return planIds.flatMap((id) => {
    const view = byId.get(id);
    return view === undefined ? [] : [view];
  });
}

function recurringPlanRow(row: any): RecurringPlan {
  return {
        id: row.id,
        portfolio_id: row.portfolio_id,
        type: row.plan_type,
        amount: { minor_units: toNumber(row.amount_minor), currency: "USD" },
        frequency: row.frequency,
        next_run_at: toIso(row.next_run_at),
        status: row.status,
        allocations: row.allocations,
        recent_runs: row.recent_runs.map((run: any) => ({
          ...run,
          scheduled_for: toIso(run.scheduled_for),
        })),
        version: Number(row.version),
        demo: demo(new Date().toISOString()),
      } as RecurringPlan;
}

export async function intentionView(
  client: PoolClient,
  tenantId: string,
  intentionId: string,
): Promise<Intention | null> {
  const result = await client.query(
    `select intention.id,intention.portfolio_id,intention.title,
       intention.target_minor::text,intention.target_date,intention.status,
       intention.current_projection_run_id,intention.version,
       coalesce(snapshot.cash_minor + snapshot.market_value_minor,0)::text progress_minor
     from intentions intention
     join tenant_demo_states state on state.tenant_id=intention.tenant_id
       and state.reset_generation=intention.reset_generation
     join demo_portfolios portfolio on portfolio.tenant_id=intention.tenant_id
       and portfolio.id=intention.portfolio_id and portfolio.reset_generation=state.reset_generation
     left join portfolio_balance_snapshots snapshot on snapshot.tenant_id=portfolio.tenant_id
       and snapshot.portfolio_id=portfolio.id and snapshot.id=portfolio.current_snapshot_id
     where intention.tenant_id=$1 and intention.id=$2`,
    [tenantId, intentionId],
  );
  const row = result.rows[0];
  if (row === undefined) return null;
  const target = toNumber(row.target_minor);
  const progress = toNumber(row.progress_minor);
  return {
    id: row.id,
    portfolio_id: row.portfolio_id,
    title: row.title,
    target: { minor_units: target, currency: "USD" },
    target_date:
      row.target_date instanceof Date
        ? row.target_date.toISOString().slice(0, 10)
        : String(row.target_date).slice(0, 10),
    status: row.status,
    progress: { minor_units: progress, currency: "USD" },
    progress_bps:
      target === 0
        ? 0
        : progress >= target
          ? 10_000
          : Math.floor((progress * 10_000) / target),
    latest_projection_id: row.current_projection_run_id,
    version: Number(row.version),
    demo: demo(new Date().toISOString()),
  } as Intention;
}

export async function futureMirrorView(
  client: PoolClient,
  tenantId: string,
  intentionId: string,
  runId: string,
): Promise<FutureMirror | null> {
  const result = await client.query(
    `select run.id,run.intention_id,run.assumptions,run.generated_at,run.model_version,
       run.input_hash,run.ledger_watermark,run.uncertainty_copy,
       coalesce(json_agg(json_build_object(
         'date',point.point_date,
         'low',json_build_object('minor_units',point.low_minor,'currency','USD'),
         'mid',json_build_object('minor_units',point.mid_minor,'currency','USD'),
         'high',json_build_object('minor_units',point.high_minor,'currency','USD')
       ) order by point.point_date) filter (where point.run_id is not null),'[]') points
     from projection_runs run
     join intentions intention on intention.tenant_id=run.tenant_id and intention.id=run.intention_id
       and intention.reset_generation=run.reset_generation
     join tenant_demo_states state on state.tenant_id=run.tenant_id
       and state.reset_generation=run.reset_generation
     left join projection_points point on point.tenant_id=run.tenant_id and point.run_id=run.id
     where run.tenant_id=$1 and run.intention_id=$2 and run.id=$3
     group by run.id`,
    [tenantId, intentionId, runId],
  );
  const row = result.rows[0];
  return row === undefined
    ? null
    : ({
        id: row.id,
        intention_id: row.intention_id,
        assumptions: row.assumptions,
        points: row.points.map((point: any) => ({
          ...point,
          date: String(point.date).slice(0, 10),
          low: {
            minor_units: toNumber(point.low.minor_units),
            currency: "USD",
          },
          mid: {
            minor_units: toNumber(point.mid.minor_units),
            currency: "USD",
          },
          high: {
            minor_units: toNumber(point.high.minor_units),
            currency: "USD",
          },
        })),
        generated_at: toIso(row.generated_at),
        model_version: row.model_version,
        input_hash: row.input_hash,
        ledger_watermark: Number(row.ledger_watermark),
        uncertainty: row.uncertainty_copy,
        demo: demo(toIso(row.generated_at)),
      } as FutureMirror);
}

export async function entitlementView(
  client: PoolClient,
  tenantId: string,
): Promise<DemoEntitlement> {
  const result = await client.query(
    `select entitlement.id,case when plan.code='demo' then 'free' else plan.code end plan_code,
       entitlement.status,entitlement.source,entitlement.starts_at,entitlement.ends_at,entitlement.version
     from tenant_entitlements entitlement
     join demo_plans plan on plan.id=entitlement.plan_id
     join tenant_demo_states state on state.tenant_id=entitlement.tenant_id
       and state.reset_generation=entitlement.reset_generation
     where entitlement.tenant_id=$1 and entitlement.status='active'
     order by entitlement.starts_at desc limit 1`,
    [tenantId],
  );
  const row = result.rows[0];
  if (row === undefined) throw new SimulationNotFoundError();
  return {
    id: row.id,
    plan_code: row.plan_code,
    status: row.status,
    source: "demo",
    starts_at: toIso(row.starts_at),
    ends_at: row.ends_at === null ? null : toIso(row.ends_at),
    version: Number(row.version),
    demo: demo(new Date().toISOString()),
  } as DemoEntitlement;
}

export async function checkoutView(
  client: PoolClient,
  tenantId: string,
  sessionId: string,
): Promise<CheckoutSession | null> {
  const result = await client.query(
    `select session.id,plan.code plan_code,session.status,session.expires_at,session.version
     from demo_checkout_sessions session
     join demo_plans plan on plan.id=session.plan_id and plan.code='premium_demo'
     join tenant_demo_states state on state.tenant_id=session.tenant_id
       and state.reset_generation=session.reset_generation
     where session.tenant_id=$1 and session.id=$2`,
    [tenantId, sessionId],
  );
  const row = result.rows[0];
  return row === undefined
    ? null
    : {
        id: row.id,
        plan_code: "premium_demo",
        status: row.status,
        expires_at: toIso(row.expires_at),
        version: Number(row.version),
        demo: demo(new Date().toISOString()),
      };
}

export async function idempotentMutation<T>(
  database: SimulationDatabase,
  context: MemberContext,
  operation: string,
  key: string,
  request: unknown,
  action: (client: PoolClient, generation: number) => Promise<T>,
): Promise<T> {
  const claimed = await claim<T>(database, context, operation, key, request);
  if (claimed.terminal !== null) return claimed.terminal;
  return scoped(database, context, async (client) => {
    const generation = await currentGeneration(client, context.tenantId, true);
    if (generation !== claimed.generation)
      throw new SimulationConflictError("demo_generation_conflict");
    const record = await client.query<{
      state: string;
      claim_owner: string | null;
      terminal_response: T | null;
    }>(
      "select state,claim_owner,terminal_response from idempotency_records where tenant_id=$1 and id=$2 for update",
      [context.tenantId, claimed.id],
    );
    const selected = record.rows[0];
    if (selected?.state !== "processing") {
      if (
        selected?.terminal_response !== null &&
        selected?.terminal_response !== undefined
      )
        return selected.terminal_response;
      throw new SimulationConflictError("terminal_result_missing");
    }
    if (selected.claim_owner !== claimed.owner)
      throw new SimulationInProgressError();
    const result = await action(client, generation);
    const completed = await client.query(
      `update idempotency_records
       set state='completed',response_hash=$3,terminal_response=$4::jsonb,lease_until=null
       where tenant_id=$1 and id=$2 and state='processing' and claim_owner=$5`,
      [
        context.tenantId,
        claimed.id,
        await sha256(result),
        JSON.stringify(result),
        claimed.owner,
      ],
    );
    if (completed.rowCount !== 1) throw new SimulationInProgressError();
    return result;
  });
}

export const quantityScale = 1_000_000_000_000n;

export function quantityUnits(value: string): bigint {
  const [whole = "0", fraction = ""] = value.split(".");
  return BigInt(whole) * quantityScale + BigInt(fraction.padEnd(12, "0"));
}

export function quantityValue(value: bigint): string {
  const negative = value < 0n;
  const absolute = negative ? -value : value;
  const whole = absolute / quantityScale;
  const fraction = String(absolute % quantityScale)
    .padStart(12, "0")
    .replace(/0+$/, "");
  return `${negative ? "-" : ""}${whole}${fraction.length === 0 ? "" : `.${fraction}`}`;
}

export type TradePosting = {
  assetId: string;
  symbol: string;
  side: "buy" | "sell";
  quantityUnits: bigint;
  priceMinor: number;
  quoteSnapshotId: string;
};

export type PreparedTrades = {
  trades: TradePosting[];
  summary: Record<string, unknown>;
  cashCreditMinor?: number;
  afterCommand?: (
    client: PoolClient,
    commandId: string,
    effectiveAt: string,
  ) => Promise<void>;
};

export type FinancialOutcome =
  | { kind: "committed"; result: SimulationResult }
  | { kind: "rejected"; code: string };

export async function executeTrades(
  database: SimulationDatabase,
  context: MemberContext,
  operation: string,
  key: string,
  request: Record<string, unknown>,
  portfolioId: string,
  inputVersion: number,
  commandType: "order" | "rebalance" | "recurring",
  prepare: (
    client: PoolClient,
    generation: number,
    version: number,
  ) => Promise<PreparedTrades>,
): Promise<SimulationResult> {
  const claimed = await claim<SimulationResult>(
    database,
    context,
    operation,
    key,
    request,
  );
  if (claimed.terminal !== null) return claimed.terminal;
  const outcome = await scoped<FinancialOutcome>(
    database,
    context,
    async (client) => {
      const generation = await currentGeneration(
        client,
        context.tenantId,
        true,
      );
      if (generation !== claimed.generation)
        throw new SimulationConflictError("demo_generation_conflict");
      const idempotency = (
        await client.query<{ state: string; claim_owner: string | null }>(
          "select state,claim_owner from idempotency_records where tenant_id=$1 and id=$2 for update",
          [context.tenantId, claimed.id],
        )
      ).rows[0];
      if (
        idempotency?.state !== "processing" ||
        idempotency.claim_owner !== claimed.owner
      )
        throw new SimulationInProgressError();
      await client.query("savepoint financial_command_boundary");
      try {
        const portfolio = (
          await client.query<{ version: number; currency: string }>(
            `select version,currency from demo_portfolios
         where tenant_id=$1 and id=$2 and reset_generation=$3 and status='active' for update`,
            [context.tenantId, portfolioId, generation],
          )
        ).rows[0];
        if (portfolio === undefined) throw new SimulationNotFoundError();
        if (Number(portfolio.version) !== inputVersion)
          throw new SimulationConflictError("version_conflict");
        const prepared = await prepare(
          client,
          generation,
          Number(portfolio.version),
        );
        if (prepared.trades.length < 1)
          throw new SimulationInputError("empty_trade_set");

        const cash = BigInt(
          (
            await client.query<{ total: string }>(
              `select coalesce(sum(entry.amount_minor),0)::text total
           from ledger_transactions transaction
           join cash_ledger_entries entry on entry.tenant_id=transaction.tenant_id and entry.transaction_id=transaction.id
           where transaction.tenant_id=$1 and transaction.portfolio_id=$2 and transaction.reset_generation=$3`,
              [context.tenantId, portfolioId, generation],
            )
          ).rows[0]?.total ?? "0",
        );
        let cashChange = BigInt(prepared.cashCreditMinor ?? 0);
        const neededPositions = new Map<string, bigint>();
        for (const trade of prepared.trades) {
          const notional =
            (trade.quantityUnits * BigInt(trade.priceMinor)) / quantityScale;
          cashChange += trade.side === "buy" ? -notional : notional;
          if (trade.side === "sell")
            neededPositions.set(
              trade.assetId,
              (neededPositions.get(trade.assetId) ?? 0n) + trade.quantityUnits,
            );
        }
        if (cash + cashChange < 0n)
          throw new SimulationConflictError("insufficient_demo_cash");
        const positionState = new Map<
          string,
          { quantity: bigint; costBasis: bigint }
        >();
        for (const assetId of new Set(
          prepared.trades.map((trade) => trade.assetId),
        )) {
          const row = (
            await client.query<{ quantity: string; cost_basis_minor: string }>(
              `select quantity::text,cost_basis_minor::text from portfolio_positions
           where tenant_id=$1 and portfolio_id=$2 and asset_id=$3`,
              [context.tenantId, portfolioId, assetId],
            )
          ).rows[0];
          positionState.set(assetId, {
            quantity: quantityUnits(row?.quantity ?? "0"),
            costBasis: BigInt(row?.cost_basis_minor ?? "0"),
          });
        }
        for (const [assetId, needed] of neededPositions) {
          if ((positionState.get(assetId)?.quantity ?? 0n) < needed)
            throw new SimulationConflictError("insufficient_demo_position");
        }

        const commandId = crypto.randomUUID();
        const transactionId = crypto.randomUUID();
        const effectiveAt = new Date().toISOString();
        await client.query(
          `insert into simulation_commands(
        id,tenant_id,reset_generation,portfolio_id,idempotency_id,command_type,status,
        committed_at,portfolio_input_version,source_preview_id
      ) values ($1,$2,$3,$4,$5,$6,'committed',now(),$7,$8)`,
          [
            commandId,
            context.tenantId,
            generation,
            portfolioId,
            claimed.id,
            commandType,
            inputVersion,
            request.preview_id ?? null,
          ],
        );
        const transaction = await client.query<{ ledger_sequence: string }>(
          `insert into ledger_transactions(
        id,tenant_id,reset_generation,portfolio_id,command_id,entry_type,effective_at,description_code
      ) values ($1,$2,$3,$4,$5,$6,$7,$8) returning ledger_sequence`,
          [
            transactionId,
            context.tenantId,
            generation,
            portfolioId,
            commandId,
            commandType,
            effectiveAt,
            `demo_${commandType}`,
          ],
        );
        const watermark = Number(transaction.rows[0]?.ledger_sequence);
        if ((prepared.cashCreditMinor ?? 0) > 0)
          await client.query(
            "insert into cash_ledger_entries(tenant_id,transaction_id,currency,amount_minor) values ($1,$2,'USD',$3)",
            [context.tenantId, transactionId, prepared.cashCreditMinor],
          );
        for (const trade of prepared.trades) {
          const signedQuantity =
            trade.side === "buy" ? trade.quantityUnits : -trade.quantityUnits;
          const signedCash = -(
            (signedQuantity * BigInt(trade.priceMinor)) /
            quantityScale
          );
          const prior = positionState.get(trade.assetId) ?? {
            quantity: 0n,
            costBasis: 0n,
          };
          const costBasisDelta =
            trade.side === "buy"
              ? -signedCash
              : -((prior.costBasis * trade.quantityUnits) / prior.quantity);
          positionState.set(trade.assetId, {
            quantity: prior.quantity + signedQuantity,
            costBasis: prior.costBasis + costBasisDelta,
          });
          await client.query(
            "insert into cash_ledger_entries(tenant_id,transaction_id,currency,amount_minor) values ($1,$2,'USD',$3)",
            [context.tenantId, transactionId, signedCash.toString()],
          );
          await client.query(
            `insert into position_ledger_entries(
          tenant_id,transaction_id,asset_id,quantity,unit_price_minor,cost_basis_delta_minor
        ) values ($1,$2,$3,$4,$5,$6)`,
            [
              context.tenantId,
              transactionId,
              trade.assetId,
              quantityValue(signedQuantity),
              trade.priceMinor,
              costBasisDelta.toString(),
            ],
          );
        }
        await prepared.afterCommand?.(client, commandId, effectiveAt);

        const touched = [
          ...new Set(prepared.trades.map((trade) => trade.assetId)),
        ];
        for (const assetId of touched) {
          const derived = (
            await client.query<{ quantity: string; cost_basis: string }>(
              `select coalesce(sum(entry.quantity),0)::text quantity,
             coalesce(sum(entry.cost_basis_delta_minor),0)::text cost_basis
           from ledger_transactions transaction
           join position_ledger_entries entry on entry.tenant_id=transaction.tenant_id and entry.transaction_id=transaction.id
           where transaction.tenant_id=$1 and transaction.portfolio_id=$2
             and transaction.reset_generation=$3 and entry.asset_id=$4`,
              [context.tenantId, portfolioId, generation, assetId],
            )
          ).rows[0];
          if (derived === undefined || quantityUnits(derived.quantity) === 0n) {
            await client.query(
              "delete from portfolio_positions where tenant_id=$1 and portfolio_id=$2 and asset_id=$3",
              [context.tenantId, portfolioId, assetId],
            );
          } else {
            await client.query(
              `insert into portfolio_positions(
            tenant_id,portfolio_id,asset_id,quantity,cost_basis_minor,as_of_transaction_id,ledger_watermark
          ) values ($1,$2,$3,$4,$5,$6,$7)
          on conflict (tenant_id,portfolio_id,asset_id) do update
          set quantity=excluded.quantity,cost_basis_minor=excluded.cost_basis_minor,
              as_of_transaction_id=excluded.as_of_transaction_id,ledger_watermark=excluded.ledger_watermark
          where portfolio_positions.ledger_watermark < excluded.ledger_watermark`,
              [
                context.tenantId,
                portfolioId,
                assetId,
                derived.quantity,
                derived.cost_basis,
                transactionId,
                watermark,
              ],
            );
          }
        }
        const totals = (
          await client.query<{
            cash_minor: string;
            market_value_minor: string;
          }>(
            `select
          coalesce((select sum(entry.amount_minor) from ledger_transactions transaction
            join cash_ledger_entries entry on entry.tenant_id=transaction.tenant_id and entry.transaction_id=transaction.id
            where transaction.tenant_id=$1 and transaction.portfolio_id=$2 and transaction.reset_generation=$3),0)::text cash_minor,
          coalesce((select sum(position.quantity*coalesce(metric.price_minor,0)) from portfolio_positions position
            left join lateral (select price_minor from asset_metric_snapshots where asset_id=position.asset_id and is_demo order by observed_at desc,id desc limit 1) metric on true
            where position.tenant_id=$1 and position.portfolio_id=$2),0)::bigint::text market_value_minor`,
            [context.tenantId, portfolioId, generation],
          )
        ).rows[0];
        const projectionGeneration = Number(
          (
            await client.query<{ value: number }>(
              "select coalesce(max(projection_generation),0)+1 value from portfolio_balance_snapshots where tenant_id=$1 and portfolio_id=$2",
              [context.tenantId, portfolioId],
            )
          ).rows[0]?.value,
        );
        const snapshotId = crypto.randomUUID();
        await client.query(
          `insert into portfolio_balance_snapshots(
        id,tenant_id,portfolio_id,as_of_transaction_id,ledger_watermark,reset_generation,
        projection_generation,as_of,cash_minor,market_value_minor,source_hash
      ) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
          [
            snapshotId,
            context.tenantId,
            portfolioId,
            transactionId,
            watermark,
            generation,
            projectionGeneration,
            effectiveAt,
            totals?.cash_minor ?? "0",
            totals?.market_value_minor ?? "0",
            await sha256({ transactionId, watermark }),
          ],
        );
        const nextVersion = inputVersion + 1;
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
            generation,
            inputVersion,
          ],
        );
        if (advanced.rowCount !== 1)
          throw new SimulationConflictError("version_conflict");
        const result: SimulationResult = {
          command_id: commandId,
          status: "committed",
          portfolio_version: nextVersion,
          ledger_transaction_ids: [transactionId],
          summary: prepared.summary,
          projection_links: [],
          demo: demo(effectiveAt),
        };
        await client.query(
          `update idempotency_records set state='completed',command_id=$3,response_hash=$4,
         terminal_response=$5::jsonb,lease_until=null
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
        return { kind: "committed", result };
      } catch (error) {
        await client.query("rollback to savepoint financial_command_boundary");
        if (!(error instanceof SimulationConflictError)) throw error;
        const commandId = crypto.randomUUID();
        const terminal = { error: { code: error.code } };
        await client.query(
          `insert into simulation_commands(
           id,tenant_id,reset_generation,portfolio_id,idempotency_id,
           command_type,status,rejection_code,portfolio_input_version,
           source_preview_id
         ) values ($1,$2,$3,$4,$5,$6,'rejected',$7,$8,$9)`,
          [
            commandId,
            context.tenantId,
            generation,
            portfolioId,
            claimed.id,
            commandType,
            error.code,
            inputVersion,
            request.preview_id ?? null,
          ],
        );
        if (commandType === "order" && typeof request.preview_id === "string") {
          const preview = (
            await client.query<{
              asset_id: string;
              side: "buy" | "sell";
              requested_notional_minor: string | null;
              requested_quantity: string | null;
              quote_snapshot_id: string;
            }>(
              `select asset_id,side,requested_notional_minor::text,
               requested_quantity::text,quote_snapshot_id
             from order_previews
             where tenant_id=$1 and id=$2 and portfolio_id=$3
               and reset_generation=$4 for update`,
              [context.tenantId, request.preview_id, portfolioId, generation],
            )
          ).rows[0];
          if (preview !== undefined) {
            await client.query(
              `insert into simulated_orders(
               tenant_id,portfolio_id,command_id,asset_id,side,order_type,
               requested_notional_minor,requested_quantity,status,
               quote_snapshot_id
             ) values ($1,$2,$3,$4,$5,'market',$6,$7,'rejected',$8)`,
              [
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
            await client.query(
              `update order_previews set status='invalidated',
               executed_command_id=$3
             where tenant_id=$1 and id=$2 and status='active'`,
              [context.tenantId, request.preview_id, commandId],
            );
          }
        }
        const rejected = await client.query(
          `update idempotency_records set state='rejected',command_id=$3,
           response_hash=$4,terminal_response=$5::jsonb,lease_until=null
         where tenant_id=$1 and id=$2 and state='processing' and claim_owner=$6`,
          [
            context.tenantId,
            claimed.id,
            commandId,
            await sha256(terminal),
            JSON.stringify(terminal),
            claimed.owner,
          ],
        );
        if (rejected.rowCount !== 1) throw new SimulationInProgressError();
        return { kind: "rejected", code: error.code };
      }
    },
  );
  if (outcome.kind === "rejected")
    throw new SimulationConflictError(outcome.code);
  return outcome.result;
}
