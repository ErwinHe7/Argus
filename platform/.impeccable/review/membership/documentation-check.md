# Membership documentation check

September 11, 2026. Ordinary extension of the incumbent research-desk design.
The [finish review](finish-review.md) gives a scoped **ship** disposition with no
material findings. This handoff compared source and receipts; it did not open a
browser, run another visual pass, or change implementation.

## Existing-system comparison

Compared [DESIGN.md](../../../features/research-desk/DESIGN.md),
[PRODUCT.md](../../../features/research-desk/PRODUCT.md), the
[surface brief](../../../features/research-desk/.impeccable/surfaces/features-research-desk-membership-membership-tsx.md),
`Membership.tsx`, `membership.css`, `api.ts`, and shared `desk.css`.

- Palette and surfaces match: inherited aubergine, plum panel/rules, ink and muted text, candle-gold actions, and the existing error red. The account panel has a one-pixel rule and no shadow or new corner treatment.
- Typography stays in DeskInter/Inter. The 40px, weight-750 title becomes 32px below 700px; body copy is 13–15px, and price/check timestamps use tabular numerals. These are scoped roles within the existing hierarchy.
- Actions reuse square gold, bordered, and text buttons, shared hover/focus treatments, and a 44px minimum height. Shared reduced-motion, selection, and scrollbar rules remain active.
- The 1180px container uses equal desktop columns with a 50px gap, reduced to 28px at 900px. Below 700px the plan precedes the account in one column, with 18px gutters and stacked actions. Long account names and footer links wrap.
- Existing Lion and official 216×48 Google assets are retained. No new shipping raster or visual token was introduced.

Per the ordinary-extension rule, DESIGN.md and PRODUCT.md remain unchanged and
no design sidecar is created or rewritten. Existing documentation drift is
reported only: the earlier navigation paragraph omits Radar while the dated
Radar section includes it; dated extension headings sit outside the canonical
eight-section structure; no `design.json` exists in the inspected root or scoped
`.impeccable` directories. The finish review's request for membership documentation
is satisfied by this scoped comparison rather than rewriting the incumbent system.

## Contract and evidence

The UI describes one $99.99 USD/month subscription, automatic renewal, cancellation,
the checkout total, and separate broker setup. Public research, browser records,
and the Paddle `/pricing` destination remain available.

`api.ts` validates a strict Whop status response and requires a current,
non-anonymous matching account before sending its bearer token to the fixed
billing service. Status uses `GET /status`; checkout uses `POST /checkout` only
after the explicit action. Responses expire after five minutes, unavailable/error
states cannot claim active membership, and checkout accepts only an exact HTTPS
Whop checkout path. Account changes discard private state and pending results.
The Google callback completes PKCE before returning to the allowlisted membership
route. Orders remains available for management and recovery. Browser return
parameters cannot grant entitlement, connect a broker, or authorize trading.

The [membership receipt](browser-checks.json) records 6/6 fixture groups and no page
errors. The [final auth receipt](auth-browser-checks.json) records 10/10 groups and
no page errors, including membership return and hostile return-path rejection.
The earlier account-auth receipt is historical. The implementing agent reports
6/6 membership API checks, 8/8 strategy/auth contract checks, and 18/18 combined
Paddle/Whop contract checks passed; scoped TypeScript and research-desk build passed.
Relevant sources are `features/research-desk/membership/api.test.ts`,
`features/strategy-lab/tests/contracts.test.ts`, `scripts/paddle-catalog-contract.test.mjs`,
and `scripts/whop-checkout-contract.test.mjs`.

These browser tests intercept external calls and inject account/billing states.
They establish local presentation and client contract behavior, including archive
failure, stale/error recovery, explicit checkout, account isolation, retained
records, and absence of embedded frames. They do not establish hosted Google login,
a real payment, webhook delivery, server entitlement enforcement, or broker operation.

## Local fixture handoff

From the platform root, build the public research-desk assets and start the loopback
preview; open `http://127.0.0.1:3231/#/membership`:

```powershell
node --import tsx scripts/research-desk-build.mjs
node features/research-desk/membership/preview.cjs
```

With the preview running, execute the mocked browser fixture in another terminal:

```powershell
node features/research-desk/membership/browser.cjs
```

The fixture requires Playwright (or `LEO_PLAYWRIGHT_MODULE` pointing to an existing
installation). It installs the external-request mocks and writes the receipt plus
1440×1000 desktop and 390×844 mobile full-page captures. The preview server only
serves built files. No deployment or backend change is part of this handoff.
