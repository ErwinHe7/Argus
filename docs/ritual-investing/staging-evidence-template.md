# Ritual Investing hosted-development evidence template

Use one copy per release in the approved evidence system. Never commit secrets,
member data, provider payloads, database URLs, signed links, or tokens.

## Release identity

- Source revision:
- OpenAPI digest / generated client version:
- Supabase project ref and sanitized database target class (direct/pooler):
- Migration range and checksums:
- Operator / reviewer / UTC window:

## Automated acceptance

- Exact deployment-target guard:
- Clean local reset, pgTAP, and repeat-reset proof:
- Hosted post-push `supabase test db --linked` proof:
- API/type/security and Edge Function checks/tests:
- OpenAPI/generated-client drift:
- Flutter member/admin/Demo checks and native builds:
- Static-only Cloudflare Pages inventory:
- Hosted Auth health and exact Edge build revision:
- `webull-supabase-v1` schema contract:
- Exact PGMQ queue inventory and retry/DLQ evidence:
- Private Storage buckets, size limits, export/delete lifecycle:
- Runtime/worker statement timeouts and active kill switches:

## Hosted scenarios

- Supabase member sign-in, refresh, step-up, logout, and account isolation:
- Supabase staff AAL2, live permission, revocation, and audit proof:
- Queue/Cron lease, receipt, retry, dead-letter, and crash-resume proof:
- Privacy export, credential/object destruction, Auth-last deletion, and resume:
- Legacy Auth0/Neon/Cloudflare API/Queue/R2 negative probes and revocation record:

## Webull gate

- Partner protocol/version/signing decision:
- Sanitized sandbox connection/read/recovery evidence:
- Sanitized sandbox manual-order and ambiguous-response evidence:
- `provider_egress` remains enabled (blocked) if either item is absent:
- `order_mutations` remains enabled (blocked) if either item is absent:

Do not substitute mocks for hosted Webull sandbox evidence. The current partner
protocol decision is unresolved, so the launch decision remains NO-GO.

## Promotion decision

- Active kill switches:
- Queue observation window and stop conditions:
- Roll-forward/restore owner:
- Legacy authority revocation owner:
- Two-person approval:
