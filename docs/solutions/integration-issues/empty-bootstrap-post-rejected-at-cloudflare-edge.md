---
title: "Empty Bootstrap POST Rejected at the Cloudflare Edge"
date: 2026-08-25
category: integration-issues
module: ritual-investing-api
problem_type: integration_issue
component: api_layer
symptoms:
  - "Authenticated Flutter startup remained blocked on the account-preparation error screen against the beta API."
  - "A fresh Auth0 login returned to the same failure, ruling out a restored stale session as the persistent cause."
  - "Live beta Worker tracing showed POST /v1/session/bootstrap returning 415 with Content-Length: 0 and no Content-Type."
root_cause: logic_error
resolution_type: code_fix
severity: high
related_components:
  - "frontend"
  - "authentication"
  - "observability"
tags:
  - "ritual-investing"
  - "session-bootstrap"
  - "cloudflare-workers"
  - "flutter"
  - "auth0"
  - "empty-post"
  - "content-length"
  - "media-type"
---

# Empty Bootstrap POST Rejected at the Cloudflare Edge

## Problem

The Ritual Investing Flutter app authenticated successfully enough to enter its member startup path, then stopped at **“Your account could not be prepared. Please try again.”** The entry coordinator deliberately collapses any bootstrap exception into that retryable destination (`ritual-investing-app/lib/core/bootstrap/entry_coordinator.dart:297-310`), while the generated API adapter turns a failed Dio bootstrap call into an application failure (`ritual-investing-app/lib/core/api/ritual_api.dart:28-39`). The generic screen therefore did not identify whether the fault was in Auth0, runtime configuration, the client transport, or server provisioning.

The failing operation was `POST /v1/session/bootstrap`. Its contract requires `write:self`, accepts no request body, and installs media validation before the no-body guard and route handler (`ritual-investing-api/src/domains/session/routes.ts:29-45`, `ritual-investing-api/src/domains/session/routes.ts:113-121`). The generated Dart client correctly emits a POST without data or a `Content-Type` (`ritual-investing-api-client/lib/generated/api/session_api.dart:42-61`).

The persistent failure was a transport-representation mismatch. At the Cloudflare edge, that bodyless POST arrived with no `Content-Type`, `Content-Length: 0`, and a non-null zero-length body stream. The API's media guard had treated every non-null stream as entity content requiring `application/json`, so it returned 415 before session provisioning ran. The ordinary local Hono happy-path test constructed a POST without an explicit body and did not exercise or assert the edge shape (`ritual-investing-api/test/domains/session.test.ts:26-38`).

## Symptoms

- Initial authenticated startup and Retry both displayed the same generic account-preparation failure because both repeated the same generated bootstrap operation (`ritual-investing-app/lib/core/bootstrap/entry_coordinator.dart:297-310`; `ritual-investing-app/lib/core/api/ritual_api.dart:28-39`).
- The app was launched against `https://api-beta.just-build-this.app`, which is the isolated beta API and Worker target (`docs/ritual-investing/beta-environment.md:7-10`, `docs/ritual-investing/beta-environment.md:99-114`). The app's production URL is only a default that a `RITUAL_API_BASE_URL` Dart define overrides (`ritual-investing-app/lib/core/config/runtime_config.dart:26-38`).
- A live tail of `ritual-investing-api-beta` showed `POST /v1/session/bootstrap` returning 415 with `Content-Length: 0` and no `Content-Type`. The captured Worker version was `c5611225-b0d2-4f34-8add-98a8fb039a4b`, and request ID `e8c5aeaa-1240-42ca-8c21-cc0562b1ef65` tied the UI Retry to that response. (session history)
- The media guard rejected the request before `rejectRequestBody` or the bootstrap handler could run (`ritual-investing-api/src/domains/session/routes.ts:113-121`).

## What Didn't Work

### Treating the screen as one Auth0 failure

An earlier beta trace had shown a 401, making scopes and token freshness reasonable first hypotheses. Bootstrap enforces `write:self` (`ritual-investing-api/src/domains/session/routes.ts:113-117`), and the member API defines four permissions (`docs/ritual-investing/auth0-setup.md:5-18`). The app was updated to request `read:self`, `write:self`, `simulate:self`, and `privacy:self` in addition to the OIDC/session scopes (`ritual-investing-app/lib/core/auth/auth0_session_repository.dart:60-73`). That resolved a real authorization prerequisite, but a subsequent beta request advanced to 415 and the user-visible screen stayed unchanged. (session history)

### Assuming a recovered token was still stale

Startup can reuse credentials from Auth0's credentials manager (`ritual-investing-app/lib/core/auth/auth0_session_repository.dart:81-88`). The simulator was logged out and authenticated through the hosted flow again; the same account-preparation failure returned. Logout and credential-clearing behavior improved recovery (`ritual-investing-app/lib/core/auth/auth0_session_repository.dart:90-98`; `ritual-investing-app/lib/core/auth/auth_controller.dart:97-104`), but a fresh token could not make the API media guard accept the request. (session history)

### Following a production health failure

The production health endpoint returned a 503 during diagnosis, but the Flutter process was configured for beta. Because `RuntimeConfig` takes the API base URL and Auth0 audience from separate compile-time values (`ritual-investing-app/lib/core/config/runtime_config.dart:26-38`), evidence from the default production host said nothing about the request actually failing in beta.

### Trusting the existing green local test

The original happy path issued a POST with no constructed body and passed (`ritual-investing-api/test/domains/session.test.ts:26-38`). Generated-client, Flutter, API, and local Worker checks likewise did not model the Cloudflare/Dart request shape. Green tests were baseline evidence, not proof that `Request.body === null` was portable across runtimes. (session history)

## Solution

### 1. Trace the environment the app actually targets

Confirm the effective `RITUAL_API_BASE_URL` and `AUTH0_AUDIENCE`, tail that Worker, and then trigger Retry. Retain the request ID, Worker version, status, `Content-Type`, and `Content-Length`; the UI copy alone cannot separate the failure layers.

### 2. Reproduce the edge-shaped empty request in a test

The regression constructs a request with an explicit zero-byte body and `Content-Length: 0`, but no `Content-Type`:

```ts
const response = await fixture.app.request(new Request(
  "https://api.ritual-investing.test/v1/session/bootstrap",
  {
    method: "POST",
    headers: {
      authorization: `Bearer ${memberToken(auth0Key)}`,
      "content-length": "0",
    },
    body: new Uint8Array(0),
  },
), undefined, testBindings());

expect(response.status).toBe(200);
expect(fixture.bootstrap).toHaveBeenCalledWith("auth0|member-1");
```

This is the current regression at `ritual-investing-api/test/domains/session.test.ts:40-56`. It failed with 415 before the middleware change and passed afterward. (session history)

### 3. Distinguish an explicit zero-length request from body content

Before the fix, the guard used raw stream presence as body presence:

```ts
if (contentType === undefined && context.req.raw.body !== null) {
  return errorResponse(context, 415, "unsupported_media_type", ...);
}
```

The fix special-cases the edge shape observed in the trace:

```ts
const contentType = context.req.header("content-type");
const hasBody = context.req.raw.body !== null
  && context.req.header("content-length") !== "0";
if (contentType === undefined && hasBody) {
  return errorResponse(context, 415, "unsupported_media_type", ...);
}
```

The implementation is at `ritual-investing-api/src/middleware/security-headers.ts:71-90`. It remains narrow: non-empty requests without a media type still receive 415, unsupported encodings and media types still receive 415, and the route's separate no-body guard still returns 422 if content reaches a bodyless operation (`ritual-investing-api/src/middleware/security-headers.ts:77-103`; `ritual-investing-api/test/domains/session.test.ts:58-121`).

### Verification and deployment status

The debugging session recorded these results after the change:

- The focused edge-shaped regression failed before the code change and passed afterward.
- The API suite passed 240 tests in 59 files, with 58 tests skipped in 8 files.
- The Workers suite passed 8 tests in 4 files.
- API typecheck passed.
- The Flutter suite passed 31 tests.
- Diff whitespace validation passed for the fix files.

These checks verify the local implementation, not the hosted beta service. No deployment was performed during the debugging session; recheck the current `ritual-investing-api-beta` version before treating that statement as present deployment status. Do not mark the user-visible incident live-resolved until the deployed beta tail shows bootstrap returning 200 and Retry or a fresh simulator login leaves the failure screen. (session history)

## Why This Works

HTTP emptiness and JavaScript stream nullability are not equivalent. A runtime may expose a `ReadableStream` even when the request explicitly contains zero bytes. The corrected predicate recognizes the exact `Content-Length: 0` edge representation before applying the JSON media-type rule (`ritual-investing-api/src/middleware/security-headers.ts:81-90`).

This aligns the server boundary with the operation contract. Bootstrap intentionally has no request body (`ritual-investing-api/src/domains/session/routes.ts:29-45`), and the generated client intentionally supplies no data (`ritual-investing-api-client/lib/generated/api/session_api.dart:42-61`). Adding a dummy JSON payload or hand-editing the generated client would violate the no-body contract and the repository rule that generated Dart code is not edited by hand (`docs/ritual-investing/api-consumer-guide.md:3-7`).

Defense in depth remains intact. Even if a request claims zero length inconsistently, `rejectRequestBody` still reads a non-null stream and rejects non-empty text (`ritual-investing-api/src/middleware/security-headers.ts:93-103`). The paired tests now prove that both valid empty representations reach subject-only bootstrap while real bodies continue to fail closed (`ritual-investing-api/test/domains/session.test.ts:26-56`, `ritual-investing-api/test/domains/session.test.ts:58-121`).

## Prevention

- Test bodyless POST endpoints with both common Fetch shapes: a null body and a non-null zero-length stream carrying `Content-Length: 0`.
- When a mobile build uses `--dart-define`, record the effective API base URL and audience before consulting health checks or logs from another environment.
- Trace the exact environment receiving the simulator request and retain correlation evidence. Generic failure copy is a routing outcome, not a root-cause diagnosis.
- Separate authorization from transport. Verify required route permissions against requested Auth0 scopes, use a fresh hosted login to rule out stale credentials, and then follow the new response status rather than assuming the original layer still fails.
- Preserve negative coverage whenever media handling changes: unsupported encodings, non-JSON media types, non-empty untyped bodies, forbidden bodies, and body-size limits must keep failing.
- After deployment, require both server evidence (beta bootstrap 200) and client evidence (Retry or fresh login reaches onboarding or the member shell) before closing the incident.

## Related Issues

- `docs/ritual-investing/beta-environment.md` — beta host, Worker, Auth0 audience, and Flutter build authority.
- `docs/ritual-investing/auth0-setup.md` — member permission and token-client contract.
- `docs/ritual-investing/api-consumer-guide.md` — OpenAPI and generated-client ownership rules.
- `docs/solutions/architecture-patterns/ritual-investing-app-current-intent-and-architecture.md` — historical scaffold context only; its “current” architecture inventory is now stale and needs a separate `ce-compound-refresh`.
- No related GitHub issues were found for `bootstrap 415 content-type` or `session bootstrap unsupported_media_type` on 2026-08-25.
