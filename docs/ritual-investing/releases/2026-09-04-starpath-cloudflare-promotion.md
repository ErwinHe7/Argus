# Starpath Cloudflare promotion — 2026-09-04

The member app at `https://leoinvesting.com` serves Cloudflare Worker version
`34dcee39-0af2-488e-bb8b-6dfc75a22f72` at 100% traffic. Cloudflare deployment
`d845fb4f-0faa-4945-a7f8-dbdac20c885c` activated the version at
2026-09-04 12:48 UTC. The deployment was still current when rechecked on
2026-09-09.

## Reason for the manual release

Erwin's Investment and Trading Starpath work was merged in PR #11 and reached
`main`, but the member Worker still served an artifact built from
`e3ffd5385dc27921a133299d112563137eb9ed12`. That older artifact did not contain
the universe selector or Trading roadmap.

A direct build of `main` was not promoted because its Google-only login was
incompatible with the live beta backend at release time: the backend reported
Google disabled and email enabled. The promoted artifact therefore preserved
the existing email authentication flow while applying the merged Starpath
experience and the current `leoinvesting.com` runtime configuration.

No backend configuration, authentication provider, Worker route, custom domain,
or database state changed during this release.

## Source and artifact identity

- Base revision: `e3ffd5385dc27921a133299d112563137eb9ed12`
- Merged feature and domain revision: `a3c2311be394f64deb7f6030b54f3e2beffbd3c4`
- Worker: `ritual-investing-member`
- Worker version: `34dcee39-0af2-488e-bb8b-6dfc75a22f72`
- Deployment: `d845fb4f-0faa-4945-a7f8-dbdac20c885c`
- Asset-manifest SHA-256:
  `36a6fb6a0bd5302eaa2751534fbccc8fe86617655f98edf5b819ddf22f1046cd`
- `main.dart.js` SHA-256:
  `07fcd8e9dd159b16e2c0d90b19c4a679a9eb4c41fd1af424e2117ab65aa101f3`

The release overlaid these paths from the merged revision onto the base:

- `ritual-investing-app/lib/features/starpath/`
- `ritual-investing-app/integration_test/starpath_member_flow_test.dart`
- `ritual-investing-app/test/starpath_presentation_test.dart`
- `ritual-investing-app/test/starpath_universe_test.dart`
- `ritual-investing-app/test/investment_constellation_test.dart`
- `ritual-investing-app/test/starpath_narration_controller_test.dart`
- `ritual-investing-app/test/support/starpath_test_fixture.dart`
- `ritual-investing-app/lib/core/config/runtime_config.dart`
- `ritual-investing-app/config/beta.json`

The build added the feature's pinned `flutter_tts: 4.2.5` dependency. The
Cloudflare version annotation records the source revisions and manifest digest.

## Verification

- Targeted Starpath, runtime, member-auth, and session tests: 73 passed.
- `flutter analyze lib`: passed with no issues.
- Flutter release web build: passed.
- TypeScript typecheck: passed.
- Asset-build and static-policy tests: 19 passed.
- Asset assembly: 93 files; every manifest hash matched.
- Live `asset-manifest.json`, `main.dart.js`, and Material Icons bytes matched
  the promoted artifact.
- The existing signed-in browser session survived the deployment and reload.
- Investment and Trading rendered and switched in both directions.
- Investment rendered four constellations and 19 backend-supplied lessons; an
  Investment lesson opened and displayed its factual content.
- Trading rendered the merged four-constellation roadmap preview.

## Rollback

The previous version is `4132c697-4656-49d1-9fa4-5e6fa2a29ffd`. Restore it to
100% traffic through a new Cloudflare Worker deployment if the promoted version
must be rolled back. Do not change routes, domains, or backend configuration as
part of that rollback.
