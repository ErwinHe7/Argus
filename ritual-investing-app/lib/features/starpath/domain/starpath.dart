import 'package:flutter/foundation.dart';

const draftPreviewStarpathManifestVersion =
    'draft-preview-starpath-curriculum-v2';

enum StarpathAvailability { available, notStarted }

enum StarpathEnvironment { beta, production }

enum StarpathNodeState { completed, current, locked }

enum StarpathSessionState { active, closed, replaced }

enum StarpathFactualSectionKind { fact, neutralExample }

enum StarpathAttemptKind { node, recall }

enum StarpathCommandEffect {
  started,
  resumed,
  contentReplaced,
  wrongAnswer,
  lessonCompleted,
  recallCompleted,
  recallSkipped,
  semanticReplay,
  idempotentReplay,
}

@immutable
class StarpathAuthority {
  const StarpathAuthority({
    required this.environment,
    required this.jurisdiction,
    required this.capabilityVersion,
    required this.policyVersion,
    required this.manifestId,
    required this.manifestVersion,
  });

  final StarpathEnvironment environment;
  final String jurisdiction;
  final int capabilityVersion;
  final String policyVersion;
  final String manifestId;
  final String manifestVersion;
}

@immutable
class StarpathTheme {
  const StarpathTheme({
    required this.id,
    required this.key,
    required this.title,
    required this.horoscopeFrame,
    required this.factualFocus,
    required this.accessibleLabel,
  });

  final String id;
  final String key;
  final String title;
  final String horoscopeFrame;
  final String factualFocus;
  final String accessibleLabel;
}

@immutable
class StarpathGuide {
  const StarpathGuide({required this.tarotKey, required this.accessibleLabel});

  final String tarotKey;
  final String accessibleLabel;
}

@immutable
class StarpathEvidence {
  const StarpathEvidence({
    required this.ordinal,
    required this.publisher,
    required this.sourceTitle,
    required this.canonicalUrl,
    required this.claimSummary,
    required this.retrievedAt,
    required this.sourceObservedAt,
    required this.currentUntil,
    this.effectiveAt,
  });

  final int ordinal;
  final String publisher;
  final String sourceTitle;
  final Uri canonicalUrl;
  final String claimSummary;
  final DateTime retrievedAt;
  final DateTime sourceObservedAt;
  final DateTime currentUntil;
  final DateTime? effectiveAt;
}

@immutable
class StarpathFactualSection {
  StarpathFactualSection({
    required this.ordinal,
    required this.kind,
    required this.heading,
    required this.body,
    required this.observedAt,
    required this.uncertainty,
    required List<StarpathEvidence> evidence,
  }) : evidence = List.unmodifiable(evidence);

  final int ordinal;
  final StarpathFactualSectionKind kind;
  final String heading;
  final String body;
  final DateTime observedAt;
  final String uncertainty;
  final List<StarpathEvidence> evidence;
}

@immutable
class StarpathKnowledgeCheckOption {
  const StarpathKnowledgeCheckOption({
    required this.id,
    required this.ordinal,
    required this.label,
  });

  final String id;
  final int ordinal;
  final String label;
}

@immutable
class StarpathKnowledgeCheck {
  StarpathKnowledgeCheck({
    required this.id,
    required this.prompt,
    required List<StarpathKnowledgeCheckOption> options,
  }) : options = List.unmodifiable(options);

  final String id;
  final String prompt;
  final List<StarpathKnowledgeCheckOption> options;
}

@immutable
class StarpathNode {
  StarpathNode({
    required this.lessonId,
    required this.revisionId,
    required this.nodeOrdinal,
    required this.pathwayOrdinal,
    required this.pathwayPosition,
    required this.title,
    required this.mythicMnemonic,
    required this.factualSummary,
    required this.materialLimitations,
    required this.riskContext,
    required this.recallPrompt,
    required this.rowanExplanation,
    required this.guide,
    required List<StarpathFactualSection> factualSections,
    required this.knowledgeCheck,
    required this.state,
  }) : factualSections = List.unmodifiable(factualSections);

  final String lessonId;
  final String revisionId;
  final int nodeOrdinal;
  final int pathwayOrdinal;
  final int pathwayPosition;
  final String title;
  final String mythicMnemonic;
  final String factualSummary;
  final String materialLimitations;
  final String riskContext;
  final String recallPrompt;
  final String rowanExplanation;
  final StarpathGuide guide;
  final List<StarpathFactualSection> factualSections;
  final StarpathKnowledgeCheck knowledgeCheck;
  final StarpathNodeState state;
}

@immutable
class StarpathSession {
  const StarpathSession({
    required this.id,
    required this.explicitStart,
    required this.startedAt,
    required this.lastActionAt,
    required this.state,
    this.replacementOfSessionId,
  });

  final String id;
  final bool explicitStart;
  final DateTime startedAt;
  final DateTime lastActionAt;
  final StarpathSessionState state;
  final String? replacementOfSessionId;
}

@immutable
class StarpathProgress {
  const StarpathProgress({
    required this.currentNodeOrdinal,
    required this.version,
    required this.updatedAt,
  });

  final int currentNodeOrdinal;
  final int version;
  final DateTime updatedAt;
}

@immutable
class StarpathRecall {
  const StarpathRecall({
    required this.id,
    required this.lessonId,
    required this.revisionId,
    required this.questionId,
    required this.prompt,
    required this.knowledgeCheck,
  });

  final String id;
  final String lessonId;
  final String revisionId;
  final String questionId;
  final String prompt;
  final StarpathKnowledgeCheck knowledgeCheck;
}

@immutable
class StarpathAnswerFeedback {
  const StarpathAnswerFeedback({
    required this.isCorrect,
    required this.explanation,
  });

  final bool isCorrect;
  final String explanation;
}

@immutable
class StarpathSnapshot {
  StarpathSnapshot({
    required this.availability,
    required this.version,
    required this.authority,
    required List<StarpathNode> nodes,
    required this.session,
    required this.progress,
    required this.theme,
    required this.recall,
    this.answer,
    this.commandEffect,
  }) : nodes = List.unmodifiable(nodes);

  final StarpathAvailability availability;
  final int version;
  final StarpathAuthority authority;
  final List<StarpathNode> nodes;
  final StarpathSession? session;
  final StarpathProgress? progress;
  final StarpathTheme? theme;
  final StarpathRecall? recall;
  final StarpathAnswerFeedback? answer;
  final StarpathCommandEffect? commandEffect;

  bool get isDraftPreview =>
      authority.environment == StarpathEnvironment.beta &&
      authority.manifestVersion == draftPreviewStarpathManifestVersion;

  StarpathNode? get currentNode {
    for (final node in nodes) {
      if (node.state == StarpathNodeState.current) return node;
    }
    return null;
  }
}

@immutable
class StarpathAnswerCommand {
  const StarpathAnswerCommand({
    required this.attemptKind,
    required this.sessionId,
    required this.manifestId,
    required this.revisionId,
    required this.questionId,
    required this.optionId,
  });

  final StarpathAttemptKind attemptKind;
  final String sessionId;
  final String manifestId;
  final String revisionId;
  final String questionId;
  final String optionId;

  String get identity => [
    attemptKind.name,
    sessionId,
    manifestId,
    revisionId,
    questionId,
    optionId,
  ].join(':');
}
