# Privacy export retention

The minute scheduler claims expired `privacy_export_artifacts` in bounded batches and emits idempotent `privacy.export.retention.requested` events. The retention consumer deletes the exact recorded R2 key and marks the artifact `deleted` in the same consumer-receipt transaction. Re-delivery is safe: a missing or already-deleted artifact is a stale no-op.

Configure the `ritual-privacy-exports` bucket with an R2 lifecycle rule that deletes objects under `privacy-exports/v1/` after eight days. The database expiry is at most seven days, so the lifecycle rule is a one-day orphan backstop for the failure window in which R2 accepted an upload but the database transaction did not commit. This lifecycle rule is required in staging and production and must be checked during release readiness; it is not represented by Wrangler configuration.

Alert when either condition is true:

- an artifact remains `published` or `revoked` more than 15 minutes after `expires_at`;
- an `outbox_dispatch_failures` row or dead-letter event names a privacy retention topic.

Recovery is to restore the queue publisher/consumer, leave the lifecycle rule enabled, and replay the failed outbox delivery. Never extend object lifetime by copying an expired export to a new key.
