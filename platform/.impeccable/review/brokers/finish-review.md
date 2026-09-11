# Broker connection finish review

Final review: 2026-09-11, 05:22 UTC. Scope: the `#/brokers` setup/status surface,
its navigation entry, Connect computer deep link, final preview copy, and staged
Windows-tools link. Preview origin: `http://127.0.0.1:3221`.

## Verdict: ship this surface

Independently inspected the regenerated `desktop.png`, `mobile.png` (390px),
`reported-desktop.png`, and `stale-desktop.png` in this folder. The aubergine,
gold, Inter, and Leo Lion design remains coherent. Final download labels wrap
cleanly on phones; broker capability labels, setup actions, and reported-account
limitations remain legible. No clipping, overlap, or other visual blocker found.
No further design changes are required.

The prior status-message accessibility finding is resolved. The persistent,
text-only identity summary has `role="status"` and `aria-atomic="true"`, with
action controls outside it. The browser regression now asserts those semantics
and confirms both fresh and stale connection text appear inside that region.

## Final regression results

All commands ran from `platform/` with the existing `tsx` loader and bundled
Playwright. Browser suites used the preview origin above and injected fixtures.

| Command | Result |
| --- | --- |
| `node --import tsx features/strategy-lab/brokers/browser.cjs` | 5/5 groups passed; no browser errors |
| `node --import tsx features/research-desk/account/auth-browser.cjs` | 9/9 groups passed; no browser errors |
| `node --import tsx features/strategy-lab/tests/browser.cjs` | 5/5 groups passed; no browser errors |
| `node --import tsx --test features/research-desk/worker-routing.test.cjs` | 17/17 tests passed |

`LEO_BROKER_TEST_BASE` and `LEO_AUTH_TEST_BASE` were set to the preview origin.
`LEO_PLAYWRIGHT_MODULE` used the bundled runtime's `node_modules/playwright`.
An initial browser attempt could not load the stopped preview; all three suites
were rerun successfully after the parent restarted it. Saved receipts and
screenshots now contain the successful final run.

The broker fixture asserts that both **Windows tools · unsigned preview** links
have the exact href
`/app/research-desk/downloads/leo-broker-tools-windows-x64.zip` and the native
`download` attribute. The staged ZIP's independently computed SHA-256 matches
the manifest's installer hash:
`f9d59fa7f22819a60cdaa154bfb98ec11fb781590351c6d403dd98d1b8132746`.
The parent verified the native bundle and all three download parts, plus Windows
install/uninstall, tamper rejection, and state preservation. The release gate is
now enabled and the UI explicitly identifies the unsigned development package.

## Product and evidence boundaries

- The setup links reach Connect computer without creating a token, mandate, or
  order. Guest exploration remains usable during archived-data outages.
- Owner identity, revoked-device exclusion, expired/future heartbeat rejection,
  and stale-value preservation passed their browser fixtures. A heartbeat is
  explicitly distinguished from broker connectivity and trading authorization.
- moomoo remains paper-only. IBKR is accurately labeled **Developer preview**:
  local Client Portal paper adapter plus read-only TWS inspector, with public
  automatic trading disabled pending broker approval and a complete paper
  validation cycle.
- The prior detector found no hard issue, only the inherited type-ramp advisory.
  It was not rerun for assertions or documentation.

Fixture accounts, timestamps, sign-in exchanges, and strategy operations are
test evidence. This review did not authenticate to Google or a broker, place
orders, perform native installation, or establish broker acceptance or returns.
The reviewer changed only browser assertions and review evidence; no product
design, commits, or deployment were changed.
