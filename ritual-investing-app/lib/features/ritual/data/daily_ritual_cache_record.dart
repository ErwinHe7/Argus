import 'package:flutter/foundation.dart';

import '../../../core/cache/read_cache.dart';
import '../domain/daily_ritual.dart';

typedef RitualMonotonicNow = Duration Function();

final Stopwatch _ritualProcessClock = Stopwatch()..start();

Duration ritualMonotonicNow() => _ritualProcessClock.elapsed;

enum RitualAuthorityInvalidReason {
  scope,
  mode,
  lineage,
  revision,
  content,
  media,
  lifecycle,
  validity,
}

class RitualAuthorityInvalid implements Exception {
  const RitualAuthorityInvalid(this.reason);

  final RitualAuthorityInvalidReason reason;
}

@immutable
class DailyRitualCacheRecord {
  const DailyRitualCacheRecord._({
    required this.schemaVersion,
    required this.scope,
    required this.mode,
    required this.ritual,
    required this.serverValidity,
    required this.receivedAt,
    required this.receivedAtElapsed,
  });

  static const int currentSchemaVersion = 1;
  static const String namespace = 'daily-ritual-authority:v1';

  final int schemaVersion;
  final CacheScope scope;
  final DailyRitualMode mode;
  final DailyRitual ritual;
  final Duration serverValidity;
  final DateTime receivedAt;
  final Duration receivedAtElapsed;

  static String cacheKey(DailyRitualMode mode) => '$namespace:${mode.name}';

  factory DailyRitualCacheRecord.fromAuthority({
    required CacheScope scope,
    required DailyRitualMode mode,
    required DailyRitual ritual,
    required DateTime receivedAt,
    required Duration receivedAtElapsed,
  }) {
    validateAuthority(scope: scope, mode: mode, ritual: ritual);
    return DailyRitualCacheRecord._(
      schemaVersion: currentSchemaVersion,
      scope: scope,
      mode: mode,
      ritual: ritual,
      serverValidity: ritual.validUntil!.toUtc().difference(
        ritual.serverEvaluatedAt!.toUtc(),
      ),
      receivedAt: receivedAt.toUtc(),
      receivedAtElapsed: receivedAtElapsed,
    );
  }

  bool isUsable({
    required CacheScope expectedScope,
    required DailyRitualMode expectedMode,
    required DateTime now,
    required Duration elapsed,
    Duration wallClockTolerance = const Duration(minutes: 2),
  }) {
    if (schemaVersion != currentSchemaVersion ||
        scope != expectedScope ||
        mode != expectedMode) {
      return false;
    }
    try {
      validateAuthority(
        scope: expectedScope,
        mode: expectedMode,
        ritual: ritual,
      );
    } on RitualAuthorityInvalid {
      return false;
    }
    final monotonicAge = elapsed - receivedAtElapsed;
    if (monotonicAge.isNegative || monotonicAge >= serverValidity) return false;
    final wallAge = now.toUtc().difference(receivedAt);
    if (wallAge.isNegative) return false;
    final discontinuity = wallAge - monotonicAge;
    final magnitude = discontinuity.isNegative ? -discontinuity : discontinuity;
    return magnitude <= wallClockTolerance;
  }

  static void validateAuthority({
    required CacheScope scope,
    required DailyRitualMode mode,
    required DailyRitual ritual,
  }) {
    if (ritual.userId != scope.accountId ||
        ritual.deletionEpoch != scope.resetGeneration) {
      throw const RitualAuthorityInvalid(RitualAuthorityInvalidReason.scope);
    }
    if (mode == DailyRitualMode.unknown || ritual.mode != mode) {
      throw const RitualAuthorityInvalid(RitualAuthorityInvalidReason.mode);
    }
    if (ritual.assignmentId.trim().isEmpty ||
        ritual.scheduleId.trim().isEmpty ||
        !ritual.date.isUtc) {
      throw const RitualAuthorityInvalid(RitualAuthorityInvalidReason.lineage);
    }
    if (ritual.revision.id.trim().isEmpty || ritual.revision.number <= 0) {
      throw const RitualAuthorityInvalid(RitualAuthorityInvalidReason.revision);
    }
    if (ritual.contentIdentity.trim().isEmpty) {
      throw const RitualAuthorityInvalid(RitualAuthorityInvalidReason.content);
    }
    final hasKey = ritual.art.key.trim().isNotEmpty;
    if ((ritual.mediaAvailability == RitualMediaAvailability.exactIdentity) !=
        hasKey) {
      throw const RitualAuthorityInvalid(RitualAuthorityInvalidReason.media);
    }
    if (ritual.version <= 0 || !_hasCoherentLifecycle(ritual)) {
      throw const RitualAuthorityInvalid(
        RitualAuthorityInvalidReason.lifecycle,
      );
    }
    final evaluatedAt = ritual.serverEvaluatedAt;
    final validUntil = ritual.validUntil;
    if (evaluatedAt == null ||
        validUntil == null ||
        evaluatedAt != evaluatedAt.toUtc() ||
        validUntil != validUntil.toUtc() ||
        !validUntil.isAfter(evaluatedAt)) {
      throw const RitualAuthorityInvalid(RitualAuthorityInvalidReason.validity);
    }
  }

  static bool _hasCoherentLifecycle(DailyRitual ritual) =>
      switch (ritual.state) {
        DailyRitualState.assigned =>
          ritual.revealedAt == null && ritual.completedAt == null,
        DailyRitualState.revealed =>
          ritual.revealedAt != null && ritual.completedAt == null,
        DailyRitualState.completed =>
          ritual.revealedAt != null &&
              ritual.completedAt != null &&
              !ritual.completedAt!.isBefore(ritual.revealedAt!),
        DailyRitualState.unknown => false,
      };
}

int dailyRitualStateRank(DailyRitualState state) => switch (state) {
  DailyRitualState.assigned => 0,
  DailyRitualState.revealed => 1,
  DailyRitualState.completed => 2,
  DailyRitualState.unknown => -1,
};
