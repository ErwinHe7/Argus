import 'package:ritual_investing_app/features/starpath/domain/starpath.dart';

import 'starpath_test_fixture.dart';

/// Only tests use this adapter; production fixture identities are never inferred
/// from titles or node position by the story resolver.
StarpathSnapshot pilotSnapshot({String? revision}) {
  final base = starpathFixtureSnapshot(currentOrdinal: 1);
  return StarpathSnapshot(
    availability: base.availability,
    version: base.version,
    authority: const StarpathAuthority(
      environment: StarpathEnvironment.beta,
      jurisdiction: 'US',
      capabilityVersion: 1,
      policyVersion: 'starpath-no-advice-v1',
      manifestId: 'fixture-manifest',
      manifestVersion: 'fixture-v1',
    ),
    session: base.session,
    progress: base.progress,
    theme: base.theme,
    recall: base.recall,
    nodes: [
      for (final node in base.nodes)
        StarpathNode(
          lessonId: 'fixture-lesson-${node.nodeOrdinal}',
          revisionId: revision ?? 'fixture-revision-${node.nodeOrdinal}',
          nodeOrdinal: node.nodeOrdinal,
          pathwayOrdinal: node.pathwayOrdinal,
          pathwayPosition: node.pathwayPosition,
          title: node.title,
          mythicMnemonic: node.mythicMnemonic,
          factualSummary: node.factualSummary,
          materialLimitations: node.materialLimitations,
          riskContext: node.riskContext,
          recallPrompt: node.recallPrompt,
          rowanExplanation: node.rowanExplanation,
          guide: node.guide,
          factualSections: node.factualSections,
          knowledgeCheck: node.knowledgeCheck,
          state: node.state,
        ),
    ],
  );
}
