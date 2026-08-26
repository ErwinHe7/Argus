# Ritual Investing Neon runbook

## Roles and connections

Use separate pooled connections for runtime, scheduler, media worker, moderation worker, privacy purge, and audit reconciliation. Runtime must not inherit or invoke purge, moderation, scheduler, or audit-checkpoint privileges. The `ritual_audit_reconciler` role can record and read immutable aggregate checkpoints but cannot inspect raw staff audit rows. Owner credentials are migration-only. Tests must activate the same restricted roles and forced RLS used in production.

Never log a connection URL. Telemetry records only the `neon` dependency name, availability, latency, outcome, and request ID.

## Migration protocol

Every release follows expand → backfill → verify → switch → contract:

1. **Expand:** additive nullable columns/tables/functions and N-1-compatible indexes.
2. **Backfill:** resumable, bounded batches with observable watermarks.
3. **Verify:** checksums, row counts, RLS/role tests, append-only invariants, projection monotonicity, and N-1/N Worker probes.
4. **Switch:** canary the N Worker and observe both client versions.
5. **Contract:** only migrations marked `ritual:contract-after-client-drain`, after the compatibility window and old-traffic drain evidence.

Run `npm run db:migrate:check`, apply to an empty database, apply N-1 then N, simulate an interrupted N transaction, repeat the migration, and run the complete PostgreSQL suite. On failure, leave traffic on the compatible version and forward-fix. Do not edit an applied migration or attempt a destructive reverse migration.

## Restore drill

1. Isolate the restored Neon branch from traffic.
2. Replay and checksum-confirm retained R2 deletion-deny journal entries before cutover.
3. Run tombstone, tenant-absence, orphan, generation, RLS, immutable-ledger, and consumer-watermark verification.
4. Rotate database credentials and advance the expected restore epoch.
5. Enable a read-only canary, then normal traffic only after `restoreCutoverReady` passes.

A stale backup must never resurrect a deleted tenant or allow pre-reset/pre-delete queued work. If replay or checksum fails, keep the restore isolated and escalate; do not disable the cutover gate.

Monitor `neon.available`, `database.rls_denials`, migration locks, pool saturation, slow queries, and restricted audit parity.
