# Supabase recovery coverage

This document is the versioned recovery-coverage input to every protected
promotion manifest. Its checksum is approved before a fence or hosted mutation.
The coverage order is: **database**, **Auth**, **Storage**, **queues**, **Cron**,
**roles**, **Vault**, **Edge secrets**, and **functions**.

Every managed-resource class is classified as **restorable**,
**reconstructable**, or **disposable**. Recovery remains **fix-forward-only**
unless the exact backup and passed restore drill named in the manifest authorize
a managed restore.

| Resource | Classification | Recovery evidence and stop condition |
|---|---|---|
| Database schema and Argus rows | Restorable | Supabase backup ID plus restore-drill ID; migration ledger and normalized target fingerprint must match before traffic admission. Never repair or rewrite migration history. |
| Auth identities and sessions | Restorable | Managed backup/restore coverage and isolated synthetic identity inventory; revoke synthetic sessions and prove no run namespace remains. Do not recreate real identities from fixtures. |
| Storage buckets, objects, and receipts | Restorable | Bucket configuration is migration-owned; object recovery uses the approved managed backup and immutable receipt/checksum evidence. Namespace residue or receipt mismatch is a no-go. |
| PGMQ queues and leases | Reconstructable | Queue definitions are migration-owned. Reconcile in-flight work from durable outbox/job evidence; stale `dispatching` provider checkpoints are re-enqueued for lookup only after 30 seconds. Never replay an ambiguous provider effect. |
| Cron schedules and run history | Reconstructable | Schedules are migration-owned and exact-name checked. Recreate only after queues and fences are verified; historical run rows are diagnostic. |
| Custom roles, memberships, settings, grants, and RLS | Reconstructable | Forward-only migrations and target-manifest ACL fingerprints are authoritative. Runtime logins receive separately rotated passwords out of band. |
| Vault secret names | Reconstructable | Inventory names only. Values are restored or rotated through the protected operator channel and never enter logs, artifacts, or the manifest. |
| Edge secrets | Reconstructable | Protected secret-name inventory plus independent credential rotation. Bind `ARGUS_BUILD_REVISION` immediately before exact-revision deployment. |
| Edge Functions | Reconstructable | Deploy callback, worker, waitlist, then API from the manifest Git revision; prove both mixed-version states and final revision handshake. |
| Isolated synthetic test resources | Disposable | Run-unique identities, objects, queues, schedules, roles, rows, and configuration must clean up to zero and match the before inventory. Any mismatch leaves all fences enabled. |

## Required recovery evidence

The recovery owner records the backup identifier, restore-drill identifier,
recovery approval, scope, capture time, source fingerprint, restored target
fingerprint, and reconciliation results. Release and security approvers confirm
that credentials were not copied into evidence and that provider/order fences
remain independently blocked. Missing, stale, partial, or mismatched evidence
invalidates the promotion manifest.
