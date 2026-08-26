import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/cache/cached_read.dart';
import 'package:ritual_investing_app/features/portfolio/application/controller.dart';
import 'package:ritual_investing_app/features/portfolio/data/repository.dart';
import 'package:ritual_investing_app/features/portfolio/domain/model.dart';

void main() {
  test('bootstrap default is selected even when it is not first', () async {
    final repository = _PortfolioRepository();
    final controller = PortfolioController(
      repository: repository,
      bootstrapDefaultPortfolioId: 'portfolio-b',
      createKey: () => 'create-key',
    );

    await controller.load();

    expect(controller.selectedPortfolioId, 'portfolio-b');
    expect(controller.selected?.isDefault, isTrue);
  });

  test('server conflict preserves rename draft for explicit review', () async {
    final repository = _PortfolioRepository()
      ..renameFailure = const LoadFailure(LoadPhase.conflict);
    final controller = PortfolioController(
      repository: repository,
      bootstrapDefaultPortfolioId: 'portfolio-b',
      createKey: () => 'create-key',
    );
    await controller.load();
    await controller.open('portfolio-b');

    await controller.renameSelected('Steady Orbit');

    expect(controller.detailState.phase, LoadPhase.conflict);
    expect(controller.pendingName, 'Steady Orbit');
    expect(controller.requiresConflictReview, isTrue);
    expect(repository.renameVersions, [8]);
  });

  test(
    'archive sends server version and surfaces authoritative protection',
    () async {
      final repository = _PortfolioRepository()
        ..archiveFailure = const LoadFailure(LoadPhase.conflict);
      final controller = PortfolioController(
        repository: repository,
        bootstrapDefaultPortfolioId: 'portfolio-b',
        createKey: () => 'create-key',
      );
      await controller.load();
      await controller.open('portfolio-b');

      await controller.archiveSelected();

      expect(repository.archiveVersions, [8]);
      expect(controller.detailState.phase, LoadPhase.conflict);
      expect(controller.message, contains('server kept this portfolio active'));
    },
  );

  test('concurrent portfolio create reuses one command execution', () async {
    final repository = _PortfolioRepository();
    final controller = PortfolioController(
      repository: repository,
      bootstrapDefaultPortfolioId: 'portfolio-b',
      createKey: () => 'create-key',
    );
    await controller.load();

    final first = controller.create('Moon Garden');
    final second = controller.create('Moon Garden');
    await Future.wait([first, second]);

    expect(repository.createKeys, ['create-key']);
  });

  test('ambiguous portfolio create keeps one key for explicit retry', () async {
    final repository = _PortfolioRepository()
      ..createFailure = const PortfolioAmbiguousMutation();
    var generated = 0;
    final controller = PortfolioController(
      repository: repository,
      bootstrapDefaultPortfolioId: 'portfolio-b',
      createKey: () => 'create-key-${generated++}',
    );
    await controller.load();

    await controller.create('Moon Garden');
    repository.createFailure = null;
    await controller.retryPendingCreate();

    expect(repository.createKeys, ['create-key-0', 'create-key-0']);
    expect(controller.pendingCreateName, isNull);
  });

  test(
    'failed authoritative conflict refetch keeps rename draft retryable',
    () async {
      final repository = _PortfolioRepository()
        ..renameFailure = const LoadFailure(LoadPhase.conflict)
        ..detailFailureAfterFirst = const OfflineException();
      final controller = PortfolioController(
        repository: repository,
        bootstrapDefaultPortfolioId: 'portfolio-b',
        createKey: () => 'create-key',
      );
      await controller.load();
      await controller.open('portfolio-b');

      await controller.renameSelected('Steady Orbit');

      expect(controller.detailState.phase, LoadPhase.retryableFailure);
      expect(controller.pendingName, 'Steady Orbit');
      expect(controller.requiresConflictReview, isFalse);
    },
  );

  test(
    'second create tap cannot replace the in-flight portfolio command',
    () async {
      final repository = _PortfolioRepository()
        ..createCompleter = Completer<PortfolioSummary>();
      var generated = 0;
      final controller = PortfolioController(
        repository: repository,
        bootstrapDefaultPortfolioId: 'portfolio-b',
        createKey: () => 'create-key-${generated++}',
      );
      await controller.load();

      final first = controller.create('Moon Garden');
      await Future<void>.delayed(Duration.zero);
      final second = controller.create('Different Garden');
      repository.createCompleter!.complete(
        _portfolio('portfolio-c', version: 1, name: 'Moon Garden'),
      );
      await Future.wait([first, second]);

      expect(repository.createNames, ['Moon Garden']);
      expect(repository.createKeys, ['create-key-0']);
      expect(generated, 1);
    },
  );

  test(
    'offline rename preserves draft and requires fresh authority before retry',
    () async {
      final repository = _PortfolioRepository()
        ..renameFailure = const OfflineException();
      final controller = PortfolioController(
        repository: repository,
        bootstrapDefaultPortfolioId: 'portfolio-b',
        createKey: () => 'create-key',
      );
      await controller.load();
      await controller.open('portfolio-b');

      await controller.renameSelected('Steady Orbit');
      expect(controller.detailState.phase, LoadPhase.retryableFailure);
      expect(controller.pendingName, 'Steady Orbit');
      await controller.reviewAndRetryRename();
      expect(repository.renameVersions, [8]);

      repository.renameFailure = null;
      await controller.refreshRenameAuthority();
      expect(controller.requiresConflictReview, isTrue);
      await controller.reviewAndRetryRename();
      expect(repository.renameVersions, [8, 8]);
    },
  );

  test('ambiguous archive reconciles active server authority before explicit retry', () async {
    final repository = _PortfolioRepository()
      ..archiveFailure = const OfflineException();
    final controller = PortfolioController(
      repository: repository,
      bootstrapDefaultPortfolioId: 'portfolio-b',
      createKey: () => 'create-key',
    );
    await controller.load();
    await controller.open('portfolio-b');

    await controller.archiveSelected();
    expect(repository.archiveVersions, [8]);
    expect(controller.requiresArchiveReview, isTrue);

    repository.archiveFailure = null;
    await controller.reviewAndRetryArchive();
    expect(repository.archiveVersions, [8, 8]);
  });
}

class _PortfolioRepository implements PortfolioRepository {
  Object? renameFailure;
  Object? archiveFailure;
  Object? createFailure;
  Object? detailFailureAfterFirst;
  Completer<PortfolioSummary>? createCompleter;
  int detailLoads = 0;
  final List<int> renameVersions = [];
  final List<int> archiveVersions = [];
  final List<String> createKeys = [];
  final List<String> createNames = [];

  @override
  Future<RepositoryRead<PortfolioCollection>> loadList() async =>
      RepositoryRead(
        value: PortfolioCollection(
          items: [
            _portfolio('portfolio-a', version: 2),
            _portfolio('portfolio-b', version: 8, isDefault: true),
          ],
        ),
        isStale: false,
        committedAt: DateTime.utc(2026, 8, 25),
      );

  @override
  Future<RepositoryRead<PortfolioDetail>> loadDetail(
    String portfolioId,
  ) async => RepositoryRead(
    value: () {
      detailLoads += 1;
      if (detailLoads > 1) {
        if (detailFailureAfterFirst case final failure?) throw failure;
      }
      return PortfolioDetail(
        portfolio: _portfolio(portfolioId, version: 8, isDefault: true),
        holdings: const [],
        activity: const [],
        snapshots: const [],
      );
    }(),
    isStale: false,
    committedAt: DateTime.utc(2026, 8, 25),
  );

  @override
  Future<PortfolioSummary> create({
    required String name,
    required String idempotencyKey,
  }) async {
    createKeys.add(idempotencyKey);
    createNames.add(name);
    await Future<void>.delayed(Duration.zero);
    if (createFailure case final failure?) throw failure;
    if (createCompleter case final completer?) return completer.future;
    return _portfolio('portfolio-c', version: 1, name: name);
  }

  @override
  Future<PortfolioSummary> rename({
    required String portfolioId,
    required String name,
    required int expectedVersion,
  }) async {
    renameVersions.add(expectedVersion);
    if (renameFailure case final failure?) throw failure;
    return _portfolio(portfolioId, version: expectedVersion + 1, name: name);
  }

  @override
  Future<void> archive({
    required String portfolioId,
    required int expectedVersion,
  }) async {
    archiveVersions.add(expectedVersion);
    if (archiveFailure case final failure?) throw failure;
  }
}

PortfolioSummary _portfolio(
  String id, {
  required int version,
  bool isDefault = false,
  String name = 'Demo Portfolio',
}) => PortfolioSummary(
  id: id,
  name: name,
  cashMinor: 1000,
  valuationMinor: 1000,
  currency: PortfolioCurrency.usd,
  status: PortfolioStatus.active,
  isDefault: isDefault,
  version: version,
  ledgerWatermark: 2,
  asOfTransactionId: 'transaction-a',
  demo: PortfolioDemoDisclosure(
    isDemo: true,
    observedAt: DateTime.utc(2026, 8, 25),
    sourceLabel: 'Deterministic Demo ledger',
    limitations: const ['No real money moves.'],
  ),
  targetAllocation: const [],
);
