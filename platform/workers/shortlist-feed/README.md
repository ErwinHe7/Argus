# Shortlist publication feed

This isolated Worker transports the Python publisher's validated, descriptive
shortlist and operational status. It does not rank assets, calculate financial
values, call an LLM, contact a broker, download data, or accept raw history.

`POST /publication` requires `Authorization: Bearer ...` matching the secret
binding `LEO_SHORTLIST_PUBLISH_TOKEN`. `GET /publication` is public and returns
the latest validated `astra-shortlist-publication.v1` envelope, or HTTP 503 when
none is available or stored data fails validation. Both responses disable
caching. No CORS headers are added; the website's existing Worker proxies GET
through a service binding. Unknown routes, query strings, and methods fail closed.

The shared schema is
`features/research-desk/shortlist/publication.ts`. Bodies are bounded to 512 KiB
while streaming and after canonical serialization. The schema permits only
declared coverage metadata, rejects execution/forecast authority and nonzero
LLM counts, and rejects future publication metadata at ingestion. An initial
status without a shortlist is permitted; a published shortlist cannot later be
erased by uploading a null artifact. Dated observations and old heartbeats stay
dated; the website determines whether to show an interrupted-update label.

The single `public-feed` SQLite Durable Object is the explicitly shared
coordination boundary. Its synchronous transaction compares the current record,
checks immutable revision identities, and writes the new envelope atomically.
It rejects older publisher heartbeats, source retrieval times, observation dates,
and publication times. Existing symbols' source and price-observation timestamps
cannot regress even when the global cutoff advances or a symbol changes between
the stock and fund groups. A changed envelope at the same heartbeat is rejected.
Retrying the identical latest JSON value is idempotent, including differences
in JSON whitespace or object-key order. Old revision identities remain retained
even after a newer revision becomes current.

The supplied `artifactSha256` is the authenticated publisher's assertion about
its original artifact bytes. The Worker does **not** claim to independently
reconstruct those bytes across Python/JavaScript JSON serializers. It separately
hashes the parsed, canonical JSON value to prevent an existing revision from
being associated with changed shortlist data, input hash, artifact hash, or
original publication time. Storage retains the latest envelope and compact
per-revision identities, without a second copy of every historical shortlist.

Configuration declares `leo-shortlist-feed`, `SHORTLIST_FEED`, and a `v1` SQLite
Durable Object migration. It declares the secret's name, never its value.
Compatibility date `2026-09-04` matches the installed workerd runtime used for
the tests. No resources or secrets are provisioned by the test suite.

From the platform directory:

```powershell
node node_modules/wrangler/bin/wrangler.js types --config workers/shortlist-feed/wrangler.jsonc --env-interface ShortlistFeedEnv workers/shortlist-feed/worker-configuration.d.ts
node node_modules/typescript/bin/tsc --project workers/shortlist-feed/tsconfig.json
node --import tsx --test workers/shortlist-feed/feed.test.ts
node node_modules/wrangler/bin/wrangler.js deploy --dry-run --config workers/shortlist-feed/wrangler.jsonc
```

Tests use the repository's existing esbuild, tsx, and Miniflare/workerd. They
exercise the actual SQLite Durable Object, concurrent writes, process restart,
revision immutability, invalid data and authorization, corrupted storage, and a
trap that rejects every outbound network request.

The storage implementation follows Cloudflare's
[SQLite transaction API](https://developers.cloudflare.com/durable-objects/api/sqlite-storage-api/#transactions)
and token comparisons use its
[timing-safe Web Crypto comparison](https://developers.cloudflare.com/workers/runtime-apis/web-crypto/#timingsafeequal).
