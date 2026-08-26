import 'package:flutter/foundation.dart';

enum AssetKind { equity, etf, marketIndex, cash }

enum AssetSourceKind { ritual, circle, discover, search, direct }

enum AssetRiskSeverity { low, medium, high }

enum AssetSavePhase {
  idle,
  saving,
  saved,
  reconciled,
  retryableFailure,
  terminalFailure,
}

@immutable
class AssetSourceContext {
  const AssetSourceContext({required this.kind, this.resourceId});

  final AssetSourceKind kind;
  final String? resourceId;
}

@immutable
class AssetDemoDisclosure {
  AssetDemoDisclosure({
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
class AssetEvidenceSummary {
  const AssetEvidenceSummary({
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
class AssetEvidenceDetail extends AssetEvidenceSummary {
  const AssetEvidenceDetail({
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
class AssetRisk {
  const AssetRisk({
    required this.title,
    required this.detail,
    required this.severity,
  });

  final String title;
  final String detail;
  final AssetRiskSeverity severity;
}

@immutable
class AssetSummaryView {
  const AssetSummaryView({
    required this.id,
    required this.revisionId,
    required this.slug,
    required this.symbol,
    required this.name,
    required this.kind,
    required this.currency,
    required this.appearanceReason,
    required this.demo,
  });

  final String id;
  final String revisionId;
  final String slug;
  final String symbol;
  final String name;
  final AssetKind kind;
  final String currency;
  final String appearanceReason;
  final AssetDemoDisclosure demo;
}

@immutable
class AssetCodex {
  AssetCodex({
    required this.id,
    required this.revisionId,
    required this.slug,
    required this.symbol,
    required this.name,
    required this.kind,
    required this.currency,
    required this.appearanceReason,
    required this.thesis,
    required this.limitations,
    required this.metricsAsOf,
    required List<AssetEvidenceSummary> evidence,
    required List<AssetEvidenceDetail> detailedEvidence,
    required List<AssetRisk> risks,
    required this.saved,
    required this.demo,
    required this.source,
    List<AssetMetric> metrics = const [],
  }) : evidence = List.unmodifiable(evidence),
       detailedEvidence = List.unmodifiable(detailedEvidence),
       risks = List.unmodifiable(risks),
       metrics = List.unmodifiable(metrics);

  final String id;
  final String revisionId;
  final String slug;
  final String symbol;
  final String name;
  final AssetKind kind;
  final String currency;
  final String appearanceReason;
  final String thesis;
  final String limitations;
  final DateTime metricsAsOf;
  final List<AssetEvidenceSummary> evidence;
  final List<AssetEvidenceDetail> detailedEvidence;
  final List<AssetRisk> risks;
  final bool saved;
  final AssetDemoDisclosure demo;
  final AssetSourceContext source;
  final List<AssetMetric> metrics;

  AssetSummaryView get summary => AssetSummaryView(
    id: id,
    revisionId: revisionId,
    slug: slug,
    symbol: symbol,
    name: name,
    kind: kind,
    currency: currency,
    appearanceReason: appearanceReason,
    demo: demo,
  );

  AssetCodex copyWith({
    bool? saved,
    AssetSourceContext? source,
    List<AssetEvidenceDetail>? detailedEvidence,
    List<AssetMetric>? metrics,
  }) => AssetCodex(
    id: id,
    revisionId: revisionId,
    slug: slug,
    symbol: symbol,
    name: name,
    kind: kind,
    currency: currency,
    appearanceReason: appearanceReason,
    thesis: thesis,
    limitations: limitations,
    metricsAsOf: metricsAsOf,
    evidence: evidence,
    detailedEvidence: detailedEvidence ?? this.detailedEvidence,
    risks: risks,
    saved: saved ?? this.saved,
    demo: demo,
    source: source ?? this.source,
    metrics: metrics ?? this.metrics,
  );
}

@immutable
class AssetMetric {
  const AssetMetric({
    required this.priceMinor,
    required this.changeBps,
    required this.expenseRatioBps,
    required this.observedAt,
    required this.sourceLabel,
    required this.demo,
  });

  final int priceMinor;
  final int? changeBps;
  final int? expenseRatioBps;
  final DateTime observedAt;
  final String sourceLabel;
  final AssetDemoDisclosure demo;
}

@immutable
class AssetComparisonItem {
  const AssetComparisonItem({
    required this.asset,
    required this.metric,
    required this.riskCount,
  });

  final AssetSummaryView asset;
  final AssetMetric metric;
  final int riskCount;
}

@immutable
class AssetComparison {
  AssetComparison({
    required List<AssetComparisonItem> items,
    required this.comparedAt,
    required this.demo,
  }) : items = List.unmodifiable(items);

  final List<AssetComparisonItem> items;
  final DateTime comparedAt;
  final AssetDemoDisclosure demo;
}
