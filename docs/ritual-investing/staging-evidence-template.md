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

## Starpath release evidence

Do not mark a row passed from repository fixtures alone. Hosted values must
identify the exact release revision while remaining free of member data and
secrets.

- RC1 capability schema/version and external release-control owner:
- Trusted environment, evaluated-at, expiry, capability version, and checksum:
- Beta branch order (Ritual → Starpath → Discover → Coven → You):
- Production-shaped branch order (Ritual → Starpath → You):
- Hidden Discover/Coven deep-link and protected-API denial proof:
- API revision and generated-client digest:
- Manifest id/version/hash and exact eight-node projection:
- Eight factual attestations and eight distinct compliance attestations:
- Adversarial no-advice copy validator results:
- RC3 legal policy hash, jurisdiction, effective/expiry window, and R20 trigger snapshot:
- First entry, wrong-answer retry, completion, distinct return, recall, correction, withdrawal/replacement, offline recovery, and completed-path proof:
- Export row counts and checksums for every Starpath member relation:
- Deletion-saga receipts and stale-command replay denial:
- Fixed-`as_of` `learning_retention_within_7d_v1` bounds, matured denominator, retained count, definition version, and checksum:
- Evidence that the metric emits no member rows, sets no target, and joins no financial/profile/astrology data:
- Local-browser wide/narrow, 200% text, reduced-motion, keyboard, and screen-reader evidence:
- iOS XcodeBuildMCP build/snapshot, VoiceOver, largest-text, and Reduce Motion evidence:
- Security Advisor and Performance Advisor result attributable to Starpath:
- Rollback capability version and continued read/export/purge proof:
- Re-enable capability/manifest identity and zero-dangling-reference proof:

Current repository status at 2026-08-30: the local generated-client, widget,
accessibility, integration-source, database, API, and local-browser evidence can
be attached to a candidate release. RC1 hosted capability evidence, RC2 hosted
publication evidence, RC3 legal approval, hosted advisors, iOS XcodeBuildMCP
evidence, rollback/re-enable evidence, and a matured retention baseline remain
required. Their absence is a production NO-GO, not a waived or inferred pass.

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
