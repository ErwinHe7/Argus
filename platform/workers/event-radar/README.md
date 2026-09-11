# Hosted event radar

`leo-event-radar` publishes a bounded, read-only official-calendar artifact. The
20-minute Cloudflare Cron runs without an LLM, a browser, or the owner's computer.
It does not require a VPS. Cloudflare resource usage still follows the account's
Workers and SQLite Durable Object plan.

The collector retrieves exactly two fixed official URLs: the Federal Reserve
FOMC calendar and the BLS `bls.ics` iCalendar linked by its official schedule. Each response is limited to
1 MiB and twelve seconds; redirects and non-success responses are rejected.
Neither caller-supplied URLs nor brokerage credentials enter the collector.

Manual observations in `features/research-desk/data/event-radar.json` seed the
first publication. They retain `manual_verified` mode and their original
verification timestamps. Successful automatic polling adds separately labeled
sources. A blocked BLS request does not turn manual BLS observations into an
automatic connection. FOMC date ranges do not become invented decision hours.
When the same meeting is already manually verified with a precise decision
hour, the matching automatic date-only observation does not duplicate it or
renew the manual timestamp. The parser accepts BLS's explicit `US-Eastern`
timezone label and retained history, then limits output to the published window.
Source versions that disappear on a successful complete parse are removed;
failed requests retain last-good values, source hashes and verification times.

The SQLite Durable Object serializes refreshes using a persisted lease and an
atomic publication. Public `GET /radar` and `HEAD /radar` only read that saved
artifact. There is no public refresh, upload, order, execution, or AI endpoint.
The main website proxies its fixed
`/app/research-desk/data/event-radar.json` path through the `EVENT_RADAR` service
binding, stripping caller credentials and query parameters. Missing bindings
return an explicit 503 instead of silently serving a static calendar as current.

The artifact schema validates UTC source chronology, Eastern event times,
coverage counts, source deadlines, and evidence references. Hypothesis records
are empty in the hosted release. The separate Python append-only journal is a
local research tool; a local hash chain cannot establish a trusted public
publication time, predictive performance or profitability.

## Development and deployment

Run from `Argus/platform`:

```powershell
node --import tsx --test workers/event-radar/feed.test.ts features/research-desk/worker-routing.test.cjs
.\node_modules\.bin\tsc.cmd --noEmit --project workers/event-radar/tsconfig.json
.\node_modules\.bin\wrangler.cmd deploy --config workers/event-radar/wrangler.jsonc --dry-run
.\node_modules\.bin\wrangler.cmd deploy --config workers/event-radar/wrangler.jsonc --keep-vars
```

Compatibility date `2026-09-04` matches the installed workerd version tested for
this release. A `2026-09-10` local integration attempt failed because that binary
supports dates only through September 4; no application test failure was hidden.
Regenerate `worker-configuration.d.ts` with Wrangler after configuration changes.

Prepare the web overlay from the last verified static release, passing
`--event-radar` to `scripts/strategy-stage.py`. Do not build or deploy the dirty
Next.js project wholesale. The stager verifies all frozen backend files and
unrelated assets against the previous release. The exact Worker name `leo`,
existing routes, Paddle billing and all existing service bindings remain intact.

## Operation and recovery

Read the public feed and inspect `sources[].lastAttemptAt`, `retrievedAt`,
`reviewAfter`, `state` and `error` independently of `generatedAt`. An advancing
artifact generation time never proves all sources are fresh. Cron runs every
20 minutes; wait for an actual scheduled run before claiming a production
source connection is verified. BLS may return 403 from a particular network;
the source status exposes that failure. Repeated structural parse failures mean
the official page changed, requiring a parser update and regression tests.
Initial manual seed records initialize the Durable Object. On a later scheduled
refresh, the deployed bundle may add a new manually verified source or replace
that source's events only when its verification time advances. Older or
same-timestamp seed edits cannot overwrite saved evidence. Automatic sources
cannot enter through that path; manual observations retain their manual label.
To add or re-verify issuer dates, review the official source, export and validate
the updated seed artifact with the Python CLI, run the tests, redeploy this
Worker, then inspect the following Cron publication. No public upload endpoint
is exposed. Existing manual observations become stale after their original
deadline. The hosted collector automates Fed and BLS schedules only.

DO eviction/restart preserves the saved artifact and source-version receipts.
Refresh crashes leave a lease that expires after one minute; a later Cron can
recover. The Worker never closes positions or manages money.

The local stock-shortlist publisher and the native strategy research runner are
separate processes. As audited September 10, their last heartbeats were September
8, and the research runner recorded a `MemoryError`. Their retained stock data
ended September 4. A VPS can keep these longer-running processes online, but
cannot supply missing current quotes, historical entitlements, or validate a
strategy by itself. Use the existing `connectors/research-runner/deployment/`
source package and setup guide when a real SSH host is available. No VPS has
been purchased or installed by this change.

Official implementation references:
[Cron Triggers](https://developers.cloudflare.com/workers/configuration/cron-triggers/),
[SQLite Durable Object storage](https://developers.cloudflare.com/durable-objects/api/sqlite-storage-api/),
[FOMC calendar](https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm),
[BLS calendar](https://www.bls.gov/schedule/).
