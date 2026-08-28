# Webull operations runbook

Webull access is fail-closed. The repository contains reviewed public-contract
fixtures and sandbox-safe adapters, but the partner-confirmed OAuth, read, and
order protocol gate is unresolved. No operator may disable `provider_egress` or
`order_mutations` in any hosted environment until the production launch record
contains the exact approved protocol version, partner confirmation reference,
sandbox evidence, credential owner, callback inventory, and rollback approver.

Token refresh, projection refresh, and reconciliation are bounded recovery
operations. They may refresh credentials, read already-existing provider state,
or reconcile an already-submitted command. They must never initiate, recreate,
or retry an order placement, modification, or cancellation. Ambiguous refresh
or order outcomes go to reauthorization or manual review.

To pause Webull immediately, enable `provider_egress` and `order_mutations` in
`argus_private.kill_switches`, then verify worker claims fail closed. Disconnect
and account-deletion flows fence callbacks and leases before destroying
credentials and mappings. Provider revocation is best effort and never delays
credential destruction or Auth-last deletion.

Key rotation uses versioned overlap: install the next encryption/HMAC key,
verify new writes and reads, drain old-key work, then retire the old key. Never
reuse an expired refresh token after a timeout that may have rotated it.
