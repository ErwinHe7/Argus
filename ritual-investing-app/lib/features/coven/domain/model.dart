import 'package:flutter/foundation.dart';

enum CovenQualificationCategory { founder, owner, chiefExecutive }

enum CovenSavePhase {
  idle,
  saving,
  saved,
  reconciled,
  retryableFailure,
  terminalFailure,
}

@immutable
class CovenDemoDisclosure {
  CovenDemoDisclosure({
    required this.isDemo,
    required this.observedAt,
    required this.sourceLabel,
    required List<String> limitations,
  }) : limitations = List.unmodifiable(limitations);

  final bool isDemo;
  final DateTime observedAt;
  final String sourceLabel;
  final List<String> limitations;
}

@immutable
class CovenEvidenceSummary {
  const CovenEvidenceSummary({
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
}

@immutable
class CovenEvidenceDetail extends CovenEvidenceSummary {
  const CovenEvidenceDetail({
    required super.claimId,
    required super.factorLabel,
    required super.observedAt,
    required super.summary,
    required super.uncertainty,
    required this.publisher,
    required this.sourceTitle,
    required this.sourceUrl,
    required this.publishedAt,
  });

  final String publisher;
  final String sourceTitle;
  final Uri sourceUrl;
  final DateTime? publishedAt;
}

@immutable
class CovenQualification {
  CovenQualification({
    required this.category,
    required this.personName,
    required this.effectiveDate,
    required this.verifiedAsOf,
    required this.validTo,
    required List<CovenEvidenceSummary> evidence,
  }) : evidence = List.unmodifiable(evidence);

  final CovenQualificationCategory category;
  final String personName;
  final DateTime effectiveDate;
  final DateTime verifiedAsOf;
  final DateTime? validTo;
  final List<CovenEvidenceSummary> evidence;
}

@immutable
class CovenEntry {
  const CovenEntry({
    required this.id,
    required this.revisionId,
    required this.slug,
    required this.name,
    required this.symbol,
    required this.category,
    required this.focus,
    required this.teaser,
    required this.effectiveDate,
    required this.verifiedAsOf,
    required this.demo,
  });

  final String id;
  final String revisionId;
  final String slug;
  final String name;
  final String? symbol;
  final CovenQualificationCategory category;
  final String focus;
  final String teaser;
  final DateTime effectiveDate;
  final DateTime verifiedAsOf;
  final CovenDemoDisclosure demo;
}

@immutable
class CovenModel {
  CovenModel({required List<CovenEntry> entries})
    : entries = List.unmodifiable(entries);

  final List<CovenEntry> entries;
}

@immutable
class CovenDetail {
  CovenDetail({
    required this.id,
    required this.revisionId,
    required this.slug,
    required this.company,
    required this.symbol,
    required this.focus,
    required this.summary,
    required this.inclusionRationale,
    required this.limitations,
    required List<CovenQualification> qualifications,
    required List<CovenEvidenceDetail> evidence,
    required this.saved,
    required this.demo,
  }) : qualifications = List.unmodifiable(qualifications),
       evidence = List.unmodifiable(evidence);

  final String id;
  final String revisionId;
  final String slug;
  final String company;
  final String? symbol;
  final String focus;
  final String summary;
  final String inclusionRationale;
  final String limitations;
  final List<CovenQualification> qualifications;
  final List<CovenEvidenceDetail> evidence;
  final bool saved;
  final CovenDemoDisclosure demo;

  CovenDetail copyWith({
    bool? saved,
    List<CovenEvidenceDetail>? evidence,
  }) => CovenDetail(
    id: id,
    revisionId: revisionId,
    slug: slug,
    company: company,
    symbol: symbol,
    focus: focus,
    summary: summary,
    inclusionRationale: inclusionRationale,
    limitations: limitations,
    qualifications: qualifications,
    evidence: evidence ?? this.evidence,
    saved: saved ?? this.saved,
    demo: demo,
  );
}
