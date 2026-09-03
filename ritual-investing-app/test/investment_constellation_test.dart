import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/features/starpath/domain/investment_constellation.dart';
import 'package:ritual_investing_app/features/starpath/domain/starpath.dart';

import 'support/starpath_test_fixture.dart';

void main() {
  test('projects eight technical nodes into four named constellations', () {
    final snapshot = starpathFixtureSnapshot(currentOrdinal: 3);

    final constellations = projectInvestmentConstellations(snapshot);

    expect(constellations, hasLength(4));
    expect(
      constellations
          .map((constellation) => constellation.displayIndex)
          .toList(),
      [1, 2, 3, 4],
    );
    expect(
      constellations.map((constellation) => constellation.title).toList(),
      [
        'Market Basics',
        'The Art of Investing',
        'Portfolio & Risk',
        'Practice Investing',
      ],
    );
    expect(
      constellations.map((constellation) => constellation.leoSubtitle).toList(),
      [
        'The Financial Universe',
        'The Long View',
        'The Shield',
        'The First Voyage',
      ],
    );
    expect(
      constellations.map((constellation) => constellation.summary),
      everyElement(isNotEmpty),
    );
  });

  test('preserves node and lesson order with backend identity attached', () {
    final snapshot = starpathFixtureSnapshot(currentOrdinal: 3);

    final second = projectInvestmentConstellationsFromNodes(snapshot.nodes)[1];

    expect(second.nodes, [snapshot.nodes[2], snapshot.nodes[3]]);
    expect(second.lessons.map((entry) => entry.node.lessonId).toList(), [
      ...List.filled(
        snapshot.nodes[2].factualSections.length,
        snapshot.nodes[2].lessonId,
      ),
      ...List.filled(
        snapshot.nodes[3].factualSections.length,
        snapshot.nodes[3].lessonId,
      ),
    ]);
    expect(
      second.lessons
          .where((entry) => identical(entry.node, snapshot.nodes[3]))
          .map((entry) => entry.sectionIndex)
          .toList(),
      List.generate(snapshot.nodes[3].factualSections.length, (index) => index),
    );
    expect(
      identical(
        second.lessons.last.section,
        snapshot.nodes[3].factualSections.last,
      ),
      isTrue,
    );
  });

  test('aggregates completed, current, and open states', () {
    final constellations = projectInvestmentConstellations(
      starpathFixtureSnapshot(currentOrdinal: 3),
    );

    expect(
      constellations.map((constellation) => constellation.state).toList(),
      [
        InvestmentConstellationState.completed,
        InvestmentConstellationState.current,
        InvestmentConstellationState.open,
        InvestmentConstellationState.open,
      ],
    );
    expect(constellations[0].progress.isComplete, isTrue);
    expect(constellations[0].progress.fraction, 1);
    expect(constellations[1].progress.completedNodeCount, 0);
    expect(constellations[1].progress.completedLessonCount, 0);
    expect(constellations[1].progress.fraction, 0);
  });

  test('counts only lessons in backend-completed nodes as progress', () {
    final constellation = projectInvestmentConstellations(
      starpathFixtureSnapshot(currentOrdinal: 2),
    ).first;
    final firstNodeLessonCount =
        constellation.nodes.first.factualSections.length;

    expect(constellation.state, InvestmentConstellationState.current);
    expect(constellation.progress.completedNodeCount, 1);
    expect(constellation.progress.completedLessonCount, firstNodeLessonCount);
    expect(
      constellation.progress.fraction,
      firstNodeLessonCount / constellation.lessons.length,
    );
  });

  test('selects the node that owns the authoritative knowledge check', () {
    final active = projectInvestmentConstellations(
      starpathFixtureSnapshot(currentOrdinal: 4),
    )[1];
    final unopened = projectInvestmentConstellations(
      starpathFixtureSnapshot(currentOrdinal: 3),
    )[2];
    final completed = projectInvestmentConstellations(
      starpathFixtureSnapshot(currentOrdinal: 9),
    ).last;

    expect(active.authoritativeCheckNode.nodeOrdinal, 4);
    expect(unopened.authoritativeCheckNode.nodeOrdinal, 5);
    expect(completed.authoritativeCheckNode.nodeOrdinal, 8);
  });

  test('returns immutable constellation, node, and lesson lists', () {
    final constellations = projectInvestmentConstellations(
      starpathFixtureSnapshot(currentOrdinal: 3),
    );

    expect(
      () => constellations.add(constellations.first),
      throwsUnsupportedError,
    );
    expect(
      () => constellations.first.nodes.add(constellations.first.nodes.first),
      throwsUnsupportedError,
    );
    expect(
      () =>
          constellations.first.lessons.add(constellations.first.lessons.first),
      throwsUnsupportedError,
    );
  });

  test('rejects snapshots outside the eight-node contract', () {
    final complete = starpathFixtureSnapshot(currentOrdinal: 3);
    final malformed = StarpathSnapshot(
      availability: complete.availability,
      version: complete.version,
      authority: complete.authority,
      nodes: complete.nodes.take(7).toList(),
      session: complete.session,
      progress: complete.progress,
      theme: complete.theme,
      recall: complete.recall,
    );

    expect(
      () => projectInvestmentConstellations(malformed),
      throwsArgumentError,
    );
  });
}
