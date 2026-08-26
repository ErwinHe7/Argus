import 'package:flutter/foundation.dart';

enum IntentionStatus { active, completed, archived }

@immutable
class IntentionDemoDisclosure {
  const IntentionDemoDisclosure({
    required this.isDemo,
    required this.observedAt,
    required this.sourceLabel,
    required this.limitations,
  });

  final bool isDemo;
  final DateTime observedAt;
  final String sourceLabel;
  final List<String> limitations;
}

@immutable
class Intention {
  const Intention({
    required this.id,
    required this.portfolioId,
    required this.title,
    required this.targetMinor,
    required this.targetDate,
    required this.status,
    required this.progressMinor,
    required this.progressBps,
    required this.version,
    required this.demo,
    this.latestProjectionId,
  });

  final String id;
  final String portfolioId;
  final String title;
  final int targetMinor;
  final DateTime targetDate;
  final IntentionStatus status;
  final int progressMinor;
  final int progressBps;
  final String? latestProjectionId;
  final int version;
  final IntentionDemoDisclosure demo;

  IntentionDraft copyAsDraft({
    String? title,
    int? targetMinor,
    DateTime? targetDate,
    IntentionStatus? status,
  }) => IntentionDraft(
    portfolioId: portfolioId,
    title: title ?? this.title,
    targetMinor: targetMinor ?? this.targetMinor,
    targetDate: targetDate ?? this.targetDate,
    status: status ?? this.status,
  );

  Intention copyWith({
    String? id,
    String? portfolioId,
    String? title,
    int? targetMinor,
    DateTime? targetDate,
    IntentionStatus? status,
    int? progressMinor,
    int? progressBps,
    String? latestProjectionId,
    bool clearLatestProjectionId = false,
    int? version,
    IntentionDemoDisclosure? demo,
  }) => Intention(
    id: id ?? this.id,
    portfolioId: portfolioId ?? this.portfolioId,
    title: title ?? this.title,
    targetMinor: targetMinor ?? this.targetMinor,
    targetDate: targetDate ?? this.targetDate,
    status: status ?? this.status,
    progressMinor: progressMinor ?? this.progressMinor,
    progressBps: progressBps ?? this.progressBps,
    latestProjectionId: clearLatestProjectionId
        ? null
        : latestProjectionId ?? this.latestProjectionId,
    version: version ?? this.version,
    demo: demo ?? this.demo,
  );
}

@immutable
class IntentionPage {
  const IntentionPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<Intention> items;
  final bool hasMore;
  final String? nextCursor;
}

@immutable
class IntentionDraft {
  const IntentionDraft({
    required this.portfolioId,
    required this.title,
    required this.targetMinor,
    required this.targetDate,
    this.status = IntentionStatus.active,
  });

  final String portfolioId;
  final String title;
  final int targetMinor;
  final DateTime targetDate;
  final IntentionStatus status;

  Map<String, Object?> toCanonicalMap() => {
    'portfolio_id': portfolioId,
    'title': title.trim(),
    'target_minor': targetMinor,
    'target_date': _dateOnly(targetDate),
    'status': status.name,
  };

  factory IntentionDraft.fromProtectedMap(Map<String, Object?> value) {
    if (value.length != 5 ||
        value['portfolio_id'] is! String ||
        value['title'] is! String ||
        value['target_minor'] is! int ||
        value['target_date'] is! String ||
        value['status'] is! String) {
      throw const FormatException('Unsupported Intention draft.');
    }
    final status = IntentionStatus.values
        .where((item) => item.name == value['status'])
        .firstOrNull;
    final date = DateTime.tryParse('${value['target_date']}T00:00:00Z');
    if (status == null || date == null || !date.isUtc) {
      throw const FormatException('Unsupported Intention draft.');
    }
    return IntentionDraft(
      portfolioId: value['portfolio_id']! as String,
      title: value['title']! as String,
      targetMinor: value['target_minor']! as int,
      targetDate: date,
      status: status,
    );
  }

  bool exactlyMatches(Intention value) =>
      portfolioId == value.portfolioId &&
      title.trim() == value.title &&
      targetMinor == value.targetMinor &&
      _dateOnly(targetDate) == _dateOnly(value.targetDate) &&
      status == value.status;
}

@immutable
class IntentionDefaults {
  const IntentionDefaults({
    required this.title,
    required this.targetDate,
    required this.sourceLabel,
  });

  final String title;
  final DateTime targetDate;
  final String sourceLabel;
}

@immutable
class IntentionCreate {
  const IntentionCreate({required this.draft, required this.idempotencyKey});

  final IntentionDraft draft;
  final String idempotencyKey;
}

@immutable
class IntentionPatch {
  const IntentionPatch({
    required this.intentionId,
    required this.expectedVersion,
    required this.draft,
  });

  final String intentionId;
  final int expectedVersion;
  final IntentionDraft draft;
}

class AmbiguousIntentionCreate implements Exception {
  const AmbiguousIntentionCreate();
}

class AmbiguousIntentionMutation implements Exception {
  const AmbiguousIntentionMutation();
}

String _dateOnly(DateTime value) =>
    '${value.toUtc().year.toString().padLeft(4, '0')}-'
    '${value.toUtc().month.toString().padLeft(2, '0')}-'
    '${value.toUtc().day.toString().padLeft(2, '0')}';
