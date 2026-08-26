// ignore_for_file: prefer_initializing_formals

import '../../../core/cache/read_cache.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/api/view_state.dart';
import '../domain/daily_ritual.dart';

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

class RitualTransitionResult {
  const RitualTransitionResult({required this.value, required this.reconciled});

  final DailyRitual value;
  final bool reconciled;
}

class DailyRitualRepository {
  DailyRitualRepository({
    required DailyRitualService service,
    required ReadCache cache,
  }) : _service = service,
       _cache = cache;
  final DailyRitualService _service;
  final ReadCache _cache;
  Future<RepositoryRead<DailyRitual>> load({DailyRitualMode? mode}) =>
      cachedRead(
        key: mode == null ? 'daily-ritual' : 'daily-ritual:${mode.name}',
        cache: _cache,
        fetch: () => _service.fetchDaily(mode: mode),
      );

  Future<List<RitualEvidenceDetail>> loadEvidence(String assignmentId) =>
      _service.fetchEvidence(assignmentId);

  Future<RitualHistoryPage> loadHistory({String? cursor}) =>
      _service.fetchHistory(cursor: cursor);

  Future<RitualTransitionResult> reveal(DailyRitual current) => _transition(
    current: current,
    target: DailyRitualState.revealed,
    mutate: () => _service.reveal(current.assignmentId, current.version),
  );

  Future<RitualTransitionResult> complete(DailyRitual current) => _transition(
    current: current,
    target: DailyRitualState.completed,
    mutate: () => _service.complete(current.assignmentId, current.version),
  );

  Future<RitualTransitionResult> _transition({
    required DailyRitual current,
    required DailyRitualState target,
    required Future<DailyRitual> Function() mutate,
  }) async {
    try {
      final value = await mutate();
      return RitualTransitionResult(value: value, reconciled: false);
    } on Object catch (error) {
      if (error is! RitualAmbiguousMutation &&
          error is! OfflineException &&
          (error is! LoadFailure || error.phase != LoadPhase.conflict)) {
        rethrow;
      }
      final authoritative = await _service.fetchAssignment(
        current.assignmentId,
      );
      final reached =
          authoritative.state == target ||
          (target == DailyRitualState.revealed &&
              authoritative.state == DailyRitualState.completed);
      if (!reached) rethrow;
      return RitualTransitionResult(value: authoritative, reconciled: true);
    }
  }
}
