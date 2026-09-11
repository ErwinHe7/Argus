# Broker onboarding implementation check

September 11, 2026. Scope: `#/brokers`, its feature-owned direct-link API/UI, and
the exact Google auth return allowlist. No backend, deployment or release file
was edited by the frontend subtask. Parent-owned concurrent changes are preserved.

Validation passed: four direct-link API unit tests, eight auth/strategy contract
tests (auth subtask), eleven broker browser groups, eleven auth browser groups,
scoped research-desk TypeScript, and the research-desk static build. Browser
receipts are `browser-checks.json` and `auth-browser-checks.json`. Requests were
intercepted; no real OAuth consent, broker order, installation or purchase ran.

The initial fixture run found a stopped local preview. After starting the
loopback preview, the complete suites passed. The receipts contain that final
run, not the earlier connection-refused checks.

One batched local visual inspection covered linked desktop, expanded IBKR mobile,
and unavailable-link mobile captures. The existing type hierarchy, square gold
and bordered actions, two-column desktop layout and single-column phone layout
remain intact. Native disclosure and wrapped commands keep advanced IBKR setup
readable without horizontal overflow. The parent review requested collapsing the
four OpenD steps so the IBKR choice appears sooner. That focused change uses the
same native disclosure, keeps purpose and software-stop limits visible, and was
followed by a rebuild and the complete broker browser fixture.

This is an ordinary extension of the existing design. PRODUCT.md and DESIGN.md
are unchanged. The scoped surface brief records the two connection paths and
their evidence boundaries. The frontend README now documents consent, server
configuration, freshness, disconnect semantics, local commands and verification.
The parent-coordinated independent finish/security review is complete; see
`finish-review.md`. This file records the implementing subtask's checks.

The independent reviewer identified a focus-event race during a pending
disconnect. The final implementation keeps that mutation exclusive through the
disconnect response and a follow-up status read. A deferred-disconnect fixture
dispatches repeated focus events, confirms no competing status request begins,
then verifies the final disconnected state. The complete broker suite passed
after that fix; scoped TypeScript was also rerun successfully.

Final built artifact SHA-256 values:

- `desk.js`: `B909609B85B5D98805CC396A369D4808D06327893DAC8F74105DDB574ECD0FA6`
- `desk.css`: `B2A9D64C5A62284277695494D27C112D2C14E0504E2A3DF0EAB950F6489CACC3`

After the scoped ship disposition, a documentation-only comparison confirmed
that the README, surface brief, receipt counts, masked-account terminology,
read-only/direct versus local-paper distinction and collapsed setup description
match the final source. No global design token or typography changed; the
existing DESIGN.md and PRODUCT.md remain unchanged. This documentation pass
did not open another browser or trigger visual edits.
