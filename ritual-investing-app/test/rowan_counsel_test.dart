import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/rowan/application/controller.dart';
import 'package:ritual_investing_app/features/rowan/data/repository.dart';
import 'package:ritual_investing_app/features/rowan/domain/model.dart';

void main() {
  test(
    'only four bounded surface/context/resource combinations are representable',
    () {
      expect(RowanRequest.dailyRitual(_assignment).contextCode, 'daily');
      expect(RowanRequest.evidence(_assignment).contextCode, 'evidence');
      expect(RowanRequest.assetCodex(_asset).contextCode, 'asset');
      expect(RowanRequest.coven(_coven).contextCode, 'coven');
      expect(
        () => RowanRequest.assetCodex('foreign-or-client-prompt'),
        throwsArgumentError,
      );
    },
  );

  test(
    'request contains identifiers only and preserves server script revision',
    () async {
      final service = _RowanService();
      final controller = RowanController(
        repository: RowanRepository(service: service, cache: MemoryReadCache()),
      );

      await controller.explain(RowanRequest.assetCodex(_asset));

      expect(service.requests.single.surface, RowanSurface.assetCodex);
      expect(service.requests.single.resourceId, _asset);
      expect(controller.state.value!.scriptRevisionId, _revision);
      expect(controller.state.value!.body, contains('choice remains yours'));
    },
  );

  for (final failure in [
    const LoadFailure(LoadPhase.empty),
    const LoadFailure(LoadPhase.throttled),
    const LoadFailure(LoadPhase.retryableFailure),
  ]) {
    test(
      '${failure.phase} is non-blocking to the underlying resource',
      () async {
        var underlyingActionCount = 0;
        final controller = RowanController(
          repository: RowanRepository(
            service: _FailingRowanService(failure),
            cache: MemoryReadCache(),
          ),
        );

        await controller.explain(RowanRequest.evidence(_assignment));
        underlyingActionCount += 1;

        expect(controller.state.phase, failure.phase);
        expect(underlyingActionCount, 1);
      },
    );
  }
}

const _assignment = '00000000-0000-4000-8000-000000000101';
const _asset = '00000000-0000-4000-8000-000000000201';
const _coven = '00000000-0000-4000-8000-000000000301';
const _revision = '00000000-0000-4000-8000-000000000401';

class _RowanService implements RowanService {
  final List<RowanRequest> requests = [];

  @override
  Future<RowanCounselResult> fetch(RowanRequest request) async {
    requests.add(request);
    return const RowanCounselResult(
      scriptRevisionId: _revision,
      surface: RowanSurface.assetCodex,
      body: 'Separate the observed evidence from the story; the choice remains yours.',
      riskFooter: 'Deterministic Demo counsel; not investment advice.',
    );
  }
}

class _FailingRowanService implements RowanService {
  const _FailingRowanService(this.failure);
  final LoadFailure failure;

  @override
  Future<RowanCounselResult> fetch(RowanRequest request) =>
      Future.error(failure);
}
