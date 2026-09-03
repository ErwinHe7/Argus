import 'package:flutter/foundation.dart';
import 'package:ritual_investing_app/features/starpath/domain/starpath.dart';

/// The display-level state of one Investment constellation.
///
/// Technical Starpath nodes may still carry [StarpathNodeState.locked] because
/// the API uses that value to describe sequence. The Investment learning path
/// is open-access, so the presentation projection deliberately exposes those
/// groups as [open] instead of as unavailable content.
enum InvestmentConstellationState { completed, current, open }

@immutable
class InvestmentLessonEntry {
  const InvestmentLessonEntry({required this.node, required this.sectionIndex});

  /// The API node that owns this lesson and its knowledge check.
  final StarpathNode node;

  /// Zero-based position inside [StarpathNode.factualSections].
  final int sectionIndex;

  StarpathFactualSection get section => node.factualSections[sectionIndex];

  bool get isCompleted => node.state == StarpathNodeState.completed;
}

@immutable
class InvestmentConstellationProgress {
  const InvestmentConstellationProgress({
    required this.completedNodeCount,
    required this.totalNodeCount,
    required this.completedLessonCount,
    required this.totalLessonCount,
  });

  final int completedNodeCount;
  final int totalNodeCount;
  final int completedLessonCount;
  final int totalLessonCount;

  /// Progress the current API contract can state authoritatively.
  ///
  /// The backend tracks completion at node level, not at factual-section level.
  /// A completed node therefore contributes all of its lessons; a current node
  /// contributes none until the backend reports it completed.
  double get fraction =>
      totalLessonCount == 0 ? 0 : completedLessonCount / totalLessonCount;

  bool get isComplete =>
      totalNodeCount > 0 && completedNodeCount == totalNodeCount;
}

@immutable
class InvestmentConstellation {
  InvestmentConstellation({
    required this.displayIndex,
    required this.title,
    required this.leoSubtitle,
    required this.summary,
    required List<StarpathNode> nodes,
    required List<InvestmentLessonEntry> lessons,
    required this.state,
    required this.progress,
    required this.authoritativeCheckNode,
  }) : nodes = List.unmodifiable(nodes),
       lessons = List.unmodifiable(lessons);

  /// One-based position in the four-constellation Investment path.
  final int displayIndex;
  final String title;
  final String leoSubtitle;
  final String summary;

  /// The two adjacent API nodes represented by this display constellation.
  final List<StarpathNode> nodes;

  /// All sections from [nodes], in node order and then section order.
  final List<InvestmentLessonEntry> lessons;

  final InvestmentConstellationState state;
  final InvestmentConstellationProgress progress;

  /// The API node whose knowledge check should be submitted for this group.
  ///
  /// This is the current node when present, otherwise the first unfinished
  /// node, or the final node after the whole constellation is completed.
  final StarpathNode authoritativeCheckNode;
}

@immutable
class _InvestmentConstellationDefinition {
  const _InvestmentConstellationDefinition({
    required this.title,
    required this.leoSubtitle,
    required this.summary,
  });

  final String title;
  final String leoSubtitle;
  final String summary;
}

const _definitions = [
  _InvestmentConstellationDefinition(
    title: 'Market Basics',
    leoSubtitle: 'The Financial Universe',
    summary: 'What investing is, what a stock is, and how the market works.',
  ),
  _InvestmentConstellationDefinition(
    title: 'The Art of Investing',
    leoSubtitle: 'The Long View',
    summary:
        'Indexes, ETFs, baskets, and three habits for long-term investing.',
  ),
  _InvestmentConstellationDefinition(
    title: 'Portfolio & Risk',
    leoSubtitle: 'The Shield',
    summary: 'Portfolios, allocation, drawdowns, and how compounding works.',
  ),
  _InvestmentConstellationDefinition(
    title: 'Practice Investing',
    leoSubtitle: 'The First Voyage',
    summary: 'Use the basics to walk through a first investment without placing a real trade.',
  ),
];

/// Projects the eight API-owned Starpath nodes into four Investment
/// constellations without changing backend identity or command authority.
List<InvestmentConstellation> projectInvestmentConstellations(
  StarpathSnapshot snapshot,
) => projectInvestmentConstellationsFromNodes(snapshot.nodes);

/// Node-only entry point for presentation widgets that already receive the
/// validated Starpath node list rather than the enclosing snapshot.
List<InvestmentConstellation> projectInvestmentConstellationsFromNodes(
  List<StarpathNode> nodes,
) {
  if (nodes.length != _definitions.length * 2) {
    throw ArgumentError.value(
      nodes.length,
      'nodes.length',
      'Investment Starpath requires exactly eight technical nodes.',
    );
  }

  return List<InvestmentConstellation>.unmodifiable([
    for (var index = 0; index < _definitions.length; index += 1)
      _projectConstellation(
        displayIndex: index + 1,
        definition: _definitions[index],
        nodes: nodes.sublist(index * 2, index * 2 + 2),
      ),
  ]);
}

InvestmentConstellation _projectConstellation({
  required int displayIndex,
  required _InvestmentConstellationDefinition definition,
  required List<StarpathNode> nodes,
}) {
  final lessons = [
    for (final node in nodes)
      for (
        var sectionIndex = 0;
        sectionIndex < node.factualSections.length;
        sectionIndex += 1
      )
        InvestmentLessonEntry(node: node, sectionIndex: sectionIndex),
  ];
  final completedNodes = nodes
      .where((node) => node.state == StarpathNodeState.completed)
      .length;
  final completedLessons = nodes
      .where((node) => node.state == StarpathNodeState.completed)
      .fold<int>(0, (total, node) => total + node.factualSections.length);

  return InvestmentConstellation(
    displayIndex: displayIndex,
    title: definition.title,
    leoSubtitle: definition.leoSubtitle,
    summary: definition.summary,
    nodes: nodes,
    lessons: lessons,
    state: _stateFor(nodes, completedNodes),
    progress: InvestmentConstellationProgress(
      completedNodeCount: completedNodes,
      totalNodeCount: nodes.length,
      completedLessonCount: completedLessons,
      totalLessonCount: lessons.length,
    ),
    authoritativeCheckNode: _authoritativeCheckNode(nodes),
  );
}

InvestmentConstellationState _stateFor(
  List<StarpathNode> nodes,
  int completedNodeCount,
) {
  if (completedNodeCount == nodes.length) {
    return InvestmentConstellationState.completed;
  }
  if (completedNodeCount > 0 ||
      nodes.any((node) => node.state == StarpathNodeState.current)) {
    return InvestmentConstellationState.current;
  }
  return InvestmentConstellationState.open;
}

StarpathNode _authoritativeCheckNode(List<StarpathNode> nodes) {
  for (final node in nodes) {
    if (node.state == StarpathNodeState.current) return node;
  }
  for (final node in nodes) {
    if (node.state != StarpathNodeState.completed) return node;
  }
  return nodes.last;
}
