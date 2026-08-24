# Ritual Investing

Standalone Flutter application for the ritual-first investing product. The app ships one shared Dart UI to iOS and Android and does not import from, run, or modify the AXIO7 research services.

## Current scaffold

- Adaptive iOS/Android bottom navigation with Ritual, Discover, Coven, and You destinations.
- Approved lunar-lilac and aubergine-night themes with a working theme control.
- Daily Compass ritual using the preserved generated artwork.
- Inspectable `Market-informed` explanation sheet and explicit Demo limitations.
- Grimoires, Circles, Founders’ Coven, portfolio, Intentions, Future Mirror, recurring-investing, rebalancing, and premium preview stubs.
- Rowan counsel using the preserved portrait study.
- Widget tests plus deterministic light/dark visual-regression captures.

## Local checks

```sh
flutter analyze
flutter test
```

The visual baselines live under `test/goldens/`. Regenerate them only after comparing the result with the approved authority at `../docs/visual-references/standalone-ritual-investing/approved-light-dark-reference.html`.

## Native prerequisites

The project includes generated `ios/` and `android/` hosts. Device builds additionally require full Xcode and CocoaPods for iOS, plus Android Studio/SDK for Android. Run `flutter doctor -v` after installing them.

The bundle identifiers generated for the working scaffold are provisional until the product name and store identity are finalized.
