# Ritual Investing

Flutter member application for the ritual-first Argus product. The app ships one shared Dart UI to iOS, Android, and an invite-first mobile-web beta and does not import from, run, or modify the AXIO7 research services. The web beta preserves supported member behavior, including the launch-required privacy lifecycle; it does not enable unfinished financial behavior.

## Product authority

Webull is authoritative for brokerage accounts, capabilities, restrictions, balances, positions, and orders. Argus is authoritative for ritual, editorial, community, preference, and privacy state. Supabase owns Argus identity, application data, server compute, durable jobs, and retained object storage. Cloudflare Pages continues to serve the unchanged static landing and standalone Demo assets. Cloudflare Workers Static Assets may deliver compiled member-beta files at the apex, with no request handler, binding, authentication, data, or backend authority.

The production member app is a frontend for an existing Webull brokerage relationship; it is not a brokerage ledger. Flutter never receives Webull credentials or raw provider payloads and never calls Webull directly. Brokerage reads and supported manual order commands cross the generated, versioned Argus API. Funding, account opening, recurring financial execution, autonomous trading, and rebalance execution are outside the product.

The standalone Demo is synthetic, memory-only, auth-free, provider-free, credential-free, and network-isolated. It remains in `ritual-investing-demo/`; production must not import its fixtures, state, services, or reset behavior.

## Public web beta

The clearly labeled apex member beta is invite-first and binds only to dedicated non-production beta Supabase Auth, the versioned beta Argus API, and canonical private tables. It does not use production endpoints, public Data API tables, or a parallel browser-owned application-data path. The current landing artifact remains the rollback target, and the standalone Demo remains independent.

Capability labels have one meaning across the member app and release evidence:

- `beta-backed` means the supported member behavior uses the versioned beta Argus API and private beta data boundary. Privacy export is beta-backed; deletion is beta-backed through the idempotent deletion path or a request/status path with a verified manual completion SLA.
- `unavailable` means the control is visibly incomplete and performs no provider or financial request. Brokerage connection and reads, funding, and order mutations remain in this state for the beta.
- `standalone Demo handoff` means an explicit, visibly labeled navigation to the independent synthetic Demo; Demo fixtures never fill gaps in the member app.

Invite-first launch requires server-enforced invitation restriction, custom SMTP, invitation delivery and resend, enumeration-resistant recovery, rate limits, deletion, and support ownership. Self-service signup additionally requires hosted email confirmation and CAPTCHA or equivalent abuse protection; until that evidence is recorded, open signup remains disabled. The unresolved hardening and product-definition work is tracked as P1 follow-up in [`public-beta-web-p1-follow-up-register.md`](../docs/ritual-investing/public-beta-web-p1-follow-up-register.md); that register does not waive a launch gate or authorize an unavailable financial capability.

Every authenticated route labels the experience as a public beta and states that live brokerage connections, funding, and orders are unavailable. Privacy, support, about, beta-feedback, and legal information remain reachable from the member experience.

## Member surfaces

- Daily Ritual, evidence, discovery, Asset Codex, Grimoires, Circles, Founders' Coven, Rowan, preferences, and editorial content remain Argus-owned.
- Intentions and Future Mirror remain non-authoritative scenarios; they do not change Webull state or authorize orders.
- Account selection, balances, positions, restrictions, and order history are timestamped Webull projections with explicit fresh, stale, unavailable, and empty states.
- Only partner-approved manual order combinations may proceed through preview, review, and explicit confirmation. Stale or incoherent authority disables mutations.
- Rowan cannot issue financial commands and cannot receive Webull credentials, raw provider payloads, balances, or positions as prompt context.
- Privacy export and deletion operate on Argus-owned data. Disconnecting or deleting Argus never claims to close a Webull account or cancel a Webull order.

## Runtime boundary

- Supabase Auth is the member identity provider.
- The generated Dio client is the only application-data and brokerage-data boundary.
- Direct Supabase client use is limited to Auth and approved private Storage transport.
- Secure device storage may hold the Supabase session and short-lived local coordination state, never Webull credentials.
- Screens depend on controllers and repository contracts rather than provider SDKs.

The member app uses Supabase Auth and the Supabase Edge API. Webull remains the brokerage authority, while the standalone Demo remains synthetic and provider-free. The migration-era Auth0, Neon, Cloudflare backend, and simulated-finance authorities have been removed.

## Local checks

```sh
flutter analyze
flutter test
flutter test integration_test/member_experience_test.dart -d <device-id> \
  --dart-define=RITUAL_MEMBER_TEST_ID=local-$(date +%s)
../scripts/test-check-member-provider-boundaries.sh
../scripts/check-member-provider-boundaries.sh
```

For native development, launch the member app against the persistent `beta`
branch of the hosted Ritual Investment Supabase project from the
repository root:

```sh
./scripts/run-ritual-investing-beta.sh -d <device-id>
```

The script reads the committed public client configuration from
`ritual-investing-app/config/beta.json`. It contains only the beta branch URL,
branch ref, Supabase publishable key, and its SHA-256 fingerprint; no server
secret or database credential is shipped to Flutter. The public web artifact
binds to that same persistent beta branch and its versioned beta API after the
release guard verifies the exact branch ref, origin, and publishable-key
fingerprint.

The visual baselines live under `test/goldens/`. Regenerate them only after comparing the result with the approved authority at `../docs/visual-references/standalone-ritual-investing/approved-light-dark-reference.html`.

## Native prerequisites

Device builds require full Xcode and CocoaPods for iOS plus Android Studio/SDK for Android. Run `flutter doctor -v` after installing them. Bundle identifiers remain provisional until the product name and store identity are finalized.

## Hosted release gates

Before a mobile release, verify on real iOS and Android devices that Supabase sign-up, sign-in, callback recovery, session restoration, reauthentication, sign-out, and different-account isolation work. Webull connection, refresh, disconnect, reads, and manual orders require separate hosted sandbox evidence; local mocks are not provider proof.

See [member release gates](../docs/ritual-investing/member-release-gates.md) and the [member data inventory](../docs/ritual-investing/member-data-inventory.md). Those documents must be updated as legacy runtime paths are replaced.
