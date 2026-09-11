# Account sign-in finish review

Date: 2026-09-11

**Disposition: SHIP for the reviewed login UI and shared identity changes.** No concrete functional, accessibility, or visual release blockers found. No product changes were made during this review.

## Scope and evidence

- Read `Welcome.tsx`, `welcome.css`, `Identity.tsx`, `auth.ts`, and `useWorkspace.ts`, plus callback configuration, route integration, shared focus styling, and the existing product/design context.
- Visually inspected `welcome-desktop.png`, `welcome-mobile.png`, `signed-in-desktop.png`, and `denied-desktop.png` in this directory. The captures agree with the current source and retain the intentional aubergine, gold, Inter, and Lion identity.
- Reviewed `browser-checks.json`: all nine authentication fixture groups pass with no recorded page errors. Reviewed the adjacent Strategy Lab receipt: five regression groups pass with no recorded errors. These existing checks were not rerun for this independent finish review.
- The parent review reports no hard detector findings. No additional detector or product-wide audit was performed here.

## Findings

No P0 or P1 findings. No additional actionable P2 or P3 findings within scope.

- The Google action is clear and separated from the public research path. The official button image is presented intact. Desktop and mobile captures show readable text, appropriate grouping, and no visible clipping or horizontal overflow.
- Native buttons and links preserve keyboard operation. The Google button has an accessible name, shared visible focus styling, and a 48px minimum height. Loading uses status announcements; failures use an alert and retain a recovery action. The icon-only mobile account link retains its accessible name.
- Signed-in identity, Picks, strategy navigation, and sign-out have a clear hierarchy. Long account addresses can wrap. Denial leaves the Google action available and explains how to retry.
- PKCE callbacks remove their code before exchange and bound the return destination to Picks or Strategies. Callback and login routes do not mount market widgets, and archive failures do not suppress login.
- Shared identity treats anonymous sessions as guests. Strategy state is cleared on account changes, mismatched owners are rejected, and superseded in-flight responses cannot restore a prior account's evidence.

## Release evidence boundary

This is a scoped UI and source review backed by injected browser fixtures. It does not establish live Google consent, production OAuth configuration, or a completed real-account login on leoinvesting.com. Those remain production verification work for the release owner.
