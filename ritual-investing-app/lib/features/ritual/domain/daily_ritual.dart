import 'package:flutter/foundation.dart';

enum DailyRitualMode { tarot, astrology, unknown }

enum DailyRitualState { assigned, revealed, completed, unknown }

@immutable
class DailyRitual {
  DailyRitual({
    required this.assignmentId,
    required this.date,
    required this.mode,
    required this.revision,
    required this.title,
    required this.art,
    required this.interpretation,
    required this.guidance,
    required this.marketLabel,
    required List<RitualIdea> ideas,
    required List<RitualEvidence> evidence,
    required this.rowan,
    required this.version,
    required this.state,
    required this.revealedAt,
    required this.completedAt,
    required this.demo,
  }) : ideas = List.unmodifiable(ideas),
       evidence = List.unmodifiable(evidence);

  final String assignmentId;
  final DateTime date;
  final DailyRitualMode mode;
  final RitualRevision revision;
  final String title;
  final RitualArt art;
  final String interpretation;
  final String guidance;
  final String marketLabel;
  final List<RitualIdea> ideas;
  final List<RitualEvidence> evidence;
  final RitualCounsel rowan;
  final int version;
  final DailyRitualState state;
  final DateTime? revealedAt;
  final DateTime? completedAt;
  final RitualDisclosure demo;

  @override
  bool operator ==(Object other) =>
      other is DailyRitual &&
      other.assignmentId == assignmentId &&
      other.date == date &&
      other.mode == mode &&
      other.revision == revision &&
      other.title == title &&
      other.art == art &&
      other.interpretation == interpretation &&
      other.guidance == guidance &&
      other.marketLabel == marketLabel &&
      listEquals(other.ideas, ideas) &&
      listEquals(other.evidence, evidence) &&
      other.rowan == rowan &&
      other.version == version &&
      other.state == state &&
      other.revealedAt == revealedAt &&
      other.completedAt == completedAt &&
      other.demo == demo;

  @override
  int get hashCode => Object.hash(
    assignmentId,
    date,
    mode,
    revision,
    title,
    art,
    interpretation,
    guidance,
    marketLabel,
    Object.hashAll(ideas),
    Object.hashAll(evidence),
    rowan,
    version,
    state,
    revealedAt,
    completedAt,
    demo,
  );
}

@immutable
class RitualRevision {
  const RitualRevision({required this.id, required this.number});
  final String id;
  final int number;

  @override
  bool operator ==(Object other) =>
      other is RitualRevision && other.id == id && other.number == number;
  @override
  int get hashCode => Object.hash(id, number);
}

@immutable
class RitualArt {
  const RitualArt({required this.key, required this.alt});
  final String key;
  final String alt;

  @override
  bool operator ==(Object other) =>
      other is RitualArt && other.key == key && other.alt == alt;
  @override
  int get hashCode => Object.hash(key, alt);
}

@immutable
class RitualIdea {
  const RitualIdea({
    required this.assetId,
    required this.symbol,
    required this.name,
    required this.appearanceReason,
    required this.riskSummary,
    this.changeLabel,
  });
  final String assetId;
  final String symbol;
  final String name;
  final String appearanceReason;
  final String riskSummary;

  /// Optional because the Daily Ritual summary does not always carry a metric.
  final String? changeLabel;

  @override
  bool operator ==(Object other) =>
      other is RitualIdea &&
      other.assetId == assetId &&
      other.symbol == symbol &&
      other.name == name &&
      other.appearanceReason == appearanceReason &&
      other.riskSummary == riskSummary &&
      other.changeLabel == changeLabel;
  @override
  int get hashCode => Object.hash(
    assetId,
    symbol,
    name,
    appearanceReason,
    riskSummary,
    changeLabel,
  );
}

@immutable
class RitualEvidence {
  const RitualEvidence({
    required this.claimId,
    required this.factorLabel,
    required this.observedAt,
    required this.summary,
    required this.uncertainty,
  });
  final String claimId;
  final String factorLabel;
  final DateTime observedAt;
  final String summary;
  final String uncertainty;

  @override
  bool operator ==(Object other) =>
      other is RitualEvidence &&
      other.claimId == claimId &&
      other.factorLabel == factorLabel &&
      other.observedAt == observedAt &&
      other.summary == summary &&
      other.uncertainty == uncertainty;
  @override
  int get hashCode =>
      Object.hash(claimId, factorLabel, observedAt, summary, uncertainty);
}

@immutable
class RitualCounsel {
  const RitualCounsel({
    required this.scriptRevisionId,
    required this.surface,
    required this.body,
    required this.riskFooter,
  });
  final String scriptRevisionId;
  final String surface;
  final String body;
  final String riskFooter;

  @override
  bool operator ==(Object other) =>
      other is RitualCounsel &&
      other.scriptRevisionId == scriptRevisionId &&
      other.surface == surface &&
      other.body == body &&
      other.riskFooter == riskFooter;
  @override
  int get hashCode => Object.hash(scriptRevisionId, surface, body, riskFooter);
}

@immutable
class RitualDisclosure {
  RitualDisclosure({
    required this.isDemo,
    required this.observedAt,
    required this.sourceLabel,
    required List<String> limitations,
  }) : limitations = List.unmodifiable(limitations);
  final bool isDemo;
  final DateTime observedAt;
  final String sourceLabel;
  final List<String> limitations;

  @override
  bool operator ==(Object other) =>
      other is RitualDisclosure &&
      other.isDemo == isDemo &&
      other.observedAt == observedAt &&
      other.sourceLabel == sourceLabel &&
      listEquals(other.limitations, limitations);
  @override
  int get hashCode =>
      Object.hash(isDemo, observedAt, sourceLabel, Object.hashAll(limitations));
}
