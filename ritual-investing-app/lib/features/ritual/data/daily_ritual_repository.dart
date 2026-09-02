// ignore_for_file: prefer_initializing_formals

import '../../../core/api/view_state.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../domain/daily_ritual.dart';
import 'daily_ritual_cache_record.dart';

export '../../../core/cache/cached_read.dart'
    show OfflineException, RepositoryRead;

abstract interface class DailyRitualService {
  Future<DailyRitual> fetchDaily({DailyRitualMode? mode});
  Future<DailyRitual> fetchAssignment(String assignmentId);
  Future<List<RitualEvidenceDetail>> fetchEvidence(String assignmentId);
  Future<RitualHistoryPage> fetchHistory({String? cursor});
  Future<DailyRitual> reveal(String assignmentId, int version);
  Future<DailyRitual> complete(String assignmentId, int version);
}

class RitualAmbiguousMutation implements Exception {
  const RitualAmbiguousMutation();
}

enum RitualOperation { reveal, complete }

enum RitualOperationDisposition {
  committed,
  reconciledToTarget,
  provenNotReached,
  authorityUnavailable,
}

class RitualTransitionResult {
  const RitualTransitionResult({
    required this.operation,
    required this.lineage,
    required this.target,
    required this.disposition,
    this.authoritative,
    this.failurePhase,
  });

  final RitualOperation operation;
  final RitualAssignmentLineage lineage;
  final DailyRitualState target;
  final RitualOperationDisposition disposition;
  final DailyRitual? authoritative;
  final LoadPhase? failurePhase;

  DailyRitual? get value => authoritative;
  bool get reconciled =>
      disposition == RitualOperationDisposition.reconciledToTarget;
}

class DailyRitualRepository {
  DailyRitualRepository({
    required DailyRitualService service,
    required ReadCache cache,
    CacheScope? scope,
    DailyRitualMode? effectiveMode,
    DateTime Function()? now,
    RitualMonotonicNow? elapsed,
  }) : _service = service,
       _cache = cache,
       _scope = scope,
       _effectiveMode = effectiveMode,
       _now = now ?? DateTime.now,
       _elapsed = elapsed ?? ritualMonotonicNow;

  final DailyRitualService _service;
  final ReadCache _cache;
  final CacheScope? _scope;
  final DateTime Function() _now;
  final RitualMonotonicNow _elapsed;
  DailyRitualMode? _effectiveMode;
  bool _requiresColdAuthority = false;

  DailyRitualMode? get effectiveMode => _effectiveMode;
  bool get hasScopedAuthority => _scope != null && _effectiveMode != null;

  void updateMode(DailyRitualMode mode) {
    if (_effectiveMode == mode) return;
    _effectiveMode = mode;
    _requiresColdAuthority = true;
  }

  void forceColdRevalidation() => _requiresColdAuthority = true;

  Future<RepositoryRead<DailyRitual>> load() async {
    final scope = _scope;
    final mode = _effectiveMode;
    if (scope == null || mode == null) {
      return cachedRead(
        key: mode == null ? 'daily-ritual' : 'daily-ritual:${mode.name}',
        cache: _cache,
        fetch: () => _service.fetchDaily(mode: mode),
        now: _now,
      );
    }
    if (mode == DailyRitualMode.unknown) {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
    final cached = await readCached();
    if (cached != null) return cached;
    return refreshAuthority();
  }

  Future<RepositoryRead<DailyRitual>?> readCached() async {
    final scope = _scope;
    final mode = _effectiveMode;
    if (scope == null || mode == null || _requiresColdAuthority) return null;
    try {
      final cached = await _cache.get<DailyRitualCacheRecord>(
        DailyRitualCacheRecord.cacheKey(mode),
      );
      final record = cached?.value;
      if (record != null &&
          record.isUsable(
            expectedScope: scope,
            expectedMode: mode,
            now: _now(),
            elapsed: _elapsed(),
          )) {
        return RepositoryRead(
          value: record.ritual,
          isStale: true,
          committedAt: cached!.committedAt,
        );
      }
    } on Object {
      // A corrupt or legacy value in the versioned lane is never displayed.
    }
    return null;
  }

  Future<RepositoryRead<DailyRitual>> refreshAuthority() async {
    final mode = _effectiveMode;
    final ritual = await _service.fetchDaily(mode: mode);
    _validateIfScoped(ritual);
    return RepositoryRead(
      value: ritual,
      isStale: false,
      committedAt: _now().toUtc(),
    );
  }

  Future<void> writeAuthority(DailyRitual ritual) async {
    final scope = _scope;
    final mode = _effectiveMode;
    final committedAt = _now().toUtc();
    if (scope == null || mode == null) {
      await _cache.put(
        mode == null ? 'daily-ritual' : 'daily-ritual:${mode.name}',
        ritual,
        committedAt,
      );
      return;
    }
    final record = DailyRitualCacheRecord.fromAuthority(
      scope: scope,
      mode: mode,
      ritual: ritual,
      receivedAt: committedAt,
      receivedAtElapsed: _elapsed(),
    );
    await _cache.put(
      DailyRitualCacheRecord.cacheKey(mode),
      record,
      committedAt,
    );
    _requiresColdAuthority = false;
  }

  Future<List<RitualEvidenceDetail>> loadEvidence(String assignmentId) =>
      _service.fetchEvidence(assignmentId);

  Future<RitualHistoryPage> loadHistory({String? cursor}) =>
      _service.fetchHistory(cursor: cursor);

  Future<RitualTransitionResult> reveal(DailyRitual current) => _transition(
    operation: RitualOperation.reveal,
    current: current,
    target: DailyRitualState.revealed,
    mutate: () => _service.reveal(current.assignmentId, current.version),
  );

  Future<RitualTransitionResult> complete(DailyRitual current) => _transition(
    operation: RitualOperation.complete,
    current: current,
    target: DailyRitualState.completed,
    mutate: () => _service.complete(current.assignmentId, current.version),
  );

  Future<RitualTransitionResult> _transition({
    required RitualOperation operation,
    required DailyRitual current,
    required DailyRitualState target,
    required Future<DailyRitual> Function() mutate,
  }) async {
    try {
      final authoritative = await mutate();
      _validateTransitionIdentity(current, authoritative);
      if (!_hasReached(authoritative, target) ||
          authoritative.version <= current.version ||
          !current.hasSameImmutableContent(authoritative)) {
        throw const RitualAuthorityInvalid(
          RitualAuthorityInvalidReason.lifecycle,
        );
      }
      return RitualTransitionResult(
        operation: operation,
        lineage: current.lineage,
        target: target,
        disposition: RitualOperationDisposition.committed,
        authoritative: authoritative,
      );
    } on Object catch (error) {
      if (_isProvenPreDispatchRejection(error)) {
        return RitualTransitionResult(
          operation: operation,
          lineage: current.lineage,
          target: target,
          disposition: RitualOperationDisposition.provenNotReached,
          authoritative: current,
          failurePhase: (error as LoadFailure).phase,
        );
      }
      try {
        final authoritative = await _service.fetchAssignment(
          current.assignmentId,
        );
        _validateTransitionIdentity(current, authoritative);
        if (!current.hasSameImmutableContent(authoritative) ||
            authoritative.version < current.version ||
            dailyRitualStateRank(authoritative.state) <
                dailyRitualStateRank(current.state)) {
          throw const RitualAuthorityInvalid(
            RitualAuthorityInvalidReason.lifecycle,
          );
        }
        final reached = _hasReached(authoritative, target);
        if (reached && authoritative.version <= current.version) {
          throw const RitualAuthorityInvalid(
            RitualAuthorityInvalidReason.lifecycle,
          );
        }
        return RitualTransitionResult(
          operation: operation,
          lineage: current.lineage,
          target: target,
          disposition: reached
              ? RitualOperationDisposition.reconciledToTarget
              : RitualOperationDisposition.provenNotReached,
          authoritative: authoritative,
        );
      } on Object {
        return RitualTransitionResult(
          operation: operation,
          lineage: current.lineage,
          target: target,
          disposition: RitualOperationDisposition.authorityUnavailable,
        );
      }
    }
  }

  void _validateIfScoped(DailyRitual ritual) {
    final scope = _scope;
    final mode = _effectiveMode;
    if (scope == null || mode == null) return;
    DailyRitualCacheRecord.validateAuthority(
      scope: scope,
      mode: mode,
      ritual: ritual,
    );
  }

  void _validateTransitionIdentity(
    DailyRitual current,
    DailyRitual authoritative,
  ) {
    _validateIfScoped(authoritative);
    if (!current.hasSameLineage(authoritative)) {
      throw const RitualAuthorityInvalid(RitualAuthorityInvalidReason.lineage);
    }
  }

  bool _hasReached(DailyRitual ritual, DailyRitualState target) =>
      ritual.state == target ||
      (target == DailyRitualState.revealed &&
          ritual.state == DailyRitualState.completed);

  bool _isProvenPreDispatchRejection(Object error) =>
      error is LoadFailure &&
      (error.phase == LoadPhase.forbidden ||
          error.phase == LoadPhase.terminalFailure ||
          error.phase == LoadPhase.throttled);
}
