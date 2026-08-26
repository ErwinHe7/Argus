import 'package:flutter/foundation.dart';

enum RecurringType { contribution, allocation }
enum RecurringFrequency { weekly, monthly }
enum RecurringStatus { active, paused, cancelled, completed }
enum RecurringRunStatus { due, running, completed, rejected }

@immutable
class RecurringDemoDisclosure {
  const RecurringDemoDisclosure({
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
class RecurringAllocation {
  const RecurringAllocation({required this.assetId, required this.weightBps});
  final String assetId;
  final int weightBps;
  Map<String, Object?> toMap() => {'asset_id': assetId, 'weight_bps': weightBps};
  factory RecurringAllocation.fromMap(Map<String, Object?> value) =>
      RecurringAllocation(
        assetId: value['asset_id']! as String,
        weightBps: value['weight_bps']! as int,
      );
}

@immutable
class RecurringRun {
  const RecurringRun({
    required this.id,
    required this.scheduledFor,
    required this.status,
  });
  final String id;
  final DateTime scheduledFor;
  final RecurringRunStatus status;
}

@immutable
class RecurringPlan {
  const RecurringPlan({
    required this.id,
    required this.portfolioId,
    required this.type,
    required this.amountMinor,
    required this.frequency,
    required this.nextRunAt,
    required this.status,
    required this.allocations,
    required this.recentRuns,
    required this.version,
    required this.demo,
  });
  final String id;
  final String portfolioId;
  final RecurringType type;
  final int amountMinor;
  final RecurringFrequency frequency;
  final DateTime nextRunAt;
  final RecurringStatus status;
  final List<RecurringAllocation> allocations;
  final List<RecurringRun> recentRuns;
  final int version;
  final RecurringDemoDisclosure demo;
}

@immutable
class RecurringPlanDraft {
  const RecurringPlanDraft({
    required this.portfolioId,
    required this.sourceId,
    required this.type,
    required this.amountMinor,
    required this.frequency,
    required this.firstRunAt,
    required this.allocations,
  });
  final String portfolioId;
  final String sourceId;
  final RecurringType type;
  final int amountMinor;
  final RecurringFrequency frequency;
  final DateTime firstRunAt;
  final List<RecurringAllocation> allocations;

  Map<String, Object?> toCanonicalMap() => {
    'portfolio_id': portfolioId,
    'source_id': sourceId,
    'type': type.name,
    'amount_minor': amountMinor,
    'currency': 'USD',
    'frequency': frequency.name,
    'first_run_at': firstRunAt.toUtc().toIso8601String(),
    'allocations': allocations.map((value) => value.toMap()).toList(),
  };

  factory RecurringPlanDraft.fromProtectedMap(Map<String, Object?> value) =>
      RecurringPlanDraft(
        portfolioId: value['portfolio_id']! as String,
        sourceId: value['source_id']! as String,
        type: RecurringType.values.byName(value['type']! as String),
        amountMinor: value['amount_minor']! as int,
        frequency: RecurringFrequency.values.byName(
          value['frequency']! as String,
        ),
        firstRunAt: DateTime.parse(value['first_run_at']! as String).toUtc(),
        allocations: List<RecurringAllocation>.unmodifiable(
          (value['allocations']! as List).map(
            (item) => RecurringAllocation.fromMap(
              (item as Map).cast<String, Object?>(),
            ),
          ),
        ),
      );
}

@immutable
class RecurringPlanCreate {
  const RecurringPlanCreate({required this.draft, required this.idempotencyKey});
  final RecurringPlanDraft draft;
  final String idempotencyKey;
}

@immutable
class RecurringPlanEdit {
  const RecurringPlanEdit({
    required this.planId,
    required this.expectedVersion,
    this.amountMinor,
    this.frequency,
    this.allocations,
  });
  final String planId;
  final int expectedVersion;
  final int? amountMinor;
  final RecurringFrequency? frequency;
  final List<RecurringAllocation>? allocations;
}

@immutable
class RecurringEditDraft {
  const RecurringEditDraft({
    required this.amountMinor,
    required this.frequency,
    required this.allocations,
  });
  final int? amountMinor;
  final RecurringFrequency? frequency;
  final List<RecurringAllocation>? allocations;
}

@immutable
class RecurringDefaults {
  const RecurringDefaults({required this.frequency, required this.label});
  final RecurringFrequency frequency;
  final String label;
}

class AmbiguousRecurringCreateFailure implements Exception {
  const AmbiguousRecurringCreateFailure();
}

class AmbiguousRecurringMutationFailure implements Exception {
  const AmbiguousRecurringMutationFailure();
}

enum RecurringFailureReason { conflict, invalidTransition, other }

class RecurringFailure implements Exception {
  const RecurringFailure.conflict() : reason = RecurringFailureReason.conflict;
  const RecurringFailure.invalidTransition()
    : reason = RecurringFailureReason.invalidTransition;
  const RecurringFailure.other() : reason = RecurringFailureReason.other;
  final RecurringFailureReason reason;
}
