---
title: "Build and Authenticate Ritual Investing iOS in Simulator with XcodeBuildMCP"
date: 2026-08-25
category: developer-experience
module: ritual-investing-app
problem_type: developer_experience
component: development_workflow
severity: medium
applies_when:
  - "building or launching ritual-investing-app in iOS Simulator through XcodeBuildMCP"
  - "smoke-testing hosted Auth0 Universal Login in iOS Simulator"
  - "using an unsigned Simulator build without associated-domain signing"
  - "automating the system ASWebAuthenticationSession surface"
root_cause: incomplete_setup
resolution_type: environment_setup
related_components:
  - "authentication"
  - "frontend"
  - "tooling"
tags:
  - "xcodebuildmcp"
  - "flutter"
  - "ios-simulator"
  - "auth0"
  - "universal-login"
  - "aswebauthenticationsession"
  - "agent-workflow"
---

# Build and Authenticate Ritual Investing iOS in Simulator with XcodeBuildMCP

## Context

The Simulator workflow has two setup layers. Flutter must first generate the
native iOS build inputs with the beta Dart defines, and XcodeBuildMCP must then
build and drive the correct workspace, scheme, simulator, and bundle. The
repository profile records `ritual-investing-app/ios/Runner.xcworkspace`, the
`Runner` scheme, Debug configuration, `iPhone 17` on the latest available iOS
runtime, and bundle ID `com.ritualinvesting.ritualInvestingApp`
(`.xcodebuildmcp/config.yaml:3-11`).

The identity values are compile-time Dart environment values. The app reads
`RITUAL_API_BASE_URL`, `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID`, `AUTH0_AUDIENCE`, and
`AUTH0_USE_HTTPS`; HTTPS callbacks default to enabled when the final value is
omitted (`ritual-investing-app/lib/core/config/runtime_config.dart:26-38`). iOS
also includes a local `Auth0.xcconfig` from Debug and Release configuration
(`ritual-investing-app/ios/Flutter/Debug.xcconfig:1-3`,
`ritual-investing-app/ios/Flutter/Release.xcconfig:1-3`). This is necessary
because the Dart domain define does not populate the native build setting used
by the associated-domain entitlement
(`ritual-investing-app/ios/Runner/Runner.entitlements:5-8`).

The verified outcome on 2026-08-25 was deliberately narrow: an iPhone 17
Simulator build launched through XcodeBuildMCP, onboarding was traversable,
Auth0 Universal Login accepted the local test account, and the callback returned
control to the app. A later account-preparation error happened after that return
and is outside this learning. This proves the local build, hosted-provider
acceptance, and callback-return path; it does not prove the post-login member
shell or replace the real-device release gates
(`ritual-investing-app/README.md:43-52`).

Earlier sessions had green generated-client and authentication tests, but those
used an injected test token and did not exercise the hosted browser or callback
return (session history). This setup closes that specific evidence gap.

## Guidance

### 1. Select the portable MCP profile

From the repository root, select the `ritual-investing-app` defaults profile,
then inspect the effective defaults before building:

1. `session_use_defaults_profile({profile: "ritual-investing-app"})`
2. `session_show_defaults({})`

Confirm the values against `.xcodebuildmcp/config.yaml:3-11`. If `iPhone 17` is
not installed, list simulators and choose an available iPhone for the current
session. Do not commit a machine-specific simulator UDID. These are also the
agent-facing rules in `ritual-investing-app/AGENTS.md:5-16`.

### 2. Bootstrap Flutter's generated iOS settings

Run this before the first MCP build and whenever a beta endpoint or Auth0 value
changes:

```sh
cd ritual-investing-app
flutter pub get
flutter build ios --simulator --debug \
  --dart-define=RITUAL_API_BASE_URL=https://api-beta.just-build-this.app \
  --dart-define=AUTH0_DOMAIN=dev-pxee7db52tqc4xoe.us.auth0.com \
  --dart-define=AUTH0_CLIENT_ID=VIFuQLVxk6baW27jS9TzQ22pIV8lAqHz \
  --dart-define=AUTH0_AUDIENCE=https://api-beta.just-build-this.app \
  --dart-define=AUTH0_USE_HTTPS=false
```

The beta values come from the member-build authority
(`docs/ritual-investing/beta-environment.md:99-114`). The explicit
`AUTH0_USE_HTTPS=false` follows the repository's custom-scheme rollback path for
this unsigned Simulator build (`docs/ritual-investing/auth0-setup.md:52-58`). The
app otherwise chooses the HTTPS web-authentication scheme and passes
`useHTTPS: true` to login and logout
(`ritual-investing-app/lib/core/auth/auth0_session_repository.dart:32-37`,
`ritual-investing-app/lib/core/auth/auth0_session_repository.dart:59-73`,
`ritual-investing-app/lib/core/auth/auth0_session_repository.dart:90-97`).

In the verified run, the unsigned HTTPS attempt ended as `interrupted` before
Universal Login could be used. Regenerating with the custom-scheme flag opened
Universal Login and returned to the app. Keep the default HTTPS path for signed,
associated-domain real-device evidence; the production migration and rollback
procedure remains authoritative (`docs/ritual-investing/auth0-setup.md:27-58`).

### 3. Align the ignored native Auth0 configuration

Create `ritual-investing-app/ios/Flutter/Auth0.xcconfig` from
`Auth0.xcconfig.example` and set `AUTH0_DOMAIN` to the same host used by the Dart
define. The example states that the values must match
(`ritual-investing-app/ios/Flutter/Auth0.xcconfig.example:1-3`), and the local
file is ignored (`ritual-investing-app/.gitignore:26-34`). Never commit the
generated local file.

### 4. Build, launch, and inspect through XcodeBuildMCP

Run `build_run_sim({})` with the verified defaults. On success, immediately take
an app UI snapshot to prove launch before interacting. Take a fresh snapshot
before each tap or text entry and again after every navigation or layout change
(`ritual-investing-app/AGENTS.md:15-16`). Use screenshots only for non-sensitive
visual evidence and use simulator log capture when the UI state is ambiguous.

### 5. Treat Universal Login as iOS-owned system UI

In the verified run, hosted Auth0 appeared as an iOS-owned
`ASWebAuthenticationSession` sheet: an ordinary app UI snapshot showed the
underlying Flutter app while the hosted sheet was active. That observation is
session evidence, not an app source-code behavior claim, and the underlying app
snapshot is not proof the login failed to open.

When the app snapshot cannot see the sheet, inspect the current system
accessibility state through XcodeBuildMCP's bundled accessibility bridge. Target
fields from the current accessibility labels and bounds; if a coordinate is
required, derive it from that fresh system snapshot rather than reusing a stale
one. Never capture a password-bearing screenshot or reproduce the password in a
command, log, report, or durable test artifact
(`ritual-investing-app/AGENTS.md:39-48`).

### 6. Keep the test identity local

The test credential file belongs at
`.xcodebuildmcp/ritual-investing-app.credentials`, which the root ignore rules
exclude from version control (`.gitignore:1-4`). Keep it mode `0600`, read it
only when a hosted-login check requires it, and enter it only into the Auth0
sheet opened by this app. Do not copy it into scripts, screenshots,
documentation, or committed configuration.

## Why This Matters

This repository's workflow bootstraps Flutter before invoking XcodeBuildMCP
because both iOS build configurations include Flutter's `Generated.xcconfig`
(`ritual-investing-app/ios/Flutter/Debug.xcconfig:1-3`,
`ritual-investing-app/ios/Flutter/Release.xcconfig:1-3`). Selecting the right
workspace cannot repair stale generated Dart defines, while a correct Flutter
bootstrap cannot prevent an agent from driving the wrong scheme or Simulator
when session defaults are not inspected.

The callback-mode distinction also prevents a misleading failure loop. This
unsigned local lane intentionally uses the custom-scheme callback; signed release
builds retain the associated-domain HTTPS path. Making those lanes explicit
keeps local exploration reliable without weakening release configuration.

Finally, hosted authentication crosses a process and accessibility boundary.
App-level snapshots describe the Flutter process, while the hosted login is
owned by iOS. Recognizing that boundary avoids false negatives and makes it
possible to automate login without treating blind coordinate taps or
credential-bearing screenshots as acceptable evidence.

## When to Apply

- Start of a fresh iOS Simulator exploration session.
- After Flutter, beta endpoint, native Auth0, callback, scheme, or bundle changes.
- When XcodeBuildMCP builds the wrong app or the launched app uses stale runtime
  configuration.
- When hosted login appears absent from an ordinary app UI snapshot.

Regenerate the Flutter inputs whenever any of the five Dart defines changes and
re-check the local native domain whenever `AUTH0_DOMAIN` changes. Stop this
workflow at successful Auth0 return if a later failure concerns API bootstrap,
account preparation, or member-shell loading; diagnose that as a separate
problem instead of expanding this learning's verified claim.

## Examples

### Happy-path sequence

1. Select `ritual-investing-app` with `session_use_defaults_profile`.
2. Inspect the effective defaults with `session_show_defaults`.
3. Run the one-time Flutter Simulator bootstrap command above.
4. Run `build_run_sim`.
5. Snapshot the app, traverse onboarding with fresh snapshots, and start hosted
   sign-in.
6. If the Auth0 sheet is absent from the app snapshot, inspect the current
   system accessibility surface and enter the ignored local test identity.
7. Record only that Auth0 accepted the account and returned to the app. Treat any
   subsequent preparation failure as separate evidence.

### Troubleshooting signals

- A missing/invalid runtime-setting error often indicates an absent or malformed
  Dart-define value; verify the values and regenerate the iOS inputs instead of
  adding launch-only environment variables (`ritual-investing-app/lib/core/config/runtime_config.dart:40-58`).
- An unsigned Simulator login that becomes `interrupted` in HTTPS mode points
  back to the callback/signing lane; regenerate with
  `AUTH0_USE_HTTPS=false` without changing production defaults.
- An unexpected installed app points back to unverified MCP session defaults.
- A snapshot that shows onboarding after login was requested may show the app
  underneath an active system sheet; inspect system accessibility before retrying.
- Auth0 return followed by account-preparation failure proves only the auth-return
  boundary.

## Related

- `ritual-investing-app/AGENTS.md` — concise agent checklist.
- `docs/ritual-investing/auth0-setup.md` — signed HTTPS callback and rollback
  authority.
- `docs/ritual-investing/beta-environment.md` — beta member-build values.
- `ritual-investing-app/README.md` — native prerequisites and release smoke
  boundary.
- `docs/ritual-investing/member-release-gates.md` — mandatory real-device
  identity evidence.
- `docs/solutions/architecture-patterns/ritual-investing-app-current-intent-and-architecture.md`
  — broader app architecture context; its implementation-state inventory is
  stale and should be refreshed before reuse.
- No matching GitHub issues were found for `xcodebuildmcp auth0 simulator` on
  2026-08-25.
