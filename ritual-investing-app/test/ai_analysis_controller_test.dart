import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/features/ai_analysis/application/controller.dart';
import 'package:ritual_investing_app/features/ai_analysis/data/repository.dart';
import 'package:ritual_investing_app/features/ai_analysis/domain/model.dart';
import 'package:ritual_investing_app/internal_preview/ai_analysis_fixture.dart';

void main() {
  group('AiAnalysisController', () {
    test('publishes a fresh snapshot as ready with its commit time', () async {
      final snapshot = buildFixtureAiAnalysisSnapshot();
      final now = DateTime.utc(2026, 9, 1, 12);
      final controller = AiAnalysisController(
        repository: AiAnalysisRepository(
          service: _MutableAiAnalysisService(snapshot),
        ),
        utcClock: () => now,
      );

      await controller.load();

      expect(controller.state.phase, LoadPhase.ready);
      expect(controller.state.value, same(snapshot));
      expect(controller.state.committedAt, now);
    });

    test('fails closed when a snapshot has expired', () async {
      final snapshot = buildFixtureAiAnalysisSnapshot();
      final controller = AiAnalysisController(
        repository: AiAnalysisRepository(
          service: _MutableAiAnalysisService(snapshot),
        ),
        // expiresAt is an exclusive freshness boundary.
        utcClock: () => snapshot.expiresAt,
      );

      await controller.load();

      expect(controller.state.phase, LoadPhase.terminalFailure);
      expect(controller.state.value, isNull);
      expect(controller.state.committedAt, isNull);
    });

    test(
      'fetch errors are retryable and never retain stale risk data',
      () async {
        final snapshot = buildFixtureAiAnalysisSnapshot();
        final service = _MutableAiAnalysisService(snapshot);
        final controller = AiAnalysisController(
          repository: AiAnalysisRepository(service: service),
          utcClock: () => DateTime.utc(2026, 9, 1, 12),
        );

        await controller.load();
        expect(controller.state.phase, LoadPhase.ready);
        expect(controller.state.value, same(snapshot));

        service.failure = StateError('provider unavailable');
        await controller.load();

        expect(controller.state.phase, LoadPhase.retryableFailure);
        expect(controller.state.value, isNull);
        expect(controller.state.committedAt, isNull);
      },
    );
  });
}

class _MutableAiAnalysisService implements AiAnalysisService {
  _MutableAiAnalysisService(this.snapshot);

  final AiAnalysisSnapshot snapshot;
  Object? failure;

  @override
  Future<AiAnalysisSnapshot> fetch() async {
    if (failure case final error?) {
      throw error;
    }
    return snapshot;
  }
}
