# Strategy API validation receipt

Validated on 2026-09-08 UTC (2026-09-07 America/New_York). These are local
implementation checks, not a hosted deployment or evidence of profitability.

| Check | Result |
| --- | --- |
| `npm run typecheck` in `ritual-investing-api` | Passed. |
| `npx vitest run test/strategy-lab` with the disposable local database enabled | 2 files, 21 tests passed; final run at 21:08:38 ET, 7.99 seconds. |
| `npx --yes deno@2.5.6 check --config supabase/functions/strategy-api/deno.json supabase/functions/strategy-api/index.ts` from the repository root | Passed; pinned `deno.lock` retained. |
| `git diff --check` for feature-owned paths and `supabase/config.toml` | Passed. |

The 17 service/HTTP tests cover owner isolation, discovered simulated account
binding, exact-origin CORS, unsigned JWT rejection, absence of live/order
routes, one-use pairing, expired sessions, monotonically increasing poll
sequences, process fencing, ACK-gated leases, offline pause, concurrent mandate
revisions, idempotent mutation replay, immutable events, credential-field
rejection, explicit retire/ACK replacement, report association and validation,
and the supervisor's pause-only authority. A delayed provider does not hold the
owner transaction or override a newer user revision; repeated explanation
requests do not call the provider twice.

The four PostgreSQL tests run the actual feature migration and repository on
PostgreSQL 18. They extract the retained production trusted-context installer,
reader, identity helpers, and lifecycle lock functions from existing migrations.
Minimal Auth/member fixture tables supply their dependencies; this is not a
replay of every unrelated application migration. The tests cover:

- Forced owner/tenant/lifecycle RLS and rejection of forged legacy JWT GUCs.
- Member inability to install trusted identity, insert another owner's records,
  see device credential rows, or alter immutable configuration bodies.
- Concurrent redemption of one pairing token, with exactly one successful
  credential, and rejection after its originating Auth session is deleted.
- More than 24,000 archived events while status retains a quiet account's latest
  reconciliation; durable event-ID and sequence replay rejection; idempotent
  configuration lookup outside the runtime history window; concurrent control
  serialization; and device revocation.

The cluster was task-owned and isolated at
`C:\Users\Hj\Desktop\Leo Roar\release-work\strategy-api-postgres\data`, bound only
to `127.0.0.1:55443`. Each test run created and dropped its own randomly named
database. The opt-in fixture rejects any connection URL except
`postgresql://postgres@127.0.0.1:55443/postgres`. Its temporary local trust
authentication is for this disposable cluster only. The cluster was stopped
successfully after the final test; the local server log remains at
`C:\Users\Hj\Desktop\Leo Roar\release-work\strategy-api-postgres\server.log`.

To rerun while that disposable local cluster is running:

```powershell
$env:STRATEGY_TEST_DATABASE_URL='postgresql://postgres@127.0.0.1:55443/postgres'
npx vitest run test/strategy-lab
```

Without this opt-in variable the database suite skips, and the 17 service/HTTP
tests still run. Do not point these tests at the configured Supabase project.

No hosted migration, Edge deploy, OAuth settings change, broker login, real or
paper order, provider charge, or credible observed-market performance run was
performed by this API work. Research import fixtures are explicitly marked
`CONTRACT TEST ONLY`; they test the Python/Rust report shape and never represent
an actual strategy result. The server marks imported reports as user-supplied
metadata whose source artifact it has not independently reproduced.

Runtime routes, exact configuration, credentials, lease/retirement semantics,
and remaining hosted setup are documented in
`../../src/domains/strategy-lab/README.md`.
