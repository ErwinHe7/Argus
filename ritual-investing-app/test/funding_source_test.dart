import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/cache/cached_read.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/funding/application/funding_source_controller.dart';
import 'package:ritual_investing_app/features/funding/data/repository.dart';
import 'package:ritual_investing_app/features/funding/domain/model.dart';

void main() {
  test('funding creation accepts only a typed fictional fixture', () async {
    final service = _FundingService();
    final controller = FundingSourceController(
      repository: CachedFundingRepository(
        service: service,
        cache: MemoryReadCache(),
      ),
      createKey: () => 'funding-key',
    );

    await controller.create(FundingFixture.moonReserve);

    expect(service.created, [(FundingFixture.moonReserve, 'funding-key')]);
    expect(
      controller.state.value?.items.single.displayLabel,
      'Moon Reserve (fictional)',
    );
    expect(controller.state.value?.items.single.demo.isDemo, isTrue);
  });

  test(
    'funding delete is authoritative and keeps server conflict distinct',
    () async {
      final service = _FundingService()
        ..deleteFailure = const FundingFailure.fundingSourceInUse();
      final controller = FundingSourceController(
        repository: CachedFundingRepository(
          service: service,
          cache: MemoryReadCache(),
        ),
        createKey: () => 'funding-key',
      );
      await controller.load();

      await controller.delete('source-a');

      expect(controller.message, contains('active recurring plan'));
      expect(
        controller.state.value?.items.single.status,
        FundingSourceStatus.active,
      );
    },
  );

  test(
    'ambiguous funding create retries the same typed fixture and key',
    () async {
      final service = _FundingService()
        ..createFailure = const OfflineException();
      var generated = 0;
      final controller = FundingSourceController(
        repository: CachedFundingRepository(
          service: service,
          cache: MemoryReadCache(),
        ),
        createKey: () => 'funding-key-${generated++}',
      );

      await controller.create(FundingFixture.moonReserve);
      expect(controller.pendingFixture, FundingFixture.moonReserve);
      service.createFailure = null;
      await controller.retryPendingCreate();

      expect(service.created, [
        (FundingFixture.moonReserve, 'funding-key-0'),
        (FundingFixture.moonReserve, 'funding-key-0'),
      ]);
      expect(controller.pendingFixture, isNull);
    },
  );

  test(
    'second source tap cannot replace an in-flight fixture command',
    () async {
      final service = _FundingService()
        ..createCompleter = Completer<FundingSource>();
      var generated = 0;
      final controller = FundingSourceController(
        repository: CachedFundingRepository(
          service: service,
          cache: MemoryReadCache(),
        ),
        createKey: () => 'funding-key-${generated++}',
      );

      final first = controller.create(FundingFixture.moonReserve);
      await Future<void>.delayed(Duration.zero);
      final second = controller.create(FundingFixture.constellationSavings);
      service.createCompleter!.complete(_source());
      await Future.wait([first, second]);

      expect(service.created, [(FundingFixture.moonReserve, 'funding-key-0')]);
      expect(generated, 1);
    },
  );
}

class _FundingService implements FundingService {
  final List<(FundingFixture, String)> created = [];
  FundingFailure? deleteFailure;
  Object? createFailure;
  Completer<FundingSource>? createCompleter;
  FundingSource current = _source();

  @override
  Future<List<FundingSource>> fetchSources() async => [current];

  @override
  Future<FundingSource> createSource({
    required FundingFixture fixture,
    required String idempotencyKey,
  }) async {
    created.add((fixture, idempotencyKey));
    if (createFailure case final failure?) throw failure;
    if (createCompleter case final completer?) return completer.future;
    current = _source(fixture: fixture);
    return current;
  }

  @override
  Future<void> deleteSource(String sourceId) async {
    if (deleteFailure case final failure?) throw failure;
    current = _source(status: FundingSourceStatus.inactive);
  }

  @override
  Future<ContributionReceipt> contribute(ContributionCommand command) =>
      throw UnimplementedError();
}

FundingSource _source({
  FundingFixture fixture = FundingFixture.moonReserve,
  FundingSourceStatus status = FundingSourceStatus.active,
}) => FundingSource(
  id: 'source-a',
  fixture: fixture,
  displayLabel: fixture == FundingFixture.moonReserve
      ? 'Moon Reserve (fictional)'
      : 'Constellation Savings (fictional)',
  fictionalLast4: fixture == FundingFixture.moonReserve ? '1108' : '2042',
  status: status,
  demo: FundingDemoDisclosure(
    isDemo: true,
    observedAt: DateTime.utc(2026, 8, 25),
    sourceLabel: 'Deterministic Demo ledger',
    limitations: const ['Fictional source; no bank connection.'],
  ),
);
