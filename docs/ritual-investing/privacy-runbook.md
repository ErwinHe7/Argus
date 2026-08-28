# Ritual Investing privacy operations

Privacy export and deletion cover Argus-owned data in Supabase Postgres and
private Supabase Storage. They never claim to delete a Webull brokerage account,
cancel a provider order, or erase records Webull is required to retain.

## Export

An export is an idempotent owner-scoped snapshot with a versioned allowlist. It
excludes authentication credentials, Webull credentials/mappings, idempotency
and worker internals, raw provider payloads, secrets, and other members. The
artifact is stored in the private `privacy-exports` bucket with a bounded size,
expiry, and one-use download flow. Verify the manifest, checksum, snapshot
coherence, expiry, replay denial, and owner isolation in the local pgTAP/worker
suite and hosted evidence run.

## Deletion order

1. Commit the deletion epoch/tombstone and immediately fence callbacks, leases,
   queued work, refresh, reconciliation, and every Webull provider operation.
2. Cryptographically destroy encrypted Webull credentials and private provider
   mappings. Provider revocation is best-effort evidence and never blocks local
   destruction.
3. Enumerate private Storage paths through the narrow deletion functions and
   delete each object idempotently, recording only bounded receipts/path hashes.
4. Purge Argus application rows and verify the tombstone epoch prevents stale
   workers, callbacks, or transactions from recreating them.
5. Delete the Supabase Auth identity last, only after credentials, mappings,
   objects, and application data have terminal receipts.

Every step is crash-resumable and owner/epoch fenced. A stale worker may not
create a row, Storage object, notification, projection, callback mapping, or
download link. If any step fails, remain denied and retry through the bounded
deletion saga; never mark deletion complete early.

## Evidence and recovery

Record tombstone and receipt identifiers only; never store raw member content,
object paths, bearer tokens, Webull credentials, or provider bodies in logs.
Exercise failures before and after Storage deletion, credential destruction,
Auth deletion, and receipt persistence. Recovery must converge without dual
authority or restoration from a legacy Neon/R2 path.
