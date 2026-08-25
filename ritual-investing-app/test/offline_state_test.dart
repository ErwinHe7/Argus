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
