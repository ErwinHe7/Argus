import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/core/api/idempotent_mutation.dart';
import 'package:ritual_investing_app/features/ritual/application/daily_ritual_controller.dart';
import 'package:ritual_investing_app/features/ritual/data/daily_ritual_repository.dart';
import 'package:ritual_investing_app/features/ritual/domain/daily_ritual.dart';

void main() {
  test(
    'offline without cache is retryable and never reports success',
    () async {
      final controller = DailyRitualController(
        repository: DailyRitualRepository(
          service: _OfflineService(),
          cache: MemoryReadCache(),
        ),
      );
      await controller.load();
      expect(controller.state.phase, LoadPhase.retryableFailure);
      expect(controller.state.value, isNull);
    },
  );

  test(
    'offline mutation stays uncommitted and retries with one idempotency key',
    () async {
      final service = _LostResponseService();
      final mutation = IdempotentMutation<String>(
        service: service,
        createKey: () => 'stable-idempotency-key',
      );
      await mutation.commit();
      expect(mutation.state.phase, MutationPhase.retryableFailure);
      expect(mutation.state.value, isNull);
      await mutation.commit();
      expect(mutation.state.phase, MutationPhase.committed);
      expect(mutation.state.value, 'one-server-result');
      expect(service.keys, [
        'stable-idempotency-key',
        'stable-idempotency-key',
      ]);
      expect(service.resultsCreated, 1);
    },
  );

  test(
    'offline Finish keeps the confirmed reading and disables blind replay',
    () async {
      final service = _OfflineFinishService();
      final controller = DailyRitualController(
        repository: DailyRitualRepository(
          service: service,
          cache: MemoryReadCache(),
        ),
      );
      await controller.load();

      final outcome = await controller.complete(refreshHistory: false);
      final replay = await controller.complete(refreshHistory: false);

      expect(
        outcome?.disposition,
        RitualOperationDisposition.authorityUnavailable,
      );
      expect(controller.state.value?.state, DailyRitualState.revealed);
      expect(controller.mutationAuthorityEnabled, isFalse);
      expect(service.completeCalls, 1);
      expect(replay, isNull);
    },
  );
}

class _OfflineService implements DailyRitualService {
  @override
  Future<DailyRitual> fetchDaily({DailyRitualMode? mode}) =>
      Future.error(const OfflineException());

  @override
  Future<DailyRitual> fetchAssignment(String assignmentId) => fetchDaily();
  @override
  Future<List<RitualEvidenceDetail>> fetchEvidence(String assignmentId) =>
      Future.error(const OfflineException());
  @override
  Future<RitualHistoryPage> fetchHistory({String? cursor}) =>
      Future.error(const OfflineException());
  @override
  Future<DailyRitual> reveal(String assignmentId, int version) => fetchDaily();
  @override
  Future<DailyRitual> complete(String assignmentId, int version) =>
      fetchDaily();
}

class _LostResponseService implements MutationService<String> {
  final List<String> keys = [];
  int resultsCreated = 0;
  @override
  Future<String> execute(String idempotencyKey) async {
    keys.add(idempotencyKey);
    if (resultsCreated == 0) {
      resultsCreated++;
      throw const OfflineException();
    }
    return 'one-server-result';
  }
}

class _OfflineFinishService implements DailyRitualService {
  int completeCalls = 0;

  @override
  Future<DailyRitual> fetchDaily({DailyRitualMode? mode}) async =>
      _revealedRitual();

  @override
  Future<DailyRitual> fetchAssignment(String assignmentId) =>
      Future.error(const OfflineException());

  @override
  Future<List<RitualEvidenceDetail>> fetchEvidence(String assignmentId) =>
      Future.error(const OfflineException());

  @override
  Future<RitualHistoryPage> fetchHistory({String? cursor}) =>
      Future.error(const OfflineException());

  @override
  Future<DailyRitual> reveal(String assignmentId, int version) =>
      Future.error(const OfflineException());

  @override
  Future<DailyRitual> complete(String assignmentId, int version) {
    completeCalls += 1;
    return Future.error(const OfflineException());
  }
}

DailyRitual _revealedRitual() => DailyRitual(
  assignmentId: 'offline-assignment',
  date: DateTime.utc(2026, 9, 2),
  mode: DailyRitualMode.tarot,
  revision: const RitualRevision(id: 'offline-revision', number: 1),
  title: 'Strength',
  art: const RitualArt(key: 'strength', alt: 'Strength tarot card'),
  interpretation: 'Keep the confirmed reading visible.',
  guidance: 'Retry only after authority is restored.',
  marketLabel: 'Educational context',
  ideas: const [],
  evidence: const [],
  rowan: const RitualCounsel(
    scriptRevisionId: 'offline-counsel',
    surface: 'daily_ritual',
    body: 'The reading remains available.',
    riskFooter: 'Not investment advice.',
  ),
  version: 2,
  state: DailyRitualState.revealed,
  revealedAt: DateTime.utc(2026, 9, 2, 12),
  completedAt: null,
  demo: RitualDisclosure(
    isDemo: true,
    observedAt: DateTime.utc(2026, 9, 2, 11),
    sourceLabel: 'Deterministic fixture',
    limitations: const ['No live provider data.'],
  ),
);
