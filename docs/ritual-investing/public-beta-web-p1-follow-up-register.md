# Public beta web P1 follow-up register

Status date: 2026-08-30

This is the durable follow-up register for the invite-first member web beta at
`just-build-this.app`. Every open document-review concern is P1, including the
fresh-context email callback concern previously reported at a higher priority.
P1 means the work is important follow-up; it is not a claim that the current
feature exists or an authorization to enable it.

## Settled beta boundary

- Preserve the current landing artifact, standalone Demo, and member product
  behavior. The member Worker may replace the landing at the apex, but the
  unchanged landing remains the tested rollback and Pages-hosted recovery
  surface. The web release adds a delivery target, not a redesign.
- Cloudflare may deliver the compiled Flutter member artifact as static assets.
  It receives no Auth, application-data, database, provider, or stateful backend
  authority.
- Member identity uses the dedicated beta Supabase project. Application data
  uses the versioned beta Argus API and private beta schemas; the browser does
  not query application tables through the Supabase Data API.
- Entry is invitation-only. Self-service signup remains disabled.
- Brokerage reads and mutations, provider connection, funding, privacy export,
  privacy deletion, and every other unfinished sensitive capability remain
  visibly unavailable and fail closed. Unavailable controls issue no provider,
  privacy, or financial request.
- Synthetic state stays in the visibly labeled, network-isolated standalone
  Demo. The member app may link to it only through an explicit Demo handoff and
  never imports its fixtures as fallback data.

The statement that no sensitive capability is functional in this beta is a
scope decision, not a determination that identity, onboarding, or stored member
data is non-sensitive. Existing authentication, privacy, redaction, and data
handling controls remain in force.

## P1 follow-ups

| ID | P1 follow-up | Required resolution before the affected capability or rollout step |
| --- | --- | --- |
| P1-01 | Fresh-context email callbacks | Define and test token-hash verification for signup confirmation, invitation, and recovery links opened in a fresh tab, browser, or profile; make every email flow use the exact configured Argus HTTPS callback, and reserve PKCE verifier exchange for flows initiated in the same tab. Until resolved, do not claim fresh-context confirmation, invitation, or recovery support. |
| P1-02 | Cross-tab logout and account changes | Clear the receiving tab's Supabase session plus all account-scoped in-memory caches when it receives a logout or account-change signal. Do not put bearer or refresh tokens in the signal payload. |
| P1-03 | Path routing | Enable and verify Flutter path URL strategy before router initialization so direct and refreshed apex links resolve without hash routing or an unexpected landing fallback. |
| P1-04 | Edge-streamed privacy exports | Assign the authenticated Edge streaming endpoint, generated API contract, and client ownership. Exports remain unavailable until the full server and artifact lifecycle is implemented and evidenced. |
| P1-05 | Generated service-worker removal | If the release build generates an empty service-worker file, prove it is empty and unreferenced before excluding it from the deploy manifest. Do not silently ship a stale caching authority. |
| P1-06 | CSP-safe Flutter build | Compile and smoke-test the release artifact in Flutter's supported CSP-safe mode; keep the enforced policy free of `unsafe-eval` and retain an explicit restrictive `form-action`. |
| P1-07 | Zero-percent Cloudflare deployment | Create the member artifact deployment with landing at 100% and member at 0% before domain-context smoke tests or any apex promotion. Record the exact version and rollback target. |
| P1-08 | Invitation abuse proof | Record enumeration-safe responses, retry and resend limits, abuse thresholds, alerting, custom SMTP behavior, and a named support owner. Open signup stays disabled until this proof and its separate approval exist. |
| P1-09 | Email-auth interaction states | Specify submission, pending delivery, expiry, throttling, resend, recovery, failure, completion, focus, announcement, and retry states for invitation and recovery screens. |
| P1-10 | Dependency sequencing | Allow beta API/data-boundary preparation and web platform compilation to proceed independently where safe, while requiring this authority set before capability composition and launch. |
| P1-11 | Open-signup deferral | Add an acceptance check that self-service signup and generic account creation remain disabled. CAPTCHA/Turnstile activation and public-signup coverage are deferred until open signup is separately approved. |
| P1-12 | Server-enforced step-up | Select a server-verifiable recent-auth or AAL2 mechanism before privacy export, deletion, provider disconnect, or another sensitive action can become functional. The current beta keeps these actions unavailable. |
| P1-13 | Retention policy | Approve category-level periods, deletion exceptions, backup behavior, and owners for identity, onboarding, support, logs, exports, deletion evidence, and waitlist data. No unfinished data-producing capability may be enabled ahead of its policy. |
| P1-14 | Route capability matrix | Map every top-level member route to `beta-backed`, `unavailable`, or `standalone Demo handoff`; keep all financial and privacy capability routes visibly unavailable until separately gated, remove their live controller composition from the browser build, and prove unavailable controls issue no brokerage, privacy, or step-up request. |
| P1-15 | Signed-out apex experience | Define the signed-out orientation, invitation/waitlist route, beta explanation, legal/support access, and optional explicit Demo handoff without changing the current landing/Demo behavior. |
| P1-16 | Supabase remediation overlap | Decide whether the existing Supabase architecture-remediation plan is a prerequisite or is superseded for each overlapping migration, grant, RLS, hosted-check, and evidence item. Avoid duplicate authority or migrations. |
| P1-17 | Legal, support, and feedback placement | Define reachable signed-out and authenticated navigation placement plus keyboard, semantic, and interaction evidence for privacy, terms, support, and feedback. |
| P1-18 | HTTPS and HSTS | Verify HTTP-to-HTTPS enforcement and approve the final HSTS policy before increasing public exposure. |
| P1-19 | Browser storage enumeration | Inventory every current browser datum and record its storage mechanism, account scope, expiry, clearing event, backup/synchronization behavior, and sensitive-data prohibition. |
| P1-20 | Privacy-safe telemetry sink | Select the transport, sink, retention, redaction rules, route-template cardinality, access owner, and incident workflow before relying on beta telemetry. |
| P1-21 | Post-native checkpoint | At a named checkpoint after native release, decide whether to graduate, retain, restrict, or retire the web beta and record data, domain, and support consequences. |
| P1-22 | Bounded password-auth requests | Apply and test an explicit timeout for Supabase password sign-in and signup, translate timeout failures into a retryable member-auth state, and ensure the credential form always re-enables submission after a partial Auth outage. |

## Closure rule

A P1 item closes only when its decision and dated evidence are linked here and
the affected acceptance gate passes. Closing one item does not open a sensitive
capability: capability enablement remains a separate, explicit product and
release decision. When the route capability matrix changes, its generated
release manifest must keep unavailable routes fail-closed and must preserve the
independent Demo boundary.
