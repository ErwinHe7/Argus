import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/features/ritual/domain/daily_ritual.dart';
import 'package:ritual_investing_app/features/ritual/presentation/ritual_tarot_art.dart';

void main() {
  test('the bundled Major Arcana catalog contains 22 unique assets', () {
    expect(majorArcanaArtwork, hasLength(22));
    expect(
      majorArcanaArtwork.map((artwork) => artwork.key).toSet(),
      hasLength(22),
    );
    expect(
      majorArcanaArtwork.map((artwork) => artwork.assetPath).toSet(),
      hasLength(22),
    );

    for (final artwork in majorArcanaArtwork) {
      expect(
        artwork.assetPath,
        startsWith('assets/images/tarot/modern-rider-waite/major/'),
        reason: 'Daily Ritual must use the direct-modernization deck',
      );
      expect(
        File(artwork.assetPath).existsSync(),
        isTrue,
        reason: '${artwork.assetPath} must be bundled with the app',
      );

      final fileName = artwork.assetPath.split('/').last;
      final reservePath = 'assets/images/tarot/modern-vector/major/$fileName';
      expect(
        File(reservePath).existsSync(),
        isTrue,
        reason: '$reservePath must remain bundled as the reserve deck',
      );
    }
  });

  test('an explicit Major Arcana key resolves independently of the date', () {
    final first = resolveRitualTarotArtwork(
      art: const RitualArt(key: 'the_star', alt: 'Legacy alt text'),
      date: DateTime(2026, 8, 26),
      mode: DailyRitualMode.tarot,
    );
    final second = resolveRitualTarotArtwork(
      art: const RitualArt(key: 'the_star', alt: 'Legacy alt text'),
      date: DateTime(2030, 1, 1),
      mode: DailyRitualMode.tarot,
    );

    expect(first, isNotNull);
    expect(first?.key, 'the_star');
    expect(first?.title, 'The Star');
    expect(
      first?.assetPath,
      'assets/images/tarot/modern-rider-waite/major/17-the-star.webp',
    );
    expect(second, same(first));
  });

  test('the legacy compass key cannot synthesize a second card assignment', () {
    final morning = resolveRitualTarotArtwork(
      art: const RitualArt(key: 'the_compass', alt: 'The Compass'),
      date: DateTime(2026, 8, 26, 8),
      mode: DailyRitualMode.tarot,
    );
    final evening = resolveRitualTarotArtwork(
      art: const RitualArt(key: 'the_compass', alt: 'The Compass'),
      date: DateTime(2026, 8, 26, 22),
      mode: DailyRitualMode.tarot,
    );
    final nextDay = resolveRitualTarotArtwork(
      art: const RitualArt(key: 'the_compass', alt: 'The Compass'),
      date: DateTime(2026, 8, 27),
      mode: DailyRitualMode.tarot,
    );

    expect(morning, isNull);
    expect(evening, isNull);
    expect(nextDay, isNull);
  });

  test('supported modes resolve the exact assigned tarot art key', () {
    final unknown = resolveRitualTarotArtwork(
      art: const RitualArt(key: 'future_art', alt: 'Future art'),
      date: DateTime(2026, 8, 26),
      mode: DailyRitualMode.tarot,
    );
    final astrology = resolveRitualTarotArtwork(
      art: const RitualArt(key: 'the_star', alt: 'The Star'),
      date: DateTime(2026, 8, 26),
      mode: DailyRitualMode.astrology,
    );

    expect(unknown, isNull);
    expect(astrology, isNotNull);
    expect(astrology?.key, 'the_star');
    expect(
      astrology?.assetPath,
      'assets/images/tarot/modern-rider-waite/major/17-the-star.webp',
    );

    for (final mode in const [
      DailyRitualMode.tarot,
      DailyRitualMode.astrology,
    ]) {
      for (final expected in majorArcanaArtwork) {
        final resolved = resolveRitualTarotArtwork(
          art: RitualArt(key: expected.key, alt: expected.alt),
          date: DateTime(2026, 8, 26),
          mode: mode,
        );
        expect(
          resolved,
          same(expected),
          reason: '${mode.name}:${expected.key}',
        );
      }
    }
  });

  test('missing and unknown art keys fail closed without substitution', () {
    for (final key in ['', 'future_art', 'the_compass']) {
      final artwork = resolveRitualTarotArtwork(
        art: RitualArt(key: key, alt: 'Unavailable assigned art'),
        date: DateTime(2026, 8, 26),
        mode: DailyRitualMode.tarot,
      );

      expect(artwork, isNull, reason: '$key must not select fallback art');
    }
  });
}
