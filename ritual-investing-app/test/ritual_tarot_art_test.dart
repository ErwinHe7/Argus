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

  test('the legacy compass key deterministically rotates by calendar date', () {
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

    expect(morning, isNotNull);
    expect(evening, same(morning));
    expect(nextDay, isNot(same(morning)));
  });

  test('unknown keys and non-tarot rituals retain the existing fallback', () {
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
    expect(astrology, isNull);
  });
}
