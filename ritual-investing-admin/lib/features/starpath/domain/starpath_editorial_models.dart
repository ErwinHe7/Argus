import 'package:flutter/foundation.dart';

enum StarpathReviewDiscipline {
  factual('factual'),
  compliance('compliance');

  const StarpathReviewDiscipline(this.wireValue);
  final String wireValue;
}

enum StarpathReviewDecision {
  approved('approved'),
  changesRequested('changes_requested'),
  rejected('rejected');

  const StarpathReviewDecision(this.wireValue);
  final String wireValue;
}

enum StarpathReleaseEnvironment {
  beta('beta'),
  production('production');

  const StarpathReleaseEnvironment(this.wireValue);
  final String wireValue;
}

@immutable
class StarpathEvidenceDraft {
  const StarpathEvidenceDraft({
    required this.canonicalUrl,
    required this.sourceTitle,
    required this.publisher,
    required this.sourceObservedAt,
    required this.effectiveAt,
    required this.retrievedAt,
    required this.currentUntil,
    required this.claimSummary,
  });

  factory StarpathEvidenceDraft.fromPayload(Map<String, Object?> value) =>
      StarpathEvidenceDraft(
        canonicalUrl: _string(value['canonical_url']),
        sourceTitle: _string(value['source_title']),
        publisher: _string(value['publisher']),
        sourceObservedAt: _date(value['source_observed_at']),
        effectiveAt: _date(value['effective_at']),
        retrievedAt: _date(value['retrieved_at']),
        currentUntil: _date(value['current_until']),
        claimSummary: _string(value['claim_summary']),
      );

  final String canonicalUrl;
  final String sourceTitle;
  final String publisher;
  final DateTime? sourceObservedAt;
  final DateTime? effectiveAt;
  final DateTime? retrievedAt;
  final DateTime? currentUntil;
  final String claimSummary;

  Map<String, Object?> toPayload() => {
    'canonical_url': canonicalUrl,
    'source_title': sourceTitle,
    'publisher': publisher,
    'source_observed_at': _timestamp(sourceObservedAt),
    'effective_at': _timestamp(effectiveAt),
    'retrieved_at': _timestamp(retrievedAt),
    'current_until': _timestamp(currentUntil),
    'claim_summary': claimSummary,
  };
}

@immutable
class StarpathFactualSectionDraft {
  const StarpathFactualSectionDraft({
    required this.kind,
    required this.heading,
    required this.body,
    required this.uncertainty,
    required this.observedAt,
    required this.evidence,
  });

  factory StarpathFactualSectionDraft.fromPayload(Map<String, Object?> value) =>
      StarpathFactualSectionDraft(
        kind: _string(value['kind']),
        heading: _string(value['heading']),
        body: _string(value['body']),
        uncertainty: _string(value['uncertainty']),
        observedAt: _date(value['observed_at']),
        evidence: _maps(value['evidence'])
            .map(StarpathEvidenceDraft.fromPayload)
            .toList(growable: false),
      );

  final String kind;
  final String heading;
  final String body;
  final String uncertainty;
  final DateTime? observedAt;
  final List<StarpathEvidenceDraft> evidence;

  Map<String, Object?> toPayload() => {
    'kind': kind,
    'heading': heading,
    'body': body,
    'uncertainty': uncertainty,
    'observed_at': _timestamp(observedAt),
    'evidence': evidence.map((item) => item.toPayload()).toList(),
  };
}

@immutable
class StarpathCheckOptionDraft {
  const StarpathCheckOptionDraft({
    required this.label,
    required this.isCorrect,
    required this.explanation,
  });

  factory StarpathCheckOptionDraft.fromPayload(Map<String, Object?> value) =>
      StarpathCheckOptionDraft(
        label: _string(value['label']),
        isCorrect: value['is_correct'] == true,
        explanation: _string(value['explanation']),
      );

  final String label;
  final bool isCorrect;
  final String explanation;

  Map<String, Object?> toPayload() => {
    'label': label,
    'is_correct': isCorrect,
    'explanation': explanation,
  };
}

@immutable
class StarpathKnowledgeCheckDraft {
  const StarpathKnowledgeCheckDraft({
    required this.prompt,
    required this.explanation,
    required this.options,
  });

  factory StarpathKnowledgeCheckDraft.fromPayload(Map<String, Object?> value) =>
      StarpathKnowledgeCheckDraft(
        prompt: _string(value['prompt']),
        explanation: _string(value['explanation']),
        options: _maps(value['options'])
            .map(StarpathCheckOptionDraft.fromPayload)
            .toList(growable: false),
      );

  final String prompt;
  final String explanation;
  final List<StarpathCheckOptionDraft> options;

  Map<String, Object?> toPayload() => {
    'prompt': prompt,
    'explanation': explanation,
    'options': options.map((option) => option.toPayload()).toList(),
  };
}

@immutable
class StarpathLessonDraft {
  const StarpathLessonDraft({
    required this.stableKey,
    required this.pathwayOrdinal,
    required this.pathwayPosition,
    required this.policyVersion,
    required this.classification,
    required this.title,
    required this.tarotKey,
    required this.tarotAccessibleLabel,
    required this.mythicMnemonic,
    required this.factualSummary,
    required this.materialLimitations,
    required this.riskContext,
    required this.recallPrompt,
    required this.rowanExplanation,
    required this.sections,
    required this.check,
  });

  factory StarpathLessonDraft.fromPayload(Map<String, Object?> value) =>
      StarpathLessonDraft(
        stableKey: _string(value['stable_key']),
        pathwayOrdinal: _integer(value['pathway_ordinal']),
        pathwayPosition: _integer(value['pathway_position']),
        policyVersion: _string(value['policy_version']),
        classification: _string(value['classification']),
        title: _string(value['title']),
        tarotKey: _string(value['tarot_key']),
        tarotAccessibleLabel: _string(value['tarot_accessible_label']),
        mythicMnemonic: _string(value['mythic_mnemonic']),
        factualSummary: _string(value['factual_summary']),
        materialLimitations: _string(value['material_limitations']),
        riskContext: _string(value['risk_context']),
        recallPrompt: _string(value['recall_prompt']),
        rowanExplanation: _string(value['rowan_explanation']),
        sections: _maps(value['sections'])
            .map(StarpathFactualSectionDraft.fromPayload)
            .toList(growable: false),
        check: StarpathKnowledgeCheckDraft.fromPayload(_map(value['check'])),
      );

  final String stableKey;
  final int pathwayOrdinal;
  final int pathwayPosition;
  final String policyVersion;
  final String classification;
  final String title;
  final String tarotKey;
  final String tarotAccessibleLabel;
  final String mythicMnemonic;
  final String factualSummary;
  final String materialLimitations;
  final String riskContext;
  final String recallPrompt;
  final String rowanExplanation;
  final List<StarpathFactualSectionDraft> sections;
  final StarpathKnowledgeCheckDraft check;

  List<String> get validationIssues {
    final issues = <String>[];
    if (classification != 'education_general') {
      issues.add('Classification must be education_general.');
    }
    if (pathwayOrdinal < 1 ||
        pathwayOrdinal > 4 ||
        pathwayPosition < 1 ||
        pathwayPosition > 2) {
      issues.add('The lesson must occupy one of four two-node pathways.');
    }
    if (materialLimitations.trim().isEmpty) {
      issues.add('Material limitations are required.');
    }
    if (riskContext.trim().isEmpty) issues.add('Risk context is required.');
    if (sections.isEmpty ||
        sections.any((section) => section.evidence.isEmpty)) {
      issues.add('Every factual section needs at least one source.');
    }
    if (sections.any(
      (section) =>
          section.observedAt == null ||
          section.evidence.any((evidence) => evidence.sourceObservedAt == null),
    )) {
      issues.add('Every source needs an observation date.');
    }
    if (sections.any(
      (section) => section.evidence.any(
        (evidence) =>
            evidence.retrievedAt == null ||
            evidence.currentUntil == null ||
            !evidence.canonicalUrl.startsWith('https://'),
      ),
    )) {
      issues.add('Every source needs a secure URL and freshness window.');
    }
    if (check.options.length < 2 ||
        check.options.where((option) => option.isCorrect).length != 1) {
      issues.add(
        'A check needs two or more options and exactly one factual answer.',
      );
    }
    final memberCopy = [
      title,
      factualSummary,
      materialLimitations,
      riskContext,
      recallPrompt,
      rowanExplanation,
      check.prompt,
      check.explanation,
      ...sections.expand(
        (section) => [
          section.heading,
          section.body,
          section.uncertainty,
          ...section.evidence.map((evidence) => evidence.claimSummary),
        ],
      ),
      ...check.options.expand((option) => [option.label, option.explanation]),
    ].join('\n');
    if (_guidance.hasMatch(memberCopy)) {
      issues.add('Subjective investment guidance is prohibited.');
    }
    if (_preferenceCheck.hasMatch(check.prompt)) {
      issues.add('Checks may assess facts only, never investment preference.');
    }
    return List.unmodifiable(issues);
  }

  Map<String, Object?> toPayload() => {
    'stable_key': stableKey,
    'pathway_ordinal': pathwayOrdinal,
    'pathway_position': pathwayPosition,
    'policy_version': policyVersion,
    'classification': classification,
    'title': title,
    'tarot_key': tarotKey,
    'tarot_accessible_label': tarotAccessibleLabel,
    'mythic_mnemonic': mythicMnemonic,
    'factual_summary': factualSummary,
    'material_limitations': materialLimitations,
    'risk_context': riskContext,
    'recall_prompt': recallPrompt,
    'rowan_explanation': rowanExplanation,
    'sections': sections.map((section) => section.toPayload()).toList(),
    'check': check.toPayload(),
  };
}

@immutable
class StarpathManifestNodeDraft {
  const StarpathManifestNodeDraft({
    required this.nodeOrdinal,
    required this.pathwayOrdinal,
    required this.pathwayPosition,
    required this.lessonId,
    required this.revisionId,
    required this.title,
    required this.revisionState,
    required this.factualApproved,
    required this.complianceApproved,
  });

  final int nodeOrdinal;
  final int pathwayOrdinal;
  final int pathwayPosition;
  final String lessonId;
  final String revisionId;
  final String title;
  final String revisionState;
  final bool factualApproved;
  final bool complianceApproved;
}

@immutable
class StarpathManifestDraft {
  const StarpathManifestDraft({
    required this.manifestId,
    required this.manifestVersion,
    required this.policyVersion,
    required this.releaseEnvironment,
    required this.supportedJurisdiction,
    required this.themeIds,
    required this.nodes,
  });

  final String manifestId;
  final String manifestVersion;
  final String policyVersion;
  final StarpathReleaseEnvironment releaseEnvironment;
  final String supportedJurisdiction;
  final List<String> themeIds;
  final List<StarpathManifestNodeDraft> nodes;

  List<String> get validationIssues {
    final issues = <String>[];
    if (nodes.length != 8) {
      issues.add('A manifest must contain exactly eight nodes.');
    }
    if (themeIds.isEmpty) issues.add('A reviewed theme is required.');
    if (nodes.map((node) => node.lessonId).toSet().length != nodes.length ||
        nodes.map((node) => node.revisionId).toSet().length != nodes.length) {
      issues.add('Every node must bind a distinct lesson and revision.');
    }
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      final ordinal = index + 1;
      if (node.nodeOrdinal != ordinal ||
          node.pathwayOrdinal != (index ~/ 2) + 1 ||
          node.pathwayPosition != (index % 2) + 1) {
        issues.add('Nodes must follow the exact four-pathway order.');
        break;
      }
    }
    if (nodes.any(
      (node) =>
          node.revisionState != 'approved' ||
          !node.factualApproved ||
          !node.complianceApproved,
    )) {
      issues.add(
        'Every node needs exact-revision factual and compliance approval.',
      );
    }
    return List.unmodifiable(issues);
  }
}

final _guidance = RegExp(
  r'\b(you should|we recommend|our pick|best (stock|etf|bond|investment)|will outperform|price target|buy this|sell this|hold this|right for you|perfect for you)\b',
  caseSensitive: false,
);
final _preferenceCheck = RegExp(
  r'\b(which|what).*(would you (choose|buy|sell|hold)|do you prefer|fits you)\b',
  caseSensitive: false,
);

String _string(Object? value) => value is String ? value : '';
int _integer(Object? value) => value is num ? value.toInt() : 0;
DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
String? _timestamp(DateTime? value) => value?.toUtc().toIso8601String();
Map<String, Object?> _map(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : <String, Object?>{};
List<Map<String, Object?>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map(Map<String, Object?>.from).toList()
    : const [];
