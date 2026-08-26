# Beta member bootstrap debug — 2026-08-25

Status: migration 0012 and the Worker repair are deployed and verified on beta.
The restored member completed setup and reached the member shell. One separate
post-login search-route defect remains documented below.

## User-visible failure

The iOS Simulator build succeeds and launches, but a restored Auth0 session
stops on `Your account could not be prepared. Please try again.` Retrying does
not advance to the member shell.

The build used the `ritual-investing-app` XcodeBuildMCP profile, the beta API at
`https://api-beta.just-build-this.app`, and the beta Auth0 native client. The
failure reproduces after a clean install and launch on the iPhone 17 simulator.

## Causal chain

1. The app sends an empty `POST /v1/session/bootstrap` for the restored member.
2. The currently deployed beta Worker returns `200`; the earlier Cloudflare
   `415 unsupported_media_type` failure is no longer the live response.
3. Deployed Worker version `100eed84-9d1b-45c8-bfd1-0fac6c5a8234` predates
   commit `ea406bb094b6e053db9fbb2396000f95df23125d`, which expanded the bootstrap
   response.
4. The deployed response therefore omits required generated-client keys:
   `astrology_profile`, `investor_profile`, and `reset_generation`.
5. The generated Dart client throws `CheckedFromJsonException` while creating
   `SessionBootstrap`. `RitualApi` maps that exception to `LoadFailure`, and
   `EntryCoordinator` renders the generic recovery screen.

This is a deployed-server/generated-client contract skew, not an Xcode build or
Flutter rendering failure.

## Additional deployment blockers found

Promoting the current source without preparation would introduce new failures:

- The clean source rejects Cloudflare's edge-shaped empty POST when it has
  `content-length: 0` and no media type, returning `415`.
- The clean Auth0 claim schema rejects the supported API-plus-userinfo audience
  pair after JWT verification, returning `401`.
- `wrangler.beta.jsonc` contains a placeholder member client allowlist. Current
  source enforces that allowlist, so bootstrap would return `403`.
- Current session code calls
  `ritual_private.bootstrap_member_account_v2(text)`, which is introduced by
  `0012_member_experience.sql`. The beta database has only migrations
  `0001`–`0011`, and the v2 function is absent.
- The database migration ledger does not match clean Git source for migrations
  `0002`, `0003`, and `0006`–`0011`. The existing workspace edits for those
  eight files match the beta ledger checksums exactly; the standard migrator
  will refuse to apply `0012` until that source/ledger reconciliation is
  intentionally carried forward.

The beta admin Auth0 client and Cloudflare Access variables also remain
placeholders. That setup is explicitly unfinished in the beta handoff; admin
routes must remain fail-closed and are outside this member-bootstrap repair.

## Prepared source fixes

The isolated branch `codex/ritual-beta-bootstrap-fix` contains:

- empty requests with `content-length: 0` are treated as bodyless;
- Auth0 accepts exactly the configured API audience alone or the bounded
  API-plus-userinfo pair in either order;
- beta allowlists the native member client used by the beta Flutter build;
- a regression test pins the beta member/client boundary.

Verification completed:

- focused tests: 18 passed;
- API suite: 255 passed, 62 skipped;
- TypeScript typecheck: passed;
- OpenAPI generation check: passed;
- reviewed migration parse/check: 12 migrations validated;
- Wrangler beta dry-run: passed, 1.64 MiB upload / 292.92 KiB gzip.

The OpenAPI drift generator could not run because its configured Docker daemon
was unavailable. The checked-in OpenAPI generation check passed, and this
candidate does not change the API schema.

## Beta migration result

Migration `0012_member_experience.sql` was applied to Neon beta branch
`br-rapid-queen-ayjfyawl` through the Neon Postgres plugin on 2026-08-25. It ran
as one database transaction together with its migration-ledger write.

Post-migration verification confirmed:

- the ledger checksum is
  `41aeee399fde79c2a4a4bfdf372a2e1330573be6840eab65313f02a34a7f91b9`;
- `ritual_private.bootstrap_member_account_v2(text)` exists;
- `ritual_private.finalize_member_onboarding(text,text,text,jsonb)` exists;
- `onboarding_finalization_commands` exists;
- the existing onboarding row has non-null schema/cohort backfill values;
- the database owner cannot `SET ROLE` to or inherit
  `ritual_function_owner`, and that role has no `CREATE` privilege on
  `ritual_private`.

The first plugin attempt was rejected before execution because a multi-command
batch cannot be sent as one prepared statement. A verification query confirmed
that it left no schema or ledger changes. The reviewed file was then split at
PostgreSQL statement boundaries and submitted through the plugin's transaction
endpoint successfully.

## Worker promotion and Xcode retest

The isolated candidate was deployed to `ritual-investing-api-beta` as Worker
version `35af9aad-7274-4315-8f8d-cc9655a86cf6`, with build revision
`3e7bb5e-c9344f22d0d1`. `GET /health` returned `200` and reported that revision.

XcodeBuildMCP then relaunched the existing beta-configured app on the iPhone 17
simulator. The restored session produced these successful live requests on the
new Worker version:

- `POST /v1/session/bootstrap` — `200`;
- `POST /v1/session/onboarding/finalize` — `200`;
- all 21 distinct member routes observed while navigating — `200`;
- 27 tailed Worker events with no exception payload and no non-2xx response.

The app advanced from the former generic failure screen to `Finish your setup`,
accepted the reviewed local draft, and reached the member shell. Verified
surfaces included daily Ritual reveal/history, Ritual briefings, Discover and an
asset detail, Founders' Coven, You, and the demo portfolio. The iOS runtime logs
contained no app-attributable error or exception; the only match was the known
iOS 26.5 Simulator duplicate accessibility-bundle warning.

## Residual search-route defect

`Search the Asset Codex` is visible after the member feature scope initializes,
but selecting it opens a GoRouter `Page Not Found` screen for
`/discover/search`.

The causal mismatch is lifecycle timing:

1. `buildDiscoverBranch` conditionally registers the `search` child route only
   when `container.optionalSearchController` is non-null while the router is
   constructed.
2. The member feature scope initializes later and supplies the search
   controller.
3. `DailyRitualScreen` and `DiscoverScreen` then render an enabled search action
   because they read the now-non-null controller during widget build.
4. The action pushes `/discover/search`, but the already-created route table
   never contained that route.

Recommended fix: register `/discover/search` unconditionally, redirect to
`/discover` when the controller is unavailable, and resolve the controller at
builder time after the redirect. Add a router regression test that constructs
the router before feature-scope initialization, initializes the scope, and then
opens the search location successfully.

## Safe repair order

1. Intentionally include the eight existing migration checksum-reconciliation
   edits; do not deploy from the dirty workspace wholesale.
2. ~~Apply pending migration `0012_member_experience.sql` to beta.~~ Completed
   through the Neon Postgres plugin.
3. ~~Verify the beta ledger records `0012` and
   `to_regprocedure('ritual_private.bootstrap_member_account_v2(text)')` is
   present.~~ Completed.
4. ~~Set an exact `BUILD_REVISION` and promote the isolated Worker candidate to
   `ritual-investing-api-beta`.~~ Completed.
5. ~~Tail `/v1/session/bootstrap`, then relaunch with XcodeBuildMCP and verify
   bootstrap, onboarding/member-shell navigation, and console output.~~
   Completed; the residual search-route defect is independent of bootstrap.

Never promote the current dirty workspace directly: it contains unrelated
in-progress changes and cannot provide a trustworthy source revision.
