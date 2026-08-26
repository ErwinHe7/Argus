# Ritual Investing app agent guide

## iOS simulator workflow

- Use XcodeBuildMCP for iOS build, launch, UI inspection, input, screenshots,
  logs, and debugging.
- From the repository root, select the persisted `ritual-investing-app`
  XcodeBuildMCP profile. Always inspect session defaults before the first build.
- The portable profile targets `ios/Runner.xcworkspace`, the `Runner` scheme,
  the latest available iOS runtime on an `iPhone 17`, and bundle identifier
  `com.ritualinvesting.ritualInvestingApp`.
- If the preferred simulator is unavailable, list simulators and select an
  available booted iPhone without editing the committed profile for a
  machine-specific UDID.
- Before tapping or typing, take a fresh runtime UI snapshot and use its
  element references. Re-snapshot after every navigation or layout change.

## Beta build and hosted login

- XcodeBuildMCP consumes Flutter's generated iOS settings. Before the first MCP
  build, and whenever a beta endpoint or Auth0 value changes, regenerate them
  from this app directory:

  ```sh
  flutter pub get
  flutter build ios --simulator --debug \
    --dart-define=RITUAL_API_BASE_URL=https://api-beta.just-build-this.app \
    --dart-define=AUTH0_DOMAIN=dev-pxee7db52tqc4xoe.us.auth0.com \
    --dart-define=AUTH0_CLIENT_ID=VIFuQLVxk6baW27jS9TzQ22pIV8lAqHz \
    --dart-define=AUTH0_AUDIENCE=https://api-beta.just-build-this.app \
    --dart-define=AUTH0_USE_HTTPS=false
  ```

- `AUTH0_USE_HTTPS=false` is the unsigned Simulator lane. Keep the signed HTTPS
  callback and associated-domain configuration for real-device release proof.
- The ignored `ios/Flutter/Auth0.xcconfig` supplies the native Auth0 domain and
  must match the Dart `AUTH0_DOMAIN`; a Dart define does not populate the native
  entitlement setting.
- Local test credentials live in
  `../.xcodebuildmcp/ritual-investing-app.credentials`. Read them only when a
  hosted-login test requires them. Never print, log, commit, or place the
  password in screenshots or durable test evidence.
- Enter credentials only into the Auth0 hosted login opened by this app. Do not
  use them for unrelated services.
- Hosted Auth0 login is an iOS-owned `ASWebAuthenticationSession` sheet, so it
  may be absent from the app's ordinary UI snapshot. Inspect the current system
  accessibility state through XcodeBuildMCP's bundled bridge; do not use stale
  coordinates or capture credential-bearing screenshots.
- A simulator login is exploratory beta evidence, not a substitute for the
  real-device Auth0 release smoke gates documented in the app README.
- The durable setup, troubleshooting signals, and verified boundary live in
  `../docs/solutions/developer-experience/xcodebuildmcp-ios-simulator-auth0-workflow.md`.
