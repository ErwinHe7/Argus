---
title: "Ritual Investing App: Current Intent, Usage, and Architecture"
date: 2026-08-23
category: architecture-patterns
module: ritual-investing-app
problem_type: architecture_pattern
component: frontend
severity: medium
applies_when:
  - "onboarding to ritual-investing-app"
  - "changing the app shell, themes, or top-level navigation"
  - "implementing stateful demo workflows from the architecture blueprint"
  - "adding a governed market-data or computational adapter"
  - "reviewing evidence, Demo disclosure, or Rowan behavior"
related_components:
  - "documentation"
  - "data_model"
tags:
  - "ritual-investing"
  - "flutter"
  - "presentation-scaffold"
  - "deterministic-demo"
  - "product-boundary"
  - "evidence-disclosure"
  - "architecture"
  - "current-state"
---

# Ritual Investing App: Current Intent, Usage, and Architecture

## Context

Ritual Investing is currently a verified Flutter **experience scaffold**, not yet the locally stateful simulated investment product described by its implementation plan. The working app establishes the product boundary, vocabulary, four-destination information architecture, Daily Ritual, evidence choreography, adaptive navigation, and light/dark visual system. It deliberately stands alone from the repository's AXIO7 research services and ships one shared Dart UI through generated iOS and Android hosts (`ritual-investing-app/README.md:3`, `ritual-investing-app/lib/main.dart:5`).

The intended user is a Gen Z or millennial woman who is curious about investing but alienated by generic brokerage interfaces. The app is designed for short daily rituals, deeper research, and periodic goal reviews. Its job is to make an idea emotionally legible, explain why it appeared, and expose uncertainty without pressuring a transaction (`ritual-investing-app/PRODUCT.md:11-17`). Tarot and astrology are framing devices around inspectable market research, not claimed causes of returns. Fictional prices, accounts, payments, and orders must remain visibly Demo (`ritual-investing-app/PRODUCT.md:31-37`). Rowan is the companion voice: warm and explanatory, but explicitly non-advisory and non-coercive (`ritual-investing-app/PRODUCT.md:19-21`, `ritual-investing-app/PRODUCT.md:36-37`).

Prior implementation sessions record a deliberate progression from Tauri and separate native-UI exploration to Flutter, chosen to balance bespoke card interactions, accessibility, cross-platform fidelity, and the cost of maintaining one interface. They also record that a conventional fintech shell with mystical decoration was rejected in favor of an image-first ritual with evidence one gesture away. (session history) These findings explain design rationale; the current source tree remains authoritative for runtime behavior.

The important distinction is between the **implemented scaffold** and the **target product**. The plan describes controllers, domain objects, repositories, a versioned local snapshot, onboarding, Asset Codex, stateful demo transactions, and reset behavior as future architecture (`docs/plans/2026-08-20-1533-feat-standalone-ritual-investing-mobile-app-plan.md:318-343`). None of those layers exists in the current `ritual-investing-app/lib/` tree. The package manifest declares Flutter and Cupertino Icons as its only runtime dependencies, with no network, persistence, state-management, brokerage, payment, or analytics client (`ritual-investing-app/pubspec.yaml:30-47`).

Verification on 2026-08-23 found `flutter analyze` clean and all four tests passing. The checked-in suite covers the initial Ritual content, Coven navigation, theme switching, and deterministic light/dark golden captures (`ritual-investing-app/test/widget_test.dart:6-55`, `ritual-investing-app/test/visual_reference_test.dart:7-76`). This validates the current Dart/widget scaffold, not the unimplemented product layers or native release readiness.

## Guidance

### Read the product as ritual first, with evidence one gesture away

The opening screen begins with a fixed Daily Signal rather than balances or quotes: the Compass art, the interpretation “Direction, not urgency,” and patient-language guidance (`ritual-investing-app/lib/features/ritual/presentation/daily_ritual_screen.dart:61-110`). The Compass art is bundled locally and given explicit image semantics; it is not fetched or generated at runtime (`ritual-investing-app/lib/features/ritual/presentation/daily_ritual_screen.dart:252-277`, `ritual-investing-app/pubspec.yaml:60-70`).

The **Market-informed · reveal the pattern** action opens a modal bottom sheet that separates mystical interpretation from a fixed observation time, named research factors, and an uncertainty statement that the scenario and prices are fictional (`ritual-investing-app/lib/features/ritual/presentation/daily_ritual_screen.dart:135-189`). The visible constellation then presents fixed VIG, XLV, and WOMN examples; these are display-only demo ideas rather than objects backed by a model or live provider (`ritual-investing-app/lib/features/ritual/presentation/daily_ritual_screen.dart:288-350`). The screen closes with Rowan counsel and an educational Demo limitation (`ritual-investing-app/lib/features/ritual/presentation/daily_ritual_screen.dart:118-125`, `ritual-investing-app/lib/features/ritual/presentation/daily_ritual_screen.dart:483-532`).

Preserve that reading order when extending the ritual: emotional framing first, adjacent evidence reveal, explorable ideas, counsel, and limitations in the same flow. This order is an approved design rule, not incidental widget placement (`ritual-investing-app/DESIGN.md:184-190`).

### Understand the current runtime architecture

1. **Entrypoint and app root.** `main()` initializes Flutter and mounts one `RitualInvestingApp` (`ritual-investing-app/lib/main.dart:5-6`). The root is stateful only because it holds an in-memory `ThemeMode`. The default follows the system, and toggling selects the opposite of the brightness currently rendered (`ritual-investing-app/lib/app/ritual_investing_app.dart:6-21`). `MaterialApp` supplies both themes and uses `AppShell` directly as `home`; there is no router configuration (`ritual-investing-app/lib/app/ritual_investing_app.dart:24-33`).

2. **Shell and navigation state.** `AppShell` owns the only other mutable field, `_selectedIndex`, initialized to Ritual at index 0 (`ritual-investing-app/lib/features/shell/presentation/app_shell.dart:20-23`). An `IndexedStack` keeps Ritual, Discover, Coven, and You mounted (`ritual-investing-app/lib/features/shell/presentation/app_shell.dart:27-44`). The Ritual screen can select Coven directly; this is tab selection, not route navigation. Native iOS receives a `CupertinoTabBar`; web, Android, and other targets receive Material `NavigationBar`, with the same four destinations (`ritual-investing-app/lib/features/shell/presentation/app_shell.dart:62-117`).

3. **Presentation-only feature slices.** Each destination is a screen under `lib/features/<feature>/presentation/`, with private file-local widgets. There are no current application, domain, data, controller, model, service, or repository files. Current “data” is literal widget content—for example, the three Grimoires (`ritual-investing-app/lib/features/discover/presentation/discover_screen.dart:40-67`), four Coven companies (`ritual-investing-app/lib/features/coven/presentation/coven_screen.dart:61-94`), and simulated balance and goal progress (`ritual-investing-app/lib/features/profile/presentation/profile_screen.dart:59-92`, `ritual-investing-app/lib/features/profile/presentation/profile_screen.dart:175-207`). Treat these literals as deterministic visual fixtures, not a reusable state model.

4. **Theme and assets.** `RitualColors` is a custom `ThemeExtension` with independently composed light and dark semantic palettes (`ritual-investing-app/lib/app/theme/app_theme.dart:3-61`). `AppTheme` composes those tokens into Material 3 colors, typography, navigation, fields, and bottom-sheet behavior (`ritual-investing-app/lib/app/theme/app_theme.dart:118-239`). Inter, Libre Baskerville, Compass art, and Rowan art are bundled in `pubspec.yaml`; visual changes should use these shared tokens and authorities instead of introducing one-off palettes or fonts (`ritual-investing-app/pubspec.yaml:53-70`).

5. **Native boundary.** Android is an empty `FlutterActivity` subclass, and iOS is a generated `FlutterAppDelegate` with plugin registration. No business workflow is duplicated in Swift or Kotlin (`ritual-investing-app/android/app/src/main/kotlin/com/ritualinvesting/ritual_investing_app/MainActivity.kt:1-5`, `ritual-investing-app/ios/Runner/AppDelegate.swift:1-16`). Bundle identity and release configuration remain provisional scaffold concerns (`ritual-investing-app/README.md:24-28`).

### Be exact about what each destination can do

| Destination | What works now | Current boundary |
| --- | --- | --- |
| Ritual | Scroll the fixed Compass reading, open the evidence sheet, switch theme, and jump to Coven (`ritual-investing-app/lib/features/ritual/presentation/daily_ritual_screen.dart:20-132`). | Date, reading, observation time, evidence, symbols, and changes are constants. There is no ritual selection, astrology mode, asset detail, save, compare, or generated signal. |
| Discover | Browse static Grimoire, Circle, and weekly-omen compositions (`ritual-investing-app/lib/features/discover/presentation/discover_screen.dart:40-119`). | Search is read-only; tiles and rows have no behavior. There is no Asset Codex, saving, copying, editing, search, or community backend (`ritual-investing-app/lib/features/discover/presentation/discover_screen.dart:32-38`, `ritual-investing-app/lib/features/discover/presentation/discover_screen.dart:173-239`). |
| Coven | Browse four fictional companies with separate founder, chief-executive, and ownership labels plus an inline Demo record date (`ritual-investing-app/lib/features/coven/presentation/coven_screen.dart:61-99`, `ritual-investing-app/lib/features/coven/presentation/coven_screen.dart:167-178`). | It is a static directory. No filters, maintained source records, refresh process, or Asset Codex route exists. The screen says live classifications require dated sources (`ritual-investing-app/lib/features/coven/presentation/coven_screen.dart:40-52`). |
| You | View a fixed Demo balance, a fixed Intention, a Future Mirror composition, demo-action rows, and Rowan's agency reminder (`ritual-investing-app/lib/features/profile/presentation/profile_screen.dart:45-169`). | Future Mirror always selects `steady`, selection changes are discarded, and every financial or premium action uses an empty callback (`ritual-investing-app/lib/features/profile/presentation/profile_screen.dart:104-138`, `ritual-investing-app/lib/features/profile/presentation/profile_screen.dart:211-232`). |

The app is therefore local-only in the stronger sense that it currently has **no persistence at all**. Theme choice and selected tab live only in widget memory and return to system theme and Ritual on a fresh process (`ritual-investing-app/lib/app/ritual_investing_app.dart:14-21`, `ritual-investing-app/lib/features/shell/presentation/app_shell.dart:20-23`). The profile's “locally simulated” wording expresses the intended product boundary, but the shown portfolio is compiled-in copy rather than stored local state (`ritual-investing-app/lib/features/profile/presentation/profile_screen.dart:45-70`). Do not claim that money moves, accounts connect, data is live, state survives relaunch, or a complete demo transaction executes.

### Use the plan as intent, not runtime truth

The target product is substantially broader: tarot and astrology modes, three-to-five explorable ideas, Asset Codex, persistent resettable Demo state, onboarding, simulated funding/orders/recurring investing/rebalancing, editable Circles, goals and projections, and simulated freemium (`docs/plans/2026-08-20-1533-feat-standalone-ritual-investing-mobile-app-plan.md:54-123`).

The target layered design is:

```text
presentation widgets
    -> application controllers and immutable view state
    -> pure-Dart domain rules and commands
    -> typed repository contracts
    -> deterministic fixtures + one versioned local snapshot
```

The plan also reserves a typed seam for a future governed market source or Rust engine (`docs/plans/2026-08-20-1533-feat-standalone-ritual-investing-mobile-app-plan.md:318-343`). That is architectural direction for future implementation, not a description of the present tree. A provider should enter through that seam under a separate plan; screens should not call AXIO7, a broker, or a payment service directly (`docs/plans/2026-08-20-1533-feat-standalone-ritual-investing-mobile-app-plan.md:284-297`).

Preserve these boundaries:

- **Standalone:** runtime and build code in `ritual-investing-app/` must not import from, run, or modify AXIO7 or another service tree (`ritual-investing-app/README.md:3`, `docs/plans/2026-08-20-1533-feat-standalone-ritual-investing-mobile-app-plan.md:311-316`).
- **Financial:** no real orders, custody, deposits, withdrawals, account credentials, payments, automatic trading, personalized portfolio management, or advisory activity (`ritual-investing-app/PRODUCT.md:33-37`, `docs/plans/2026-08-20-1533-feat-standalone-ritual-investing-mobile-app-plan.md:93-97`).
- **Truth:** mystical interpretation may frame research but may not hide evidence, uncertainty, timing, risk, Demo status, or claim supernatural causation (`ritual-investing-app/PRODUCT.md:31-37`).
- **Agency:** Rowan explains and reassures but never decides or uses affection, exclusivity, jealousy, urgency, or sexual pressure to influence a financial decision (`ritual-investing-app/PRODUCT.md:36-37`, `docs/plans/2026-08-20-1533-feat-standalone-ritual-investing-mobile-app-plan.md:79-83`).
- **Platform:** one shared Dart product UI preserves the information architecture while navigation, touch targets, gestures, accessibility, and safe areas remain native-feeling (`ritual-investing-app/PRODUCT.md:35`, `ritual-investing-app/DESIGN.md:184-190`).
- **Visual:** the Compass and Rowan assets plus `docs/visual-references/standalone-ritual-investing/` remain review authorities; golden changes require intentional comparison (`ritual-investing-app/README.md:22`, `docs/visual-references/standalone-ritual-investing/README.md:3-15`).

## Why This Matters

Without this baseline, “implemented,” “demo,” and “planned” are easy to conflate. The UI is polished enough that its destinations can look complete during visual review, but many controls are read-only or no-op and every financial value is a constant. Calling those screens locally stateful would hide the largest remaining engineering step: establishing domain commands, derived state, persistence, and focused navigation without weakening the disclosure contract.

The scaffold is still valuable architecture. It demonstrates the differentiating product loop—the ritual catches attention, evidence makes the framing accountable, and exploration remains non-transactional—while proving one shared Flutter UI can preserve the approved light and dark composition. Golden tests pin both atmospheres at a deterministic surface and preload fonts and art before capture (`ritual-investing-app/test/visual_reference_test.dart:11-69`). Prior sessions show why those details matter: early captures raced image decoding or used fallback glyphs, and the stable baselines required bundled fonts, pre-cached art, and warmed theme frames. (session history)

The hard boundary against real financial activity is a product safety invariant, not merely a missing integration. New work should deepen the coherent simulation and evidence model before broadening external connectivity.

## When to Apply

- **Onboarding into the app:** distinguish the working UI contract from the plan's future layers and flows.
- **Estimating a feature:** decide whether it is a presentation change within the scaffold or the start of application, domain, and data architecture. Persistence, Asset Codex, Circle editing, projections, and entitlements are the latter.
- **Changing Ritual content or evidence:** preserve the one-gesture evidence reveal, observation context, uncertainty, non-prescriptive language, and visible Demo status.
- **Adding a provider or native integration:** keep business logic in Dart behind a typed boundary; do not couple a screen directly to AXIO7, a broker, a payment service, or a native host.
- **Reviewing completeness:** require interactive behavior, coherent state transitions, relaunch behavior, and relevant tests. Visual presence alone does not satisfy a planned workflow.

## Examples

### The user flow that works today

1. Launch follows the device theme and lands on Ritual (`ritual-investing-app/lib/app/ritual_investing_app.dart:14-32`, `ritual-investing-app/lib/features/shell/presentation/app_shell.dart:20-39`).
2. Read the fixed Compass interpretation and tap **Market-informed · reveal the pattern** to open fixed factors, a fixed observation time, and uncertainty (`ritual-investing-app/lib/features/ritual/presentation/daily_ritual_screen.dart:74-110`, `ritual-investing-app/lib/features/ritual/presentation/daily_ritual_screen.dart:135-183`).
3. Dismiss the sheet, inspect the three demo ideas, then tap **Founders' Coven** to select tab index 2 (`ritual-investing-app/lib/features/ritual/presentation/daily_ritual_screen.dart:288-350`, `ritual-investing-app/lib/features/shell/presentation/app_shell.dart:27-35`).
4. Browse four fictional, categorized records; use bottom navigation to view the static Discover and You previews (`ritual-investing-app/lib/features/coven/presentation/coven_screen.dart:61-99`, `ritual-investing-app/lib/features/shell/presentation/app_shell.dart:71-117`).
5. Toggle the theme from Ritual if desired. It changes immediately but is not persisted across a process restart (`ritual-investing-app/lib/features/ritual/presentation/daily_ritual_screen.dart:38-50`, `ritual-investing-app/lib/app/ritual_investing_app.dart:14-21`).

### Where to change what

| Change | Current source of truth | Caution |
| --- | --- | --- |
| Startup, title, root theme mode | `ritual-investing-app/lib/main.dart:5`; `ritual-investing-app/lib/app/ritual_investing_app.dart:13-33` | Persisting theme introduces a data concern; the existing toggle is in-memory only. |
| Top-level destinations and adaptive tab navigation | `ritual-investing-app/lib/features/shell/presentation/app_shell.dart:20-117` | Focused flows need an explicit navigation design; the shell currently changes indices only. |
| Daily reading, evidence, constellation, Rowan, Coven shortcut | `ritual-investing-app/lib/features/ritual/presentation/daily_ritual_screen.dart:5-532` | Extract typed fixtures and domain state before making scenarios mutable or provider-backed. |
| Grimoires, Circles, and search preview | `ritual-investing-app/lib/features/discover/presentation/discover_screen.dart:5-240` | Adding callbacks alone is not an Asset Codex or state model. |
| Women-led directory and category/date display | `ritual-investing-app/lib/features/coven/presentation/coven_screen.dart:5-187` | Live claims need dated, maintained sourcing; current companies are fictional. |
| Balance, Intention, Future Mirror, and demo action previews | `ritual-investing-app/lib/features/profile/presentation/profile_screen.dart:5-233` | All values are constants and actions no-op; introduce commands and one derived-state path before edits. |
| Semantic palette and component theming | `ritual-investing-app/lib/app/theme/app_theme.dart:3-239`; `ritual-investing-app/DESIGN.md:1-209` | Preserve independently composed light/dark tokens and non-color meaning. |
| Behavior and visual regression coverage | `ritual-investing-app/test/widget_test.dart:6-55`; `ritual-investing-app/test/visual_reference_test.dart:7-76` | Add domain/state tests before persistence or simulations; inspect golden changes rather than regenerating blindly. |

### How to approach the next stateful slice

If the next request is “make recurring ritual update the portfolio,” do not implement it directly in `_ActionRow.onTap`; that callback is currently empty (`ritual-investing-app/lib/features/profile/presentation/profile_screen.dart:211-232`). First establish a typed recurring-plan command, pure-Dart validation and accounting, immutable view state, a repository-backed local snapshot, and controller coordination. Then bind the row to that intent and verify that cash, holdings, history, allocation, and projections derive from the same transition. This follows the plan's rule that screens must not patch totals or projections independently (`docs/plans/2026-08-20-1533-feat-standalone-ritual-investing-mobile-app-plan.md:338-343`).

## Related

- `ritual-investing-app/PRODUCT.md` — product intent and safety authority.
- `ritual-investing-app/DESIGN.md` — design-system and interaction authority.
- `ritual-investing-app/README.md` — concise current-scaffold inventory and verification commands.
- `docs/visual-references/standalone-ritual-investing/README.md` — approved visual-reference ownership and review policy.
- `docs/plans/2026-08-20-1533-feat-standalone-ritual-investing-mobile-app-plan.md` — product contract and target architecture; do not read planned layers as current implementation.
- No related GitHub issues were found for the query `ritual investing architecture` on 2026-08-23.
