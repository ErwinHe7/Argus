import {
  bigint,
  boolean,
  date,
  foreignKey,
  integer,
  jsonb,
  numeric,
  pgTable,
  text,
  timestamp,
  unique,
  uuid,
} from "drizzle-orm/pg-core";

import { assets } from "./editorial";
import { tenants } from "./identity";

export const demoSeedVersions = pgTable("demo_seed_versions", {
  id: uuid("id").defaultRandom().primaryKey(), version: integer("version").notNull().unique(), fixtureHash: text("fixture_hash").notNull().unique(),
  publishedAt: timestamp("published_at", { withTimezone: true }).notNull(), isCurrent: boolean("is_current").notNull().default(false),
});
export const tenantDemoStates = pgTable("tenant_demo_states", {
  tenantId: uuid("tenant_id").primaryKey().references(() => tenants.id, { onDelete: "cascade" }), seedVersionId: uuid("seed_version_id").notNull().references(() => demoSeedVersions.id),
  resetGeneration: integer("reset_generation").notNull().default(1), version: integer("version").notNull().default(1), resetAt: timestamp("reset_at", { withTimezone: true }).notNull().defaultNow(),
});
export const demoPortfolios = pgTable("demo_portfolios", {
  id: uuid("id").defaultRandom().primaryKey(), tenantId: uuid("tenant_id").notNull().references(() => tenants.id, { onDelete: "cascade" }), name: text("name").notNull(),
  currency: text("currency").notNull(), status: text("status").notNull(), version: integer("version").notNull().default(1),
}, (t) => [unique("demo_portfolios_tenant_id_id_unique").on(t.tenantId, t.id)]);
export const portfolioTargetAllocations = pgTable("portfolio_target_allocations", {
  tenantId: uuid("tenant_id").notNull().references(() => tenants.id, { onDelete: "cascade" }), portfolioId: uuid("portfolio_id").notNull(),
  assetId: uuid("asset_id").notNull().references(() => assets.id), targetBps: integer("target_bps").notNull(), version: integer("version").notNull().default(1),
}, (t) => [
  foreignKey({ name: "portfolio_target_allocations_tenant_portfolio_fk", columns: [t.tenantId, t.portfolioId], foreignColumns: [demoPortfolios.tenantId, demoPortfolios.id] }).onDelete("cascade"),
  unique("portfolio_target_allocations_unique").on(t.tenantId, t.portfolioId, t.assetId),
]);
export const idempotencyRecords = pgTable("idempotency_records", {
  id: uuid("id").defaultRandom().primaryKey(), tenantId: uuid("tenant_id").notNull().references(() => tenants.id, { onDelete: "cascade" }), resetGeneration: integer("reset_generation").notNull(),
  operation: text("operation").notNull(), key: text("idempotency_key").notNull(), requestHash: text("request_hash").notNull(), state: text("state").notNull().default("processing"),
  // The reviewed SQL adds the mutual, deferrable (tenant_id, command_id)
  // foreign key after both tables exist; declaring that cycle here defeats
  // TypeScript inference in Drizzle 0.45.
  claimOwner: text("claim_owner"), leaseUntil: timestamp("lease_until", { withTimezone: true }), commandId: uuid("command_id"), responseHash: text("response_hash"), terminalResponse: jsonb("terminal_response"),
  expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
}, (t) => [
  unique("idempotency_records_generation_key_unique").on(t.tenantId, t.resetGeneration, t.operation, t.key),
  unique("idempotency_records_tenant_id_id_unique").on(t.tenantId, t.id),
]);
export const simulationCommands = pgTable("simulation_commands", {
  id: uuid("id").defaultRandom().primaryKey(), tenantId: uuid("tenant_id").notNull().references(() => tenants.id, { onDelete: "cascade" }), resetGeneration: integer("reset_generation").notNull(),
  portfolioId: uuid("portfolio_id").notNull(), idempotencyId: uuid("idempotency_id").notNull().unique(), commandType: text("command_type").notNull(),
  status: text("status").notNull(), rejectionCode: text("rejection_code"), committedAt: timestamp("committed_at", { withTimezone: true }),
}, (t) => [
  foreignKey({ name: "simulation_commands_tenant_portfolio_fk", columns: [t.tenantId, t.portfolioId], foreignColumns: [demoPortfolios.tenantId, demoPortfolios.id] }),
  foreignKey({ name: "simulation_commands_tenant_idempotency_fk", columns: [t.tenantId, t.idempotencyId], foreignColumns: [idempotencyRecords.tenantId, idempotencyRecords.id] }),
  unique("simulation_commands_tenant_id_id_unique").on(t.tenantId, t.id),
]);
export const demoFundingSources = pgTable("demo_funding_sources", {
  id: uuid("id").defaultRandom().primaryKey(), tenantId: uuid("tenant_id").notNull().references(() => tenants.id, { onDelete: "cascade" }), fixtureKey: text("fixture_key").notNull(),
  displayLabel: text("display_label").notNull(), fictionalLast4: text("fictional_last4").notNull(), status: text("status").notNull(),
}, (t) => [unique("demo_funding_sources_tenant_fixture_unique").on(t.tenantId, t.fixtureKey)]);
export const simulatedOrders = pgTable("simulated_orders", {
  id: uuid("id").defaultRandom().primaryKey(), tenantId: uuid("tenant_id").notNull().references(() => tenants.id, { onDelete: "cascade" }), portfolioId: uuid("portfolio_id").notNull(),
  commandId: uuid("command_id").notNull(), assetId: uuid("asset_id").notNull().references(() => assets.id), side: text("side").notNull(), orderType: text("order_type").notNull(),
  requestedNotionalMinor: bigint("requested_notional_minor", { mode: "bigint" }), requestedQuantity: numeric("requested_quantity", { precision: 30, scale: 12 }), status: text("status").notNull(), quoteSnapshotId: uuid("quote_snapshot_id"),
}, (t) => [
  foreignKey({ name: "simulated_orders_tenant_portfolio_fk", columns: [t.tenantId, t.portfolioId], foreignColumns: [demoPortfolios.tenantId, demoPortfolios.id] }),
  foreignKey({ name: "simulated_orders_tenant_command_fk", columns: [t.tenantId, t.commandId], foreignColumns: [simulationCommands.tenantId, simulationCommands.id] }),
  unique("simulated_orders_tenant_command_unique").on(t.tenantId, t.commandId),
  unique("simulated_orders_tenant_id_id_unique").on(t.tenantId, t.id),
]);
export const simulatedOrderFills = pgTable("simulated_order_fills", {
  id: uuid("id").defaultRandom().primaryKey(), tenantId: uuid("tenant_id").notNull().references(() => tenants.id, { onDelete: "cascade" }), orderId: uuid("order_id").notNull(),
  quantity: numeric("quantity", { precision: 30, scale: 12 }).notNull(), priceMinor: bigint("price_minor", { mode: "bigint" }).notNull(), filledAt: timestamp("filled_at", { withTimezone: true }).notNull(),
}, (t) => [
  foreignKey({ name: "simulated_order_fills_tenant_order_fk", columns: [t.tenantId, t.orderId], foreignColumns: [simulatedOrders.tenantId, simulatedOrders.id] }),
  unique("simulated_order_fills_tenant_order_unique").on(t.tenantId, t.orderId),
  unique("simulated_order_fills_tenant_id_id_unique").on(t.tenantId, t.id),
]);
export const ledgerTransactions = pgTable("ledger_transactions", {
  id: uuid("id").defaultRandom().primaryKey(), tenantId: uuid("tenant_id").notNull().references(() => tenants.id, { onDelete: "cascade" }), resetGeneration: integer("reset_generation").notNull(),
  portfolioId: uuid("portfolio_id").notNull(), commandId: uuid("command_id").notNull(), entryType: text("entry_type").notNull(),
  effectiveAt: timestamp("effective_at", { withTimezone: true }).notNull(), descriptionCode: text("description_code").notNull(),
}, (t) => [
  foreignKey({ name: "ledger_transactions_tenant_portfolio_fk", columns: [t.tenantId, t.portfolioId], foreignColumns: [demoPortfolios.tenantId, demoPortfolios.id] }),
  foreignKey({ name: "ledger_transactions_tenant_command_fk", columns: [t.tenantId, t.commandId], foreignColumns: [simulationCommands.tenantId, simulationCommands.id] }),
  unique("ledger_transactions_tenant_command_unique").on(t.tenantId, t.commandId),
  unique("ledger_transactions_tenant_id_id_unique").on(t.tenantId, t.id),
]);
export const cashLedgerEntries = pgTable("cash_ledger_entries", {
  id: uuid("id").defaultRandom().primaryKey(), tenantId: uuid("tenant_id").notNull().references(() => tenants.id, { onDelete: "cascade" }), transactionId: uuid("transaction_id").notNull(),
  currency: text("currency").notNull(), amountMinor: bigint("amount_minor", { mode: "bigint" }).notNull(),
}, (t) => [
  foreignKey({ name: "cash_ledger_entries_tenant_transaction_fk", columns: [t.tenantId, t.transactionId], foreignColumns: [ledgerTransactions.tenantId, ledgerTransactions.id] }).onDelete("cascade"),
  unique("cash_ledger_entries_tenant_id_id_unique").on(t.tenantId, t.id),
]);
export const positionLedgerEntries = pgTable("position_ledger_entries", {
  id: uuid("id").defaultRandom().primaryKey(), tenantId: uuid("tenant_id").notNull().references(() => tenants.id, { onDelete: "cascade" }), transactionId: uuid("transaction_id").notNull(),
  assetId: uuid("asset_id").notNull().references(() => assets.id), quantity: numeric("quantity", { precision: 30, scale: 12 }).notNull(), unitPriceMinor: bigint("unit_price_minor", { mode: "bigint" }).notNull(),
}, (t) => [
  foreignKey({ name: "position_ledger_entries_tenant_transaction_fk", columns: [t.tenantId, t.transactionId], foreignColumns: [ledgerTransactions.tenantId, ledgerTransactions.id] }).onDelete("cascade"),
  unique("position_ledger_entries_tenant_id_id_unique").on(t.tenantId, t.id),
]);
export const portfolioPositions = pgTable("portfolio_positions", {
  tenantId: uuid("tenant_id").notNull().references(() => tenants.id, { onDelete: "cascade" }), portfolioId: uuid("portfolio_id").notNull(), assetId: uuid("asset_id").notNull().references(() => assets.id),
  quantity: numeric("quantity", { precision: 30, scale: 12 }).notNull(), costBasisMinor: bigint("cost_basis_minor", { mode: "bigint" }).notNull(), asOfTransactionId: uuid("as_of_transaction_id").notNull(),
}, (t) => [
  foreignKey({ name: "portfolio_positions_tenant_portfolio_fk", columns: [t.tenantId, t.portfolioId], foreignColumns: [demoPortfolios.tenantId, demoPortfolios.id] }).onDelete("cascade"),
  foreignKey({ name: "portfolio_positions_tenant_transaction_fk", columns: [t.tenantId, t.asOfTransactionId], foreignColumns: [ledgerTransactions.tenantId, ledgerTransactions.id] }),
  unique("portfolio_positions_tenant_portfolio_asset_unique").on(t.tenantId, t.portfolioId, t.assetId),
]);
export const portfolioBalanceSnapshots = pgTable("portfolio_balance_snapshots", {
  id: uuid("id").defaultRandom().primaryKey(), tenantId: uuid("tenant_id").notNull().references(() => tenants.id, { onDelete: "cascade" }), portfolioId: uuid("portfolio_id").notNull(),
  asOfTransactionId: uuid("as_of_transaction_id").notNull(), projectionGeneration: integer("projection_generation").notNull(), asOf: timestamp("as_of", { withTimezone: true }).notNull(),
  cashMinor: bigint("cash_minor", { mode: "bigint" }).notNull(), marketValueMinor: bigint("market_value_minor", { mode: "bigint" }).notNull(), sourceHash: text("source_hash").notNull(),
}, (t) => [
  foreignKey({ name: "portfolio_balance_snapshots_tenant_portfolio_fk", columns: [t.tenantId, t.portfolioId], foreignColumns: [demoPortfolios.tenantId, demoPortfolios.id] }),
  foreignKey({ name: "portfolio_balance_snapshots_tenant_transaction_fk", columns: [t.tenantId, t.asOfTransactionId], foreignColumns: [ledgerTransactions.tenantId, ledgerTransactions.id] }),
  unique("portfolio_balance_snapshots_tenant_generation_unique").on(t.tenantId, t.portfolioId, t.projectionGeneration),
  unique("portfolio_balance_snapshots_tenant_id_id_unique").on(t.tenantId, t.id),
]);
export const recurringPlans = pgTable("recurring_plans", {
  id: uuid("id").defaultRandom().primaryKey(), tenantId: uuid("tenant_id").notNull().references(() => tenants.id, { onDelete: "cascade" }), portfolioId: uuid("portfolio_id").notNull(),
  planType: text("plan_type").notNull(), amountMinor: bigint("amount_minor", { mode: "bigint" }).notNull(), frequency: text("frequency").notNull(), nextRunAt: timestamp("next_run_at", { withTimezone: true }).notNull(), status: text("status").notNull(), version: integer("version").notNull().default(1),
}, (t) => [
  foreignKey({ name: "recurring_plans_tenant_portfolio_fk", columns: [t.tenantId, t.portfolioId], foreignColumns: [demoPortfolios.tenantId, demoPortfolios.id] }),
  unique("recurring_plans_tenant_id_id_unique").on(t.tenantId, t.id),
]);
export const recurringPlanAllocations = pgTable("recurring_plan_allocations", {
  tenantId: uuid("tenant_id").notNull().references(() => tenants.id, { onDelete: "cascade" }), planId: uuid("plan_id").notNull(), assetId: uuid("asset_id").notNull().references(() => assets.id), weightBps: integer("weight_bps").notNull(),
}, (t) => [
  foreignKey({ name: "recurring_plan_allocations_tenant_plan_fk", columns: [t.tenantId, t.planId], foreignColumns: [recurringPlans.tenantId, recurringPlans.id] }).onDelete("cascade"),
  unique("recurring_plan_allocations_unique").on(t.tenantId, t.planId, t.assetId),
]);
export const recurringPlanRuns = pgTable("recurring_plan_runs", {
  id: uuid("id").defaultRandom().primaryKey(), tenantId: uuid("tenant_id").notNull().references(() => tenants.id, { onDelete: "cascade" }), resetGeneration: integer("reset_generation").notNull(), planId: uuid("plan_id").notNull(),
  scheduledFor: timestamp("scheduled_for", { withTimezone: true }).notNull(), commandId: uuid("command_id"), status: text("status").notNull(), attemptedAt: timestamp("attempted_at", { withTimezone: true }),
}, (t) => [
  foreignKey({ name: "recurring_plan_runs_tenant_plan_fk", columns: [t.tenantId, t.planId], foreignColumns: [recurringPlans.tenantId, recurringPlans.id] }),
  foreignKey({ name: "recurring_plan_runs_tenant_command_fk", columns: [t.tenantId, t.commandId], foreignColumns: [simulationCommands.tenantId, simulationCommands.id] }),
  unique("recurring_plan_runs_generation_schedule_unique").on(t.tenantId, t.planId, t.resetGeneration, t.scheduledFor),
  unique("recurring_plan_runs_tenant_id_id_unique").on(t.tenantId, t.id),
]);
export const rebalancePreviews = pgTable("rebalance_previews", {
  id: uuid("id").defaultRandom().primaryKey(), tenantId: uuid("tenant_id").notNull().references(() => tenants.id, { onDelete: "cascade" }), resetGeneration: integer("reset_generation").notNull(), portfolioId: uuid("portfolio_id").notNull(),
  inputVersion: integer("input_version").notNull(), expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(), status: text("status").notNull(),
}, (t) => [
  foreignKey({ name: "rebalance_previews_tenant_portfolio_fk", columns: [t.tenantId, t.portfolioId], foreignColumns: [demoPortfolios.tenantId, demoPortfolios.id] }),
  unique("rebalance_previews_tenant_id_id_unique").on(t.tenantId, t.id),
]);
export const rebalancePreviewTrades = pgTable("rebalance_preview_trades", {
  id: uuid("id").defaultRandom().primaryKey(), tenantId: uuid("tenant_id").notNull().references(() => tenants.id, { onDelete: "cascade" }), previewId: uuid("preview_id").notNull(),
  assetId: uuid("asset_id").notNull().references(() => assets.id), side: text("side").notNull(), quantity: numeric("quantity", { precision: 30, scale: 12 }).notNull(), notionalMinor: bigint("notional_minor", { mode: "bigint" }).notNull(),
}, (t) => [
  foreignKey({ name: "rebalance_preview_trades_tenant_preview_fk", columns: [t.tenantId, t.previewId], foreignColumns: [rebalancePreviews.tenantId, rebalancePreviews.id] }).onDelete("cascade"),
  unique("rebalance_preview_trades_tenant_preview_asset_unique").on(t.tenantId, t.previewId, t.assetId),
  unique("rebalance_preview_trades_tenant_id_id_unique").on(t.tenantId, t.id),
]);
