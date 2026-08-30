import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/features/ritual/presentation/ritual_tarot_art.dart';
import 'package:ritual_investing_app/features/starpath/presentation/starpath_tarot_art.dart';

void main() {
  test('Starpath uses the complete Daily Ritual Major Arcana deck', () {
    expect(majorArcanaArtwork, hasLength(22));

    for (final artwork in majorArcanaArtwork) {
      final starpathKey = artwork.key.replaceAll('_', '-');
      expect(resolveStarpathTarotArtwork(starpathKey), same(artwork));
    }
  });

  test('unknown guide keys retain The Star fallback', () {
    final fallback = resolveStarpathTarotArtwork('future-guide');

    expect(fallback.key, 'the_star');
  });
}
