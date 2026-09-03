import 'package:flutter/foundation.dart';

enum DailyRitualMode { tarot, astrology, unknown }

enum DailyRitualState { assigned, revealed, completed, unknown }

enum RitualMediaAvailability { exactIdentity, missingIdentity }

enum RitualContentAvailability { available, unavailable }

enum RitualMutationPhase {
  idle,
  committing,
  committed,
  reconciled,
  retryableFailure,
  terminalFailure,
}

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
    this.userId,
    this.deletionEpoch,
    this.scheduleId = '',
    this.serverEvaluatedAt,
    this.validUntil,
    this.contentIdentity = '',
    RitualMediaAvailability? mediaAvailability,
    this.contentAvailability = RitualContentAvailability.available,
  }) : ideas = List.unmodifiable(ideas),
       evidence = List.unmodifiable(evidence),
       mediaAvailability =
           mediaAvailability ??
           (art.key.trim().isEmpty
               ? RitualMediaAvailability.missingIdentity
               : RitualMediaAvailability.exactIdentity);

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
  final String? userId;
  final int? deletionEpoch;
  final String scheduleId;
  final DateTime? serverEvaluatedAt;
  final DateTime? validUntil;
  final String contentIdentity;
  final RitualMediaAvailability mediaAvailability;
  final RitualContentAvailability contentAvailability;

  bool get hasExactArtIdentity =>
      mediaAvailability == RitualMediaAvailability.exactIdentity &&
      art.key.trim().isNotEmpty;

  RitualAssignmentLineage get lineage => RitualAssignmentLineage(
    userId: userId,
    deletionEpoch: deletionEpoch,
    localDate: date,
    mode: mode,
    assignmentId: assignmentId,
    assignmentVersion: version,
    revision: revision,
    contentIdentity: contentIdentity,
    artKey: art.key,
  );

  bool hasSameAssignmentIdentity(DailyRitual other) =>
      assignmentId == other.assignmentId &&
      date == other.date &&
      mode == other.mode &&
      userId == other.userId &&
      deletionEpoch == other.deletionEpoch;

  bool hasSameImmutableContent(DailyRitual other) =>
      revision == other.revision &&
      scheduleId == other.scheduleId &&
      contentIdentity == other.contentIdentity &&
      title == other.title &&
      art == other.art &&
      mediaAvailability == other.mediaAvailability &&
      contentAvailability == other.contentAvailability &&
      interpretation == other.interpretation &&
      guidance == other.guidance &&
      marketLabel == other.marketLabel &&
      listEquals(ideas, other.ideas) &&
      listEquals(evidence, other.evidence) &&
      rowan == other.rowan &&
      demo == other.demo;

  bool hasSameVersionPayload(DailyRitual other) =>
      version == other.version &&
      state == other.state &&
      revealedAt == other.revealedAt &&
      completedAt == other.completedAt &&
      hasSameImmutableContent(other);

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
      other.demo == demo &&
      other.userId == userId &&
      other.deletionEpoch == deletionEpoch &&
      other.scheduleId == scheduleId &&
      other.serverEvaluatedAt == serverEvaluatedAt &&
      other.validUntil == validUntil &&
      other.contentIdentity == contentIdentity &&
      other.mediaAvailability == mediaAvailability &&
      other.contentAvailability == contentAvailability;

  @override
  int get hashCode => Object.hashAll([
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
    userId,
    deletionEpoch,
    scheduleId,
    serverEvaluatedAt,
    validUntil,
    contentIdentity,
    mediaAvailability,
    contentAvailability,
  ]);
}

@immutable
class RitualAssignmentLineage {
  const RitualAssignmentLineage({
    required this.userId,
    required this.deletionEpoch,
    required this.localDate,
    required this.mode,
    required this.assignmentId,
    required this.assignmentVersion,
    required this.revision,
    required this.contentIdentity,
    required this.artKey,
  });

  final String? userId;
  final int? deletionEpoch;
  final DateTime localDate;
  final DailyRitualMode mode;
  final String assignmentId;
  final int assignmentVersion;
  final RitualRevision revision;
  final String contentIdentity;
  final String artKey;

  @override
  bool operator ==(Object other) =>
      other is RitualAssignmentLineage &&
      other.userId == userId &&
      other.deletionEpoch == deletionEpoch &&
      other.localDate == localDate &&
      other.mode == mode &&
      other.assignmentId == assignmentId &&
      other.assignmentVersion == assignmentVersion &&
      other.revision == revision &&
      other.contentIdentity == contentIdentity &&
      other.artKey == artKey;

  @override
  int get hashCode => Object.hash(
    userId,
    deletionEpoch,
    localDate,
    mode,
    assignmentId,
    assignmentVersion,
    revision,
    contentIdentity,
    artKey,
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
class RitualEvidenceSource {
  const RitualEvidenceSource({
    required this.publisher,
    required this.title,
    required this.url,
    required this.publishedAt,
  });

  final String publisher;
  final String title;
  final Uri url;
  final DateTime? publishedAt;
}

@immutable
class RitualEvidenceDetail {
  const RitualEvidenceDetail({
    required this.claimId,
    required this.factorLabel,
    required this.observedAt,
    required this.summary,
    required this.uncertainty,
    required this.source,
  });

  final String claimId;
  final String factorLabel;
  final DateTime observedAt;
  final String summary;
  final String uncertainty;
  final RitualEvidenceSource source;
}

@immutable
class RitualHistoryEntry {
  const RitualHistoryEntry({
    required this.assignmentId,
    required this.date,
    required this.mode,
    required this.title,
    required this.state,
    required this.demo,
  });

  factory RitualHistoryEntry.fromRitual(DailyRitual ritual) =>
      RitualHistoryEntry(
        assignmentId: ritual.assignmentId,
        date: ritual.date,
        mode: ritual.mode,
        title: ritual.title,
        state: ritual.state,
        demo: ritual.demo,
      );

  final String assignmentId;
  final DateTime date;
  final DailyRitualMode mode;
  final String title;
  final DailyRitualState state;
  final RitualDisclosure demo;
}

@immutable
class RitualHistoryPage {
  RitualHistoryPage({
    required List<RitualHistoryEntry> items,
    required this.nextCursor,
    required this.hasMore,
  }) : items = List.unmodifiable(items);

  final List<RitualHistoryEntry> items;
  final String? nextCursor;
  final bool hasMore;
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
