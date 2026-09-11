# Strategy workspace sign-in recovery — 2026-09-11

The deployed strategy service returned HTTP 503 for a real Google sign-in even
though the account had an active member record, open lifecycle and live Auth
session. The public catalog and database rate limiter remained healthy.

The retained JWT verifier returns `userId`, `sessionId`, `aal`, `issuedAt`, and
optional `authenticatedAt`. The strategy repository passed that whole object to
the strict database request-context schema, which accepts only the first three
fields. Its rejection happened before the member transaction opened. Earlier
strategy unit fixtures used only those three fields and did not expose the bug.

`ritual-investing-api/src/domains/strategy-lab/repository.ts` now explicitly
projects the already-verified `userId`, `sessionId`, and `aal` into the database
boundary. JWT verification, strict identity validation, live-session checks,
member/lifecycle checks, capability roles, RLS and origin policies are unchanged.

The new `test/strategy-lab/repository.test.ts` reproduces the previous 503 with
the complete verifier principal and confirms HTTP 200 after the fix. It also
confirms malformed session IDs are rejected before a connection is opened and
revoked sessions still yield HTTP 401 with transaction rollback.

Verification:

- Focused repository, strategy control-plane/origin and shared request-context
  tests: **49 passed, 2 existing hosted-DB integration cases skipped**.
- API TypeScript check: passed.
- Deno 2.5.6 strategy entrypoint check: passed.
- Only `strategy-api` was deployed to `katwbobjiyzipqlzarus` using CLI 2.117.0.
  Version **2**, artifact SHA-256
  `969a4b42f925f395c335ede03a0b33a07d40bc94cd71cfdfdf2d269cf951d2a5`.
- Hosted public catalog: **200**; unauthenticated status: **401**; exact Leo
  CORS retained. The release owner verified the same real Google session after
  deployment: Brokers now shows **Leo account records verified** and **No local
  computer paired**, with no strategy-service error. The separate moomoo link
  correctly remains **No moomoo account linked**. No device or mandate was created.
- Retained `api` version 4 and `worker` version 3 remain unchanged, with hashes
  `fe36456921d80d8ea11cc501bf28c9f2cff681d44dfdbfc91d91df749180f446` and
  `a3ed1dffe714d8288c9249d0cf4798bd8592c802c51f3dcf5884bbbbbc384611`.

No user was impersonated, no browser token was extracted, and no database schema,
membership, authorization setting, strategy configuration or mandate changed.
This repair does not establish broker consent or a paper execution lifecycle.
