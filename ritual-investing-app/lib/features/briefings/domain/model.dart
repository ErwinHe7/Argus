import 'package:flutter/foundation.dart';

enum BriefingType { daily, weekly, moonCycle }

@immutable
class BriefingSummary {
  const BriefingSummary({
    required this.id,
    required this.type,
    required this.periodStart,
    required this.periodEnd,
    required this.generatedAt,
    required this.generation,
    required this.sourceSequence,
    required this.readAt,
  });

  final String id;
  final BriefingType type;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime generatedAt;
  final int generation;
  final int sourceSequence;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  String get cadenceLabel => switch (type) {
    BriefingType.daily => 'Daily reflection',
    BriefingType.weekly => 'Weekly recap',
    BriefingType.moonCycle => 'Moon-cycle recap',
  };

  BriefingSummary copyWith({DateTime? readAt, bool clearReadAt = false}) =>
      BriefingSummary(
        id: id,
        type: type,
        periodStart: periodStart,
        periodEnd: periodEnd,
        generatedAt: generatedAt,
        generation: generation,
        sourceSequence: sourceSequence,
        readAt: clearReadAt ? null : readAt ?? this.readAt,
      );
}

@immutable
class BriefingSummarySection {
  const BriefingSummarySection({
    required this.ordinal,
    required this.sourceSequence,
    required this.disclosure,
  });

  final int ordinal;
  final int sourceSequence;
  final String disclosure;
  int get schemaVersion => 1;
}

@immutable
class BriefingDetail {
  const BriefingDetail({required this.summary, required this.sections});

  final BriefingSummary summary;
  final List<BriefingSummarySection> sections;

  String get id => summary.id;
  BriefingType get type => summary.type;
  DateTime get generatedAt => summary.generatedAt;
  int get sourceSequence => summary.sourceSequence;
  bool get isRead => summary.isRead;
  String get formatLabel => 'Reviewed local parser · summary v1';

  BriefingDetail copyWithSummary(BriefingSummary value) =>
      BriefingDetail(summary: value, sections: sections);
}

@immutable
class BriefingPage {
  const BriefingPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<BriefingSummary> items;
  final bool hasMore;
  final String? nextCursor;
}

@immutable
class DailyBriefingResult {
  const DailyBriefingResult._({this.detail, this.pendingDate});

  factory DailyBriefingResult.available(BriefingDetail detail) =>
      DailyBriefingResult._(detail: detail);

  factory DailyBriefingResult.pending(DateTime localDate) =>
      DailyBriefingResult._(pendingDate: localDate);

  final BriefingDetail? detail;
  final DateTime? pendingDate;

  bool get isPending => pendingDate != null;
}
