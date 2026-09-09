# Leonidas: The Observatory’s First Light

Four story-first activities are available through **Starpath → Investment →
Stories with Leonidas** when a current Starpath snapshot has loaded. This
supplementary collection is separate from the hosted lesson reader and recorded
learning progress. The first four matching local-preview lessons also retain
their inline story integration.

Each activity contains nine scenes, two teaching choices, specific retry
feedback, and tappable learning objects. The fourth chapter also contains an
ordered learner → broker → market interaction.

| Existing lesson | Chapter |
| --- | --- |
| What Is Investing? | The Unfinished Garden |
| What Is a Stock? | The Ownership Seal |
| Why Do Prices Move? | The Murmuring Hall |
| How the Market Works | The Lantern Route |

## Hosted supplementary collection

The Investment entry opens four numbered chapter rows. Any chapter can be
opened independently and ends with **Back to stories**. The selector and notes
say **Supplementary practice. No recorded progress or knowledge checks.**
The collection never calls start, answer, or recall commands.

The entry is absent from Trading and from loading, stale, offline, unavailable,
or forbidden Starpath states. Library, player, and notes routes all observe the
current controller; loss of the ready snapshot removes their content and
disposes the player and its narration.

`lib/features/starpath/presentation/leonidas_story_library.dart` owns the
collection, route access checks, and factual notes. Notes are adapted from the
first four internal-preview sections dated August 31, 2026, including their
uncertainty, limitations, and risk context. Fictional scenes and example quote
values are explicitly identified as illustrative, not observed market data.
Each chapter provides a selectable, clickable Investor.gov source:

- [Introduction to Investing](https://www.investor.gov/introduction-investing)
- [Stocks](https://www.investor.gov/introduction-investing/investing-basics/investment-products/stocks)
- [How Stock Markets Work](https://www.investor.gov/introduction-investing/investing-basics/how-stock-markets-work)
- [Executing an Order](https://www.investor.gov/introduction-investing/investing-basics/how-stock-markets-work/executing-order)

The first reference uses the current Introduction to Investing page because
the former `/introduction-investing/investing-basics` landing URL did not
resolve during verification. The source URLs were checked on September 5,
2026; this does not change the provenance date of the lesson material.

## Run the isolated preview

From `ritual-investing-app`:

```powershell
flutter run -d chrome --target test/leonidas_story_preview.dart
```

Or build and serve it locally:

```powershell
flutter build web --no-pub --no-web-resources-cdn --target test/leonidas_story_preview.dart --output build/leonidas-web
python -m http.server 8767 --bind 127.0.0.1 --directory build/leonidas-web
```

Open `http://127.0.0.1:8767`. Select any of the four lessons. The isolated
preview uses test lesson notes and checks; its LOCAL PREVIEW label stays visible,
and checks never record member progress. The app's existing internal preview
uses its own existing lesson notes through the same route integration.

## Content and authority

- Complete dialogue and choice scripts live in
  `lib/features/starpath/domain/leonidas_story.dart`.
- The resolver accepts only manifest `fixture-manifest` / `fixture-v1`,
  lesson/revision pairs `fixture-lesson-1` / `fixture-revision-1` and
  `fixture-lesson-2` / `fixture-revision-2`, section ordinals 1 and 2.
  Section headings are checked as an additional drift guard.
- Hosted draft lessons have different content and identities. They keep the
  existing reader; the supplementary collection does not modify the resolver
  or substitute fixture IDs into a member snapshot. Register an inline hosted
  revision only after its factual content and corresponding story script are
  reviewed together. No curriculum publication or database migration is included.
- Story choices change only local playback. In the inline local-preview
  integration, the existing knowledge-check route is offered after chapters two
  and four and retains its permission, preview, read-only, and sequential rules.
  The hosted supplementary player receives no knowledge-check callback.
- A controller-owned visit retains chapter position and explored choices by
  story/revision. Replay clears that chapter; a new controller starts fresh.
  The supplementary collection uses local namespace
  `leonidas-supplementary-v1`, independent of hosted curriculum revisions.
  Nothing is persisted to disk or synchronized to an account.

## Presentation and assets

The player inherits the app theme and uses separate portrait/dialogue regions:
stacked on phones, side by side from 760 logical pixels. Large text reduces the
portrait height and leaves the dialogue scrollable. No controls cover the face.
Existing warm, playful, analytical, and concerned Leonidas assets are reused
from `assets/images/leonidas/` and retain their existing provenance. The first
chapter adds the original Blender environment described below; its canonical
human speaker portrait remains separate from the scene.

The current line or feedback is read with the existing best-effort system TTS.
Mute is shared with Starpath. Navigation, notes, and backgrounding stop speech;
returning from notes does not start speech automatically. Text is primary and
remains usable if browser speech is blocked or unavailable. No cloud voice or
runtime language model is used.

## Blender garden pilot

**The Unfinished Garden** (`garden-v1`) uses a 1536 × 1152 image rendered in
Blender 4.5.9 LTS with Cycles. The original scene contains an observatory
courtyard, empty planting beds, and a table with a garden plan and botanical
specimen. Geometry, procedural materials, lighting and camera are reproducible
without external models or textures. This environment is an illustrative
memory aid, not evidence or a prediction about investment outcomes.

The environment fills the first chapter's art region. Leonidas's existing human
portrait appears in a stationary, labeled rectangular frame at the lower left;
the character has not been converted into a rigged 3D model. Chapters two through
four retain their existing art. Dialogue, choices, notes, narration and progress
contracts are unchanged.

The app adds a slow 18-second push/pull, bounded to a 1.015–1.04 image scale.
The 48-pixel **Pause scene motion** control becomes **Resume scene motion** when
paused. Reduced Motion uses a static scene, and background or hidden-route
states stop the animation. If the PNG cannot load, the previous canonical
portrait fills the stage. Lesson controls remain available and the lesson stays
readable. Focused tests cover motion, pause, lifecycle, fallback, and the first
chapter at 390 × 844 with doubled text, including the full speaker caption.

Authoring files are retained outside the app's bundled assets:

- [Editable Blender scene](../../art/leonidas/blender/garden-v1/leonidas-garden-v1.blend).
- [Rebuild script](../../art/leonidas/blender/build_garden.py).
- [Render provenance](../../art/leonidas/blender/garden-v1/provenance.json).
- [Authoring instructions](../../art/leonidas/blender/README.md), including the
  reproducible render command and renderer setup.

The app asset is
`assets/images/leonidas/leonidas-garden-blender-v1.png`; the existing Leonidas
asset-directory registration includes it. The website receives the PNG, not
the `.blend` source or a browser 3D runtime. Use the isolated preview commands
above and select **What Is Investing?** to inspect the garden locally at
`http://127.0.0.1:8767`. A local preview or successful release build does not
publish the change to `leoinvesting.com`.

## Prepare an isolated member release

The main worktree contains unrelated, unfinished Market Map changes. The
prepared member release is isolated at
`release-work/leo-web-20260905/`, beside the Argus repository. Its `source.zip`
is a Git archive of commit `54587fa68aadebe5ce56bc8d02b0e68524d18848` containing
`ritual-investing-app`, `ritual-investing-api-client`, and
`ritual-investing-site`. The archive SHA-256 is
`c104db40c4b56089f0970be7da2b9799711594bcfe887f93699eea94714eceb8`.

Recreate future releases from a retained Git archive or clean checkout, then
overlay only the selected story changes, their tests, lion web assets/metadata,
and destination configuration. The current source overlay consists of the
Starpath controller/narration controller, lesson and path screens, four new
story domain/playback/player/library files, their focused tests and fixture,
and `web/index.html`, `web/manifest.json`, and the two `leo-lion` icons. The
Blender pilot additionally overlays its scene PNG and updated player/tests.
Existing Google-only welcome/auth behavior comes from the archived base.
Do not copy the unrelated dirty application shell, Market Map, or API changes.

The user's corrected delivery target is exactly
`https://leoinvesting.com/#/welcome`. This supersedes the earlier alternate
hostname. The prepared artifact uses a separate configuration, preserving
`config/leoinvesting.json`, the earlier `config/leo-investing.json`, and the
default Worker configuration:

| Setting | Requested destination |
| --- | --- |
| Site | `https://leoinvesting.com/#/welcome` |
| Supabase project | `katwbobjiyzipqlzarus` |
| App configuration | `config/leoinvesting-fresh.json` |
| App OAuth return | `https://leoinvesting.com/mobile/argus-auth/callback` |

The domain's existing Worker also serves another hostname. Do not deploy this
artifact through the earlier alternate Worker configuration or assume that
updating the shared Worker is limited to the requested domain. Publication
requires verified access to the domain's owning account and a deployment
mapping scoped to `leoinvesting.com`.

Before building for a different destination, create its own public configuration
with the intended API/Supabase project and exact OAuth return URL. Confirm the
public-key hash and staging project reference agree.
Google client secrets remain server-side; the frontend build contains only
public configuration. A compiled Google button does not establish that the
destination's Supabase and Google callback settings are operational.

From the isolated `ritual-investing-app`, resolve dependencies, run the checks
below, then build the member entry point:

```powershell
flutter pub get
flutter build web --release --no-pub --no-web-resources-cdn --no-source-maps --no-wasm-dry-run --pwa-strategy=none --dart-define-from-file=config/leoinvesting-fresh.json
```

From the isolated `ritual-investing-site`, use the existing member assembly:

```powershell
$releaseConfiguration = Get-Content ../ritual-investing-app/config/leoinvesting-fresh.json -Raw | ConvertFrom-Json
$env:MEMBER_STAGING_SUPABASE_PROJECT_REF = $releaseConfiguration.STAGING_SUPABASE_PROJECT_REF
$env:MEMBER_STAGING_SUPABASE_ORIGIN = $releaseConfiguration.SUPABASE_URL
$env:MEMBER_STAGING_SUPABASE_PUBLISHABLE_KEY_SHA256 = $releaseConfiguration.STAGING_SUPABASE_PUBLISHABLE_KEY_SHA256
npm ci
npm run assets:build:member-staging
```

The assembled directory is `ritual-investing-site/dist/member-staging/`. Its
assembler validates provider configuration and asset limits, adds member
response headers and a noindex policy, and emits a SHA-256 asset manifest.
The release flags match the existing member web workflow: service workers and
source maps are disabled. The assembler rejects service-worker output.
Rebuild and reassemble whenever destination configuration changes. Deployment
and hosted OAuth verification are separate steps; this document records the
prepared artifact, not a deployment receipt.

The deployment serves the assembled static assets; Supabase remains the Auth
and application backend. Publishing is a separate action after the owning
account, domain mapping, package, and fresh backend's Google configuration are
verified. No publication command is prescribed until that mapping is resolved.

## Verification — 2026-09-05

Before the Blender extension, the isolated member source passed full
`flutter analyze --no-pub` and all 48 focused Flutter tests:

```powershell
flutter analyze --no-pub
flutter test --no-pub test/leonidas_story_test.dart test/leonidas_story_presentation_test.dart test/leonidas_story_integration_test.dart test/leonidas_story_library_test.dart test/starpath_presentation_test.dart test/starpath_controller_test.dart test/starpath_narration_controller_test.dart
```

Coverage includes every chapter/choice branch, revision fallback, replay/resume,
incorrect sequence taps, zero progress commands during story play, chapter-end
read-only checks, notes return, narration failure/mute/background handling,
keyboard focus, semantics, both themes, and 1×/2× text at phone and wide sizes.
Library tests additionally cover Investment-only entry, stale/offline/forbidden
access, all four chapters with unsupported hosted-shaped fixture identities,
source notes, no progress commands, and player disposal on access loss.

Visual review: Flutter-rendered phone and wide layouts, then a compiled web
smoke check of chapter entry, Next, and exploration feedback. Review PNGs can be
regenerated in `build/leonidas-review/` by setting `LEONIDAS_CAPTURE=1` for the
presentation tests. No golden baselines were changed.

The library also has Flutter-rendered 200% text captures at 402 × 874 and
1100 × 800 in `build/leonidas-story-library-review/`. The bounded source/visual
review verdict was **ship**. At phone width the long title wraps mid-word at
200%; no content or navigation is lost.

Independent source/artifact comparison of the original prepared release found:

- 95 of 96 selected Starpath, auth/onboarding, test, and asset files match the
  main source byte-for-byte. Every compared production behavior, configuration,
  and asset file matches.
- The initially stale `test/leonidas_story_library_test.dart` capture helper
  was refreshed after the fresh build. Its final copy matches the main source
  and places image encoding inside `tester.runAsync`.
- The local-only `test/leonidas_story_preview.dart` is absent
  from the prepared member source. Run the isolated preview from the main
  application directory as described above.
- The archive's old `web/icons/leo-192.png` and `leo-512.png` remain as unused
  source files. Both compiled and assembled manifests reference the new
  `leo-lion-192.png` and `leo-lion-512.png` URLs.
- All 110 original assembled asset-manifest records matched their SHA-256 hashes and
  lengths, totaling 99,063,525 bytes. Built and assembled HTML, JavaScript,
  manifest, and lion icons agree. The JavaScript bundle contains the four
  chapter titles, supplementary-practice notice, and Google sign-in entry.
- The fresh `config/leoinvesting-fresh.json` matches its main-source copy,
  SHA-256 `13d0dd6a507f20d9507aa726768a47edac6906dbe5f5f4181aba4b0cc27c9bd8`.
  The public-key digest agrees with its configured value. The compiled app
  references only the fresh Supabase origin, its API and public key, and the
  exact `https://leoinvesting.com/mobile/argus-auth/callback` return URL. The
  earlier alternate hostname is absent from the compiled JavaScript.
  Assembled CSP permits the fresh backend; no service workers or source maps
  are packaged.
- The requested-domain JavaScript release build and member assembly passed.
  The asset manifest SHA-256 is
  `28e11785492cc3e82ca3665942afeaa035e763eb2f88974ac1845f9099795933`.
  These checks do not claim a deployment or domain mapping change.

After the Blender extension, the isolated member release and asset assembly
were rebuilt successfully. All **111 files (101,430,746 bytes)** passed hash and
length verification. The refreshed manifest SHA-256 is
`30d220722bd889597ab65131193d13b7f4fbd52195ae355480cf83699a7d6728`.
Focused presentation/integration tests and scoped analysis passed. Desktop and
phone browser review checked the new artwork, pause/resume, replay, and answer
feedback; the independent visual review verdict was **ship**. The prepared
package's current status is recorded in
[the deployment record](leo-investing-deployment-20260905.md).

The existing `flutter_tts` dependency reports WebAssembly dry-run warnings;
the prepared artifact is JavaScript, and a Wasm build is not claimed. The main
dirty worktree's unrelated missing Market Map imports do not appear in the
isolated base. Native iOS/Android device verification was not performed on this
Windows host. No hosted account access or Google consent round-trip is claimed
by these local checks.
