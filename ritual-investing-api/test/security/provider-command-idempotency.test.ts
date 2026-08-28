import { readFileSync } from "node:fs";
import { resolve } from "node:path";

import { describe, expect, it, vi } from "vitest";

import type {
  DatabaseClient,
  DatabasePool,
} from "../../src/db/database-port.ts";
import { StaffAuthorizationError } from "../../src/db/request-transaction.ts";
import { createBrokerageOrderRepository } from "../../src/domains/brokerage-orders/repository.ts";

const migration = readFileSync(
  resolve(
    import.meta.dirname,
    "../../../supabase/migrations/20260828095121_u7_manual_order_commands.sql",
  ),
  "utf8",
) + readFileSync(
  resolve(
    import.meta.dirname,
    "../../../supabase/migrations/20260828054740_argus_private_baseline.sql",
  ),
  "utf8",
);
const repository = readFileSync(
  resolve(
    import.meta.dirname,
    "../../src/domains/brokerage-orders/repository.ts",
  ),
  "utf8",
);

describe("provider command database security boundary", () => {
  it("makes the application idempotency key global and binding-sensitive", () => {
    expect(migration).toContain(
      "create unique index provider_commands_idempotency_key_unique",
    );
    for (
      const binding of [
        "existing.user_id<>p_user_id",
        "existing.connection_id<>p_connection_id",
        "existing.account_id<>p_account_id",
        "existing.operation<>p_operation",
        "existing.target_order_id is distinct from p_target_order_id",
        "existing.normalized_payload_hash<>p_payload_hash",
        "existing.normalized_payload is distinct from p_normalized_payload",
        "existing.policy_version<>p_policy_version",
      ]
    ) expect(migration).toContain(binding);
  });

  it("returns an exact duplicate before freshness and ambiguity gates but starts new work transactionally", () => {
    expect(migration).toContain(
      "select account.*,connection.status as connection_status into account_row",
    );
    expect(migration).not.toContain(
      "select account,connection.status into account_row,connection_status",
    );
    const advisoryLock = migration.indexOf(
      "pg_advisory_xact_lock(hashtextextended(p_idempotency_key,554237))",
    );
    const duplicate = migration.indexOf("select * into existing");
    const freshness = migration.indexOf("account_row.expires_at<=p_now");
    const ambiguity = migration.indexOf(
      "raise exception 'account_command_blocked'",
    );
    const commandInsert = migration.indexOf(
      "insert into argus_private.provider_commands(",
      ambiguity,
    );
    const attemptInsert = migration.indexOf(
      "insert into argus_private.provider_command_attempts(",
      commandInsert,
    );
    expect(advisoryLock).toBeGreaterThan(0);
    expect(advisoryLock).toBeLessThan(duplicate);
    expect(duplicate).toBeLessThan(freshness);
    expect(duplicate).toBeLessThan(ambiguity);
    expect(commandInsert).toBeGreaterThan(ambiguity);
    expect(attemptInsert).toBeGreaterThan(commandInsert);
    expect(migration.slice(commandInsert, attemptInsert)).toContain(
      "'dispatching',p_now",
    );
    expect(migration.slice(attemptInsert, attemptInsert + 600)).toContain(
      "'egress','started'",
    );
  });

  it("uses an account-scoped ambiguity gate and queues only a command reference", () => {
    expect(migration).toContain(
      "blocked.user_id=p_user_id and blocked.account_id=p_account_id",
    );
    expect(migration).toContain(
      "blocked.state in ('dispatching','ambiguous','reconciling','manual_review')",
    );
    expect(repository).toContain(
      "'webull.command.reconciliation.requested',id",
    );
    expect(repository).toContain("'provider-command:' || id::text");
    expect(repository).not.toMatch(
      /outbox_events[\s\S]{0,500}(normalized_payload|provider_preview_ref_ciphertext)/,
    );
  });

  it("keeps provider mappings private and client roles grant-free", () => {
    expect(migration).toContain(
      "alter table argus_private.webull_order_mappings force row level security",
    );
    expect(migration).toContain(
      "alter table argus_brokerage.order_projection_generations force row level security",
    );
    expect(migration).toContain(
      "revoke all on argus_private.webull_order_mappings",
    );
    expect(migration).toContain("from public,anon,authenticated");
    expect(migration).toContain("provider_order_ref_ciphertext bytea not null");
    expect(migration).toContain("provider_order_ref_hash text not null");
    expect(migration).toContain(
      "asset.asset_kind in ('equity','etf')",
    );
    expect(migration).toContain(
      "target_asset_kind not in ('equity','etf')",
    );
    expect(migration).toContain(
      "create or replace function argus_private.request_user_id()",
    );
    expect(migration).toContain(
      "grant execute on function argus_private.request_user_id() to argus_runtime",
    );
    expect(migration).toContain("security invoker");
    expect(migration).toContain(
      "current_setting('request.jwt.claims', true)",
    );
    expect(migration).toContain(
      "current_setting('request.jwt.claim.sub', true)",
    );
    expect(migration).not.toContain("grant usage on schema auth to argus_runtime");
    expect(migration).not.toContain(
      "grant execute on function auth.uid() to argus_runtime",
    );
    expect(migration).not.toMatch(
      /grant\s+(?:select|insert|update|delete|all)[\s\S]{0,80}auth\./i,
    );
  });

  it("purges weaker synthetic pending commands before installing the U7 boundary", () => {
    const triggerDrop = migration.indexOf(
      "drop trigger provider_command_attempts_immutable",
    );
    const attemptPurge = migration.indexOf(
      "delete from argus_private.provider_command_attempts;",
    );
    const pendingPurge = migration.indexOf(
      "delete from argus_private.provider_commands;",
    );
    const triggerRecreate = migration.indexOf(
      "create trigger provider_command_attempts_immutable",
      attemptPurge,
    );
    const prepareFunction = migration.indexOf(
      "create or replace function argus_private.prepare_provider_order_command",
    );
    expect(pendingPurge).toBeGreaterThan(0);
    expect(pendingPurge).toBeLessThan(prepareFunction);
    expect(triggerDrop).toBeGreaterThan(0);
    expect(triggerDrop).toBeLessThan(attemptPurge);
    expect(attemptPurge).toBeLessThan(pendingPurge);
    expect(triggerRecreate).toBeGreaterThan(pendingPurge);
    expect(migration).toContain(
      "Remove them before the U7 idempotency boundary can return one as a winner",
    );
  });

  it("keeps attempts and projections immutable and order evidence monotonic", () => {
    expect(migration).toContain("provider_command_attempts_immutable");
    expect(migration).toContain("order_projection_generations_immutable");
    expect(migration).toContain("next_rank<prior_rank");
    expect(migration).toContain("p_filled_quantity<prior.filled_quantity");
    expect(migration).toContain("prior.source='detail' and p_source='list'");
    expect(migration).toContain("command.state='dispatching'");
    expect(migration).toContain(
      "command.egress_started_at<=now()-interval '30 seconds'",
    );
    expect(migration).toContain(
      "'applied','authoritative_not_applied','superseded_by_fill'",
    );
    expect(migration).toContain(
      "command_row.operation='cancel' and p_resolution='applied'",
    );
  });

  it("binds every per-order list row to the atomic owner list generation", () => {
    expect(migration).toContain("order_list_generation bigint");
    expect(migration).toContain(
      "check ((source='list')=(order_list_generation is not null))",
    );
    expect(repository).toContain(
      "select pg_advisory_xact_lock(hashtextextended($1,782743))",
    );
    const perOrder = repository.indexOf(
      "select argus_private.append_order_projection(",
    );
    const listGeneration = repository.indexOf(
      "insert into argus_brokerage.projection_generations(",
      perOrder,
    );
    expect(perOrder).toBeGreaterThan(0);
    expect(listGeneration).toBeGreaterThan(perOrder);
    expect(repository.slice(perOrder, listGeneration)).toContain(
      "listGeneration",
    );
  });

  it("requires current brokerage:read staff permission even for an AAL2 principal", async () => {
    const query = vi.fn(async (text: string) => ({
      rows: text.includes("has_live_staff_session")
        ? [{ live: true }]
        : text.includes("has_staff_permission")
        ? [{ allowed: false }]
        : [],
      rowCount: 0,
    }));
    const pool: DatabasePool = {
      connect: vi.fn(async () => ({
        query: query as DatabaseClient["query"],
        release: vi.fn(),
      })),
      end: vi.fn(async () => undefined),
    };
    const repository = createBrokerageOrderRepository({
      pool,
      claims: {
        userId: "018f3c2a-4b67-7a89-8abc-123456789001",
        sessionId: "018f3c2a-4b67-7a89-8abc-123456789002",
        aal: "aal2",
      },
    });

    await expect(repository.staffReconciliation(
      "018f3c2a-4b67-7a89-8abc-123456789003",
    )).rejects.toBeInstanceOf(StaffAuthorizationError);
    expect(query).toHaveBeenCalledWith(
      "select argus_private.has_staff_permission($1::text) as allowed",
      ["brokerage:read"],
    );
    expect(
      query.mock.calls.some(([text]) =>
        String(text).includes("from argus_private.provider_commands command")
      ),
    ).toBe(false);
  });
});
