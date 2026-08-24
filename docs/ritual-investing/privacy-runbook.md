# Ritual Investing privacy runbook

## Export

An export is an idempotent, tenant-scoped, repeatable-read snapshot with a versioned manifest and allowlisted sections. It excludes authentication subjects, encrypted push tokens, idempotency/outbox/job internals, secrets, provider/scanner payloads, and every other tenant. The ZIP is encrypted at rest in R2. Status returns a short-lived, constant-time-verified, single-purpose link; responses are no-store.

Deletion revokes exports in every phase. A pre-delete or stale export worker may create no tenant row, R2 object, notification, projection, or new link. Verify the artifact checksum, manifest version, snapshot coherence, expiry, one-time policy, and tenant isolation in staging.

## Verified deletion

1. Validate the member confirmation and immediately revoke sessions, devices, notifications, export requests, links, and queued mutable work.
2. Create the tombstone and advance purge generation.
3. Append a deletion-deny journal entry in retained R2 keyed by tombstone ID and purge generation.
4. Persist and checksum-confirm that journal entry before destructive purge.
5. Purge tenant rows and R2 objects through the narrow privacy role; verify zero orphans and terminal receipts.
6. Retain only the minimized tombstone, stable receipt, and independent deny journal required by policy.

Retries are idempotent. If journal confirmation, R2 deletion, receipt persistence, or verification fails, remain denied and retry; never mark complete early. Monitor purge age against the 30-day critical fixture and the product contract deadline.

## Restore protection

Restored Neon never receives traffic until the retained deletion-deny journal is replayed and checksum-confirmed for the expected restore epoch. Prove that stale backups cannot recreate deleted tenants and that stale jobs are fenced. Missing or corrupt journal data is a cutover blocker, not a reason to waive denial. Follow the [Neon restore drill](neon-runbook.md).
