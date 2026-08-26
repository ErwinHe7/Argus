# Ritual Investing

Standalone Flutter application for the ritual-first investing product. The app ships one shared Dart UI to iOS and Android and does not import from, run, or modify the AXIO7 research services.

## Current member experience

- Adaptive iOS/Android bottom navigation with Ritual, Discover, Coven, and You destinations.
- Approved lunar-lilac and aubergine-night themes with a server-authoritative theme setting.
- Daily Compass ritual using the preserved generated artwork.
- Inspectable `Market-informed` explanation sheet and explicit Demo limitations.
- Asset Codex search and comparison; Grimoires, Circles, and Founders’ Coven discovery and saving.
- Provider-free Demo portfolio, fictional funding, simulated orders, recurring investing, and rebalancing with explicit confirmation.
- Intentions, Future Mirror, briefings, in-app notifications, Demo membership, privacy export/deletion status, and seeded-Demo reset flows.
- Guided investing, ritual-language, spirituality, and optional date-only astrology onboarding before Auth0 sign-up/sign-in, followed by server-complete shell gating.
- Rowan counsel using the preserved portrait study.
- Active personalization changes presentation and defaults only; it never authorizes a command or moves real money.
- Widget, accessibility, generated-Dio integration, and deterministic light/dark visual-regression tests.

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

The aggregate integration target starts local loopback services and traverses
every member slice through the generated Dio client. Its injected identity is
test-only and ephemeral; it does not contact a bank, broker, payment, market-data,
push, or hosted Auth0 provider.

## Native prerequisites

The project includes generated `ios/` and `android/` hosts. Device builds additionally require full Xcode and CocoaPods for iOS, plus Android Studio/SDK for Android. Run `flutter doctor -v` after installing them.

The bundle identifiers generated for the working scaffold are provisional until the product name and store identity are finalized.

## Beta iOS Simulator build

From the repository root, use this single command to regenerate the Flutter iOS settings and build the beta app for the unsigned Simulator callback lane:

```sh
cd ritual-investing-app && flutter pub get && flutter build ios --simulator --debug --dart-define=RITUAL_API_BASE_URL=https://api-beta.just-build-this.app --dart-define=AUTH0_DOMAIN=dev-pxee7db52tqc4xoe.us.auth0.com --dart-define=AUTH0_CLIENT_ID=VIFuQLVxk6baW27jS9TzQ22pIV8lAqHz --dart-define=AUTH0_AUDIENCE=https://api-beta.just-build-this.app --dart-define=AUTH0_USE_HTTPS=false
```

`AUTH0_USE_HTTPS=false` is only for the unsigned iOS Simulator lane. Keep HTTPS callbacks enabled for signed real-device and release builds.

## Release smoke gates

The loopback integration suite exercises an injectable hosted-auth seam; it does not imitate or claim proof of the external Auth0 browser. Before a mobile release, verify on real iOS and Android devices that:

- Auth0 Universal Login opens for both sign-up and returning sign-in.
- Cancel returns to the editable review with the protected draft intact.
- The configured callback returns to this app and the authenticated account is reconciled before the member shell opens.
- Logout clears the Auth0 session and a different-account sign-in cannot inherit the prior account's draft or cache.

The iOS simulator build is a separate local build gate. Android build and device smoke proof require an installed Android SDK; SDK absence is an environment limitation, not a passing Android result.

See the repository [member release gates](../docs/ritual-investing/member-release-gates.md),
[member data inventory](../docs/ritual-investing/member-data-inventory.md), and
[Auth0 setup](../docs/ritual-investing/auth0-setup.md) before beta promotion.
