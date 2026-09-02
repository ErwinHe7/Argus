import 'package:flutter/foundation.dart';

/// The two learning disciplines presented inside Starpath.
///
/// A learner may move between them freely. Progress is intentionally owned by
/// each discipline's learning experience instead of this catalog model.
enum StarpathUniverseId { invest, trade }

/// Product access is separate from curriculum copy so it can later be driven
/// by an entitlement service without adding prices to the client.
enum StarpathUniverseAccess { available, roadmapPreview, locked }

@immutable
class StarpathRoadmapStop {
  const StarpathRoadmapStop({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;
}

@immutable
class StarpathUniverseDefinition {
  StarpathUniverseDefinition({
    required this.id,
    required this.title,
    required this.introduction,
    required this.topicSummary,
    required this.primaryActionLabel,
    required this.access,
    required List<StarpathRoadmapStop> roadmap,
  }) : roadmap = List.unmodifiable(roadmap);

  final StarpathUniverseId id;
  final String title;
  final String introduction;
  final String topicSummary;
  final String primaryActionLabel;
  final StarpathUniverseAccess access;
  final List<StarpathRoadmapStop> roadmap;

  bool get canOpenLessons => access == StarpathUniverseAccess.available;

  bool get isRoadmapOnly => access == StarpathUniverseAccess.roadmapPreview;
}

final investStarpathUniverse = StarpathUniverseDefinition(
  id: StarpathUniverseId.invest,
  title: 'Investment',
  introduction: 'Learn how to build and understand long-term investments.',
  topicSummary: 'Stocks · Indexes · ETFs · Portfolios',
  primaryActionLabel: 'Explore Investment',
  access: StarpathUniverseAccess.available,
  roadmap: const [
    StarpathRoadmapStop(
      id: 'market-basics',
      title: 'Market Basics',
      subtitle: 'The Financial Universe',
    ),
    StarpathRoadmapStop(
      id: 'art-of-investing',
      title: 'The Art of Investing',
      subtitle: 'The Long View',
    ),
    StarpathRoadmapStop(
      id: 'portfolio-risk',
      title: 'Portfolio & Risk',
      subtitle: 'The Shield',
    ),
    StarpathRoadmapStop(
      id: 'practice-investing',
      title: 'Practice Investing',
      subtitle: 'The First Voyage',
    ),
  ],
);

final tradeStarpathUniverse = StarpathUniverseDefinition(
  id: StarpathUniverseId.trade,
  title: 'Trading',
  introduction: 'Learn how to read markets and actively trade price movement.',
  topicSummary: 'Charts · Price action · Orders · Risk',
  primaryActionLabel: 'View Trading roadmap',
  access: StarpathUniverseAccess.roadmapPreview,
  roadmap: const [
    StarpathRoadmapStop(
      id: 'reading-the-market',
      title: 'Reading the Market',
      subtitle: 'Candles · timeframes · volume',
    ),
    StarpathRoadmapStop(
      id: 'price-action',
      title: 'Price Action',
      subtitle: 'Trends · ranges · support · resistance',
    ),
    StarpathRoadmapStop(
      id: 'execution-risk',
      title: 'Execution & Risk',
      subtitle: 'Orders · stops · position size · risk/reward',
    ),
    StarpathRoadmapStop(
      id: 'advanced-markets',
      title: 'Advanced Markets',
      subtitle: 'Options · futures · gold · crypto',
    ),
  ],
);

final starpathUniverses = List<StarpathUniverseDefinition>.unmodifiable([
  investStarpathUniverse,
  tradeStarpathUniverse,
]);

StarpathUniverseDefinition starpathUniverseFor(StarpathUniverseId id) =>
    starpathUniverses.firstWhere((universe) => universe.id == id);
