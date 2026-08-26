# Ritual Investing staging evidence template

Use one copy per release. Store it in the approved evidence system; never commit environment secrets or production data.

## Release identity

- Source revision:
- OpenAPI digest / generated client version:
- Migration range and checksums:
- Mobile N-1 / N versions:
- Operator / reviewer / UTC window:

## External binding proof

Record pass/fail, timestamp, sanitized request or job ID, and artifact link for Auth0 member/admin audience separation, Cloudflare Access, each rate-limit class, public cache miss/hit/304/purge, Queue retry/receipt/DLQ, scheduled delivery, R2 quarantine/public/export lifecycle, restricted Neon roles/RLS, deletion-deny journal restore cutover, push provider allowlisted response, and admin static hostname.

Do not record bearer/access assertions, raw subjects, database URLs, signed links, push tokens, provider/scanner bodies, member content, or tenant identifiers.

## Required gates

- Locked install, source guard, typecheck, API/Worker/security/full PostgreSQL tests:
- Empty/repeat/N-1→N/interrupted migration proof:
- OpenAPI/generated Dart drift and mobile compatibility proof:
- Dart client, mobile analyze/test/goldens, Android, no-codesign iOS:
- Admin analyze/test/web build/real-browser workflow:
- Wrangler dry run:
- Capacity report: cache miss/hit, authenticated read, command p95 and zero-error threshold:
- Alert fixture drill and immutable audit parity:
- Privacy export/deletion/restore drill:

## Promotion decision

- Canary percentage and observation window:
- Queue initial/final concurrency:
- Active kill switches:
- N-1 traffic/adoption drain evidence:
- Roll-forward owner and stop conditions:
- Two-person approval:
