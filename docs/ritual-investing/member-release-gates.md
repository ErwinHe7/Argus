# Ritual Investing member release gates

Status date: 2026-08-25

This checklist separates repository proof from environment proof. Passing CI
does not claim a deployed beta, a real-device Auth0 callback, an applied database
migration, or an enabled background processor.

## Required repository proof

Before producing a beta build:

1. Run API typecheck, domain/security/Worker tests, OpenAPI generation and drift
   checks, and generated Dart client analysis/tests.
2. Run the full Flutter suite, the generated-Dio aggregate integration target,
   the Android debug build, and the iOS no-codesign build.
3. Run `scripts/test-check-member-provider-boundaries.sh` and
   `scripts/check-member-provider-boundaries.sh`. New literal production hosts,
   runtime fetch entry points, dependencies, or Queue effects must be explicitly
   reviewed; dynamic API and Auth0 URLs remain governed by typed HTTPS runtime
   configuration and deployment review.
4. Preserve accessibility proof at 2× text in both themes, reduced-motion and
   accessible-navigation behavior, 44-point iOS and 48-dp Android tap targets,
   labeled controls, focused confirmation routes, and platform back behavior.
5. Preserve the approved ritual-first visual hierarchy and keep `Demo` plus
   `No real money moves` adjacent to every financial or membership action.

CI uses a run-scoped `RITUAL_MEMBER_TEST_ID` with loopback generated-Dio
services. This proves serialization, routing, and account isolation in the test
harness. It does not exercise Auth0's hosted browser or create a production
tenant.

## Beta capability matrix

Every capability starts fail-closed. Change one switch at a time, record the
operator, revision, sanitized evidence, and rollback condition, then observe
receipts, backlog, DLQ, generation fences, and tenant isolation before enabling
the next capability.

| Capability | Required proof before enablement | Fail-closed state / rollback |
| --- | --- | --- |
| Scheduled briefings, recurring Demo plans, and export retention | Target environment has the reviewed cron set, scheduler/runtime database roles, Queue/DLQ, and direct handler plus scheduled-event smoke proof | `KILL_SWITCH_SCHEDULED=on`; remove/pause beta crons if they were added |
| Queue processing | Isolated Queue/DLQ bindings, durable receipts, retry/DLQ proof, and backlog alerting | `KILL_SWITCH_QUEUE=on` |
| In-app notification writing | Queue and database proof plus valid member deep links; delivery remains independently disabled | `KILL_SWITCH_NOTIFICATION_WRITER=on` |
| External notification delivery | An approved push provider, encrypted token binding, provider allowlist, retry/rate-limit proof, consent, and real-device validation | `KILL_SWITCH_NOTIFICATION_DELIVERY=on`; no push service binding |
| Privacy export | Queue/DLQ, scheduler/runtime roles, export bucket, expiry/one-time-link, and staged archive-inventory proof | `KILL_SWITCH_EXPORTS=on`; requests return `503` before mutation |
| Privacy purge | Queue/DLQ, scheduler/runtime/privacy roles, export/quarantine/deletion-journal buckets, restore-journal replay, deadline monitoring, and purge verification | `KILL_SWITCH_PURGE=on`; requests return `503` before mutation |
| Media scan/process | Approved scanner and processor service bindings, quarantine/public buckets, validation, and rollback proof | `KILL_SWITCH_MEDIA=on`; no provider service bindings |

In-app-only notifications require neither a push provider binding nor
`PUSH_TOKEN_ENCRYPTION_KEY`. Keep notification delivery disabled and do not
collect push tokens in that mode.

The current beta account has no cron capacity reserved for Ritual. Until the
reviewed schedules are actually installed and observed, scheduled briefings,
recurring execution, privacy retention, export, and purge are unavailable even
if their repository handlers pass. Seeded/current recaps may keep the UI
deterministic, but they are not evidence of a running schedule.

## Identity and native gates

Hosted Auth0 is a separate real-device gate on both iOS and Android. Record
signup, returning sign-in, correct member `azp`, cancellation, process recovery,
recent authentication, logout, verified HTTPS callback/app link, and the
custom-scheme rollback. Simulator/emulator integration tests cannot satisfy this
gate.

The API must be configured with the exact member application client ID in
`AUTH0_MEMBER_CLIENT_IDS`; admin IDs are never valid substitutes. Follow the
[Auth0 migration and rollback procedure](auth0-setup.md) before changing client
IDs or callback modes.

## Rollback order

1. Turn on the narrow affected capability switch; use the Queue-wide or
   scheduled switch only when the scope is broader.
2. Stop new schedules/producers and leave queued effects fenced. Do not bypass
   authentication, authorization, recent-auth, idempotency, or deletion gates.
3. Roll the mobile build back to the last verified callback mode/client, keeping
   both client IDs allowlisted only for the documented compatibility window.
4. Roll the Worker revision back without pointing beta at production resources.
   Database rollback is forward-only: deploy a reviewed compensating migration
   or restore only through the deletion-journal replay gate.
5. Re-enable at low concurrency only after the original failure condition and
   rollback condition are both verified.
