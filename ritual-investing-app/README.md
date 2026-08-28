# Ritual Investing

Flutter member application for the ritual-first Argus product. The app ships one shared Dart UI to iOS and Android and does not import from, run, or modify the AXIO7 research services.

## Product authority

Webull is authoritative for brokerage accounts, capabilities, restrictions, balances, positions, and orders. Argus is authoritative for ritual, editorial, community, preference, and privacy state. Supabase owns Argus identity, application data, server compute, durable jobs, and retained object storage. Cloudflare Pages serves only static landing and standalone Demo assets.

The production member app is a frontend for an existing Webull brokerage relationship; it is not a brokerage ledger. Flutter never receives Webull credentials or raw provider payloads and never calls Webull directly. Brokerage reads and supported manual order commands cross the generated, versioned Argus API. Funding, account opening, recurring financial execution, autonomous trading, and rebalance execution are outside the product.

The standalone Demo is synthetic, memory-only, auth-free, provider-free, credential-free, and network-isolated. It remains in `ritual-investing-demo/`; production must not import its fixtures, state, services, or reset behavior.

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

The current source still contains migration-era Auth0, Neon, Cloudflare Worker/Queue/R2, and simulated-finance implementations. They are replacement inputs, not target authority, and are removed only after their Supabase or Webull replacements pass the cutover gates.

## Local checks

```sh
flutter analyze
flutter test
flutter test integration_test/member_experience_test.dart -d <device-id> \
  --dart-define=RITUAL_MEMBER_TEST_ID=local-$(date +%s)
../scripts/test-check-member-provider-boundaries.sh
../scripts/check-member-provider-boundaries.sh
```

The visual baselines live under `test/goldens/`. Regenerate them only after comparing the result with the approved authority at `../docs/visual-references/standalone-ritual-investing/approved-light-dark-reference.html`.

## Native prerequisites

Device builds require full Xcode and CocoaPods for iOS plus Android Studio/SDK for Android. Run `flutter doctor -v` after installing them. Bundle identifiers remain provisional until the product name and store identity are finalized.

## Hosted release gates

Before a mobile release, verify on real iOS and Android devices that Supabase sign-up, sign-in, callback recovery, session restoration, reauthentication, sign-out, and different-account isolation work. Webull connection, refresh, disconnect, reads, and manual orders require separate hosted sandbox evidence; local mocks are not provider proof.

See [member release gates](../docs/ritual-investing/member-release-gates.md) and the [member data inventory](../docs/ritual-investing/member-data-inventory.md). Those documents must be updated as legacy runtime paths are replaced.
