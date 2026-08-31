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

## Supabase member Auth build and hosted login

- XcodeBuildMCP consumes Flutter's generated iOS settings. Before the first MCP
  build, and whenever a Supabase endpoint or native-link host changes, copy
  `ios/Flutter/NativeLinks.xcconfig.example` to the ignored
  `ios/Flutter/NativeLinks.xcconfig`, set the claimed-link host, and regenerate
  Flutter's settings
  from this app directory:

  ```sh
  flutter pub get
  flutter build ios --simulator --debug \
    --dart-define=RITUAL_API_BASE_URL=https://YOUR_PROJECT.supabase.co/functions/v1/api \
    --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
    --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY \
    --dart-define=ARGUS_AUTH_REDIRECT_ALLOWLIST=https://just-build-this.app/mobile/argus-auth/callback,com.ritualinvesting.ritual-investing-app.auth://argus-auth/callback \
    --dart-define=WEBULL_COMPLETION_ALLOWLIST=https://just-build-this.app/mobile/webull/complete,com.ritualinvesting.ritual-investing-app.webull://webull/complete
  ```

- Supabase member authentication is Google OAuth only. The app calls
  `signInWithOAuth(OAuthProvider.google)` with one exact redirect selected from
  `ARGUS_AUTH_REDIRECT_ALLOWLIST`; register that redirect in Supabase Auth and
  the matching origin in Google Auth Platform. Email/password signup, login,
  confirmation, and recovery are not member entry paths.
- The OAuth consent flow may run in a system-owned browser surface and be
  absent from the app's ordinary UI snapshot. Inspect fresh system
  accessibility state; never use stale coordinates or capture credentials.
- Exercise cold start, warm return, cancelled OAuth, wrong-account return,
  expired-session refresh, offline refresh, local logout, global logout, and
  every malformed or cross-lifecycle link. Never print or preserve access,
  refresh, callback, provider, or step-up tokens in screenshots, logs, or test
  evidence.
- Webull completion targets are a separate lifecycle and must never be accepted
  by the Supabase callback predicate.
