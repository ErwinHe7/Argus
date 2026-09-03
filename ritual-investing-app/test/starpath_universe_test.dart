import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/features/starpath/domain/starpath_universe.dart';

void main() {
  group('Starpath universe catalog', () {
    test('offers both disciplines without coupling their progress', () {
      expect(starpathUniverses.map((universe) => universe.id), [
        StarpathUniverseId.invest,
        StarpathUniverseId.trade,
      ]);
      expect(
        starpathUniverses.map((universe) => universe.id).toSet(),
        hasLength(2),
      );
      expect(
        starpathUniverseFor(StarpathUniverseId.invest),
        same(investStarpathUniverse),
      );
      expect(
        starpathUniverseFor(StarpathUniverseId.trade),
        same(tradeStarpathUniverse),
      );
    });

    test('Investment is available with four focused constellations', () {
      expect(investStarpathUniverse.canOpenLessons, isTrue);
      expect(investStarpathUniverse.isRoadmapOnly, isFalse);
      expect(investStarpathUniverse.title, 'Investment');
      expect(investStarpathUniverse.roadmap, hasLength(4));
      expect(investStarpathUniverse.roadmap.map((stop) => stop.title), [
        'Market Basics',
        'The Art of Investing',
        'Portfolio & Risk',
        'Practice Investing',
      ]);
      expect(investStarpathUniverse.roadmap.map((stop) => stop.subtitle), [
        'The Financial Universe',
        'The Long View',
        'The Shield',
        'The First Voyage',
      ]);
    });

    test('Trading is a four-constellation preview, not fake lesson access', () {
      expect(tradeStarpathUniverse.canOpenLessons, isFalse);
      expect(tradeStarpathUniverse.isRoadmapOnly, isTrue);
      expect(tradeStarpathUniverse.title, 'Trading');
      expect(tradeStarpathUniverse.roadmap, hasLength(4));
      expect(tradeStarpathUniverse.roadmap.map((stop) => stop.title), [
        'Reading the Market',
        'Price Action',
        'Execution & Risk',
        'Advanced Markets',
      ]);
      expect(
        tradeStarpathUniverse.roadmap.last.subtitle,
        'Options · futures · gold · crypto',
      );
    });

    test('catalog and roadmap collections cannot be mutated', () {
      expect(
        () => starpathUniverses.add(investStarpathUniverse),
        throwsUnsupportedError,
      );
      expect(
        () => tradeStarpathUniverse.roadmap.add(
          const StarpathRoadmapStop(
            id: 'extra',
            title: 'Extra',
            subtitle: 'Not part of the roadmap',
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
