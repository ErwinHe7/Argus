# Ritual Investing member data inventory

Status date: 2026-08-25

This inventory covers the member app and its API. The experience is a
provider-free Demo: it does not collect bank credentials, brokerage accounts,
payment-card data, real holdings, or real transaction data.

## Guided-onboarding data

| Data | Purpose | Required | Server persistence and member control |
| --- | --- | --- | --- |
| Investing experience | Choose explanation depth | Yes | Stored in the tenant investor profile; editable in You → Investing profile |
| Goal, horizon, and risk comfort | Shape Demo defaults and presentation | Yes | Stored in the tenant investor profile; editable in You → Investing profile |
| Contribution rhythm | Shape Demo plan defaults | Yes | Stored in the tenant investor profile; editable in You → Investing profile |
| Ritual language and familiarity | Choose practical, balanced, or mystical presentation | Yes, including `prefer_not_to_say` | Stored in tenant preferences; editable in You → Ritual preferences |
| Ritual interests | Choose relevant ritual and research surfaces | At least one | Stored in tenant preferences; editable in You → Ritual preferences |
| Astrology choice | Record whether personalized astrology is enabled | Yes; accepting personalization is optional | Stored as a versioned astrology consent decision |
| Birth date | Derive a coarse Demo astrology profile | Only after astrology consent | Date only; no birth time or place. Stored in the tenant astrology profile and removed when personalization is turned off |
| Terms, privacy, and Demo disclosure | Record the reviewed policy versions | Required to finish onboarding | Stored as append-only versioned consent receipts |

These answers affect presentation and defaults only. They do not authorize a
financial command, alter tenant boundaries, or bypass a confirmation. Server
state, version checks, idempotency keys, and explicit confirmation remain the
authority for every simulated mutation.

## Before and after account creation

Before Auth0 completes, the questionnaire is an installation-bound encrypted
device draft. It expires after seven days, is deleted when expired, corrupted,
or restored on a different installation, and is not synchronized or included in
device backup. Android backup and device transfer exclude the protected storage
namespace; iOS uses this-device-only, non-synchronizing Keychain access.

After authentication, the API atomically validates the questionnaire, active
policy versions, astrology choice, and consent decisions. The device draft is
cleared only after the server reports onboarding `complete`. A completed account
does not silently absorb a later anonymous draft.

Do not place questionnaire answers, birth dates, Auth0 subjects, bearer tokens,
or consent payloads in analytics, logs, crash breadcrumbs, screenshots, or CI
artifacts. Operational evidence may use sanitized request IDs and aggregate
pass/fail results only.

## Consent, retention, export, and deletion

- General astrology remains available when personalized astrology is declined.
  A birth date is rejected unless the matching astrology policy version is
  accepted. Turning personalization off removes the astrology profile and
  records the new consent decision.
- The active account retains investor and ritual preferences until the member
  edits them or requests account deletion. Consent receipts remain versioned so
  the accepted or declined policy can be demonstrated.
- A protected, recently authenticated export request is processor-gated. An
  accepted export snapshot and archive expire after seven days; each generated
  download link expires after five minutes and is one-time use.
- Account deletion is irreversible after acceptance. It immediately revokes
  member access, is generation-fenced against stale jobs, and exposes a
  `purge_by` deadline no later than 30 days after the effective time. Deletion
  remains denied/retrying until its retained deletion journal and purge are
  verified.
- Export and deletion return `503` before mutation unless every required Queue,
  database, bucket, schedule, and capability switch is ready. See
  [Member release gates](member-release-gates.md) and the
  [privacy runbook](privacy-runbook.md).

The export implementation uses an explicit collection allowlist. Before beta
promotion, compare that allowlist with this inventory and verify that every
persisted onboarding field intended for member access appears in a staged
archive; repository tests alone are not deployed-data proof.
