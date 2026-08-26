import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/invalidation_bus.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/cache/cached_read.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/funding/application/contribution_controller.dart';
import 'package:ritual_investing_app/features/funding/data/repository.dart';
import 'package:ritual_investing_app/features/funding/domain/model.dart';
import 'package:ritual_investing_app/features/portfolio/application/controller.dart';
import 'package:ritual_investing_app/features/portfolio/data/repository.dart';
import 'package:ritual_investing_app/features/portfolio/domain/model.dart';

void main() {
  test(
    'contribution rhythm provides an editable one-time amount suggestion',
    () {
      expect(
        ContributionDefaults.forRhythm(MemberContributionRhythm.weekly)
            .minorUnits,
        2500,
      );
      expect(
        ContributionDefaults.forRhythm(MemberContributionRhythm.monthly)
            .minorUnits,
        10000,
      );
      expect(
        ContributionDefaults.forRhythm(MemberContributionRhythm.notSure).label,
        contains('flexible'),
      );
    },
  );

  test(
    'lost response retries the same key and produces one ledger effect',
    () async {
      final fixture = await _Fixture.create();
      final events = <InvalidationEvent>[];
      fixture.bus.eventsFor(fixture.scope).listen(events.add);
      await fixture.controller.prepare(
        portfolioId: 'portfolio-a',
        sourceId: 'source-a',
        minorUnits: 2500,
      );

      await fixture.controller.confirm();
      expect(fixture.controller.phase, ContributionPhase.retryableFailure);
      expect(fixture.service.effectCount, 1);
      expect(
        await fixture.store.restore(
          fixture.scope,
          fixture.controller.operation,
        ),
        isNotNull,
      );
      expect(fixture.portfolios.refreshes, 0);

      fixture.controller.reviewSameContribution();
      await fixture.controller.confirm();

      expect(fixture.service.keys, ['contribution-key', 'contribution-key']);
      expect(fixture.service.effectCount, 1);
      expect(fixture.controller.phase, ContributionPhase.receipt);
      expect(
        await fixture.store.restore(
          fixture.scope,
          fixture.controller.operation,
        ),
        isNull,
      );
      expect(fixture.portfolios.refreshes, 1);
    expect(events.single.resource, InvalidationResource.ledger);
      expect(events.single.ledgerWatermark, 9);
    },
  );

  test(
    'restart reconciles authority and never auto-submits a pending command',
    () async {
      final fixture = await _Fixture.create();
      await fixture.controller.prepare(
        portfolioId: 'portfolio-a',
        sourceId: 'source-a',
        minorUnits: 2500,
      );
      await fixture.controller.confirm();
      final restarted = fixture.restart();

      await restarted.restorePending('portfolio-a');

      expect(restarted.phase, ContributionPhase.restoredReview);
      expect(fixture.service.keys, ['contribution-key']);
      expect(fixture.portfolios.refreshes, 1);
      await restarted.prepare(
        portfolioId: 'portfolio-a',
        sourceId: 'source-a',
        minorUnits: 2500,
      );
      expect(restarted.phase, ContributionPhase.review);
      expect(fixture.service.keys, ['contribution-key']);
    },
  );

  test(
    'editing a restored amount clears old command and requires a new key',
    () async {
      final fixture = await _Fixture.create(keys: ['old-key', 'new-key']);
      await fixture.controller.prepare(
        portfolioId: 'portfolio-a',
        sourceId: 'source-a',
        minorUnits: 2500,
      );
      await fixture.controller.confirm();
      final restarted = fixture.restart();
      await restarted.restorePending('portfolio-a');

      await restarted.prepare(
        portfolioId: 'portfolio-a',
        sourceId: 'source-a',
        minorUnits: 3000,
      );
      await restarted.confirm();

      expect(fixture.service.keys, ['old-key', 'new-key']);
      expect(restarted.phase, ContributionPhase.receipt);
    },
  );

  test('offline confirmation remains uncommitted and maps response states distinctly', () async {
    for (final entry in <(Object, ContributionPhase)>[
      (const OfflineException(), ContributionPhase.retryableFailure),
      (const LoadFailure(LoadPhase.forbidden), ContributionPhase.forbidden),
      (const LoadFailure(LoadPhase.conflict), ContributionPhase.conflictReview),
      (const LoadFailure(LoadPhase.throttled), ContributionPhase.throttled),
      (
        const LoadFailure(LoadPhase.terminalFailure),
        ContributionPhase.terminalFailure,
      ),
    ]) {
      final fixture = await _Fixture.create(failure: entry.$1);
      await fixture.controller.prepare(
        portfolioId: 'portfolio-a',
        sourceId: 'source-a',
        minorUnits: 2500,
      );
      await fixture.controller.confirm();
      expect(fixture.controller.phase, entry.$2);
      expect(fixture.controller.receipt, isNull);
      expect(
        fixture.portfolios.refreshes,
        entry.$2 == ContributionPhase.conflictReview ? 1 : 0,
      );
    }
  });

  test('concurrent confirm deduplicates one network mutation', () async {
    final fixture = await _Fixture.create(loseFirstResponse: false);
    await fixture.controller.prepare(
      portfolioId: 'portfolio-a',
      sourceId: 'source-a',
      minorUnits: 2500,
    );
    await Future.wait([
      fixture.controller.confirm(),
      fixture.controller.confirm(),
    ]);
    expect(fixture.service.keys, ['contribution-key']);
  });

  test('committed receipt never becomes a resubmittable command when refresh fails', () async {
    final fixture = await _Fixture.create(
      loseFirstResponse: false,
      refreshFailure: const OfflineException(),
    );
    await fixture.controller.prepare(
      portfolioId: 'portfolio-a',
      sourceId: 'source-a',
      minorUnits: 2500,
    );

    await fixture.controller.confirm();

    expect(fixture.controller.phase, ContributionPhase.receiptRefreshPending);
    expect(fixture.controller.receipt?.commandId, 'command-a');
    expect(
      await fixture.store.restore(fixture.scope, fixture.controller.operation),
      isNull,
    );
    expect(fixture.service.keys, ['contribution-key']);

    fixture.portfolios.refreshFailure = null;
    await fixture.controller.retryPortfolioRefresh();
    expect(fixture.controller.phase, ContributionPhase.receipt);
    expect(fixture.service.keys, ['contribution-key']);
  });

  test(
    'conflict refetch failure keeps command and draft without inviting retry',
    () async {
      final fixture = await _Fixture.create(
        failure: const LoadFailure(LoadPhase.conflict),
        refreshFailure: const OfflineException(),
      );
      await fixture.controller.prepare(
        portfolioId: 'portfolio-a',
        sourceId: 'source-a',
        minorUnits: 2500,
      );

      await fixture.controller.confirm();

      expect(
        fixture.controller.phase,
        ContributionPhase.reconciliationRequired,
      );
      expect(fixture.controller.draft?.minorUnits, 2500);
      expect(
        await fixture.store.restore(
          fixture.scope,
          fixture.controller.operation,
        ),
        isNotNull,
      );
      expect(fixture.controller.message, contains('Refresh'));
      fixture.controller.reviewSameContribution();
      await fixture.controller.confirm();
      expect(fixture.service.keys, ['contribution-key']);
    },
  );

  test('restored command blocks review and confirm until authority refresh succeeds', () async {
    final fixture = await _Fixture.create();
    await fixture.controller.prepare(
      portfolioId: 'portfolio-a',
      sourceId: 'source-a',
      minorUnits: 2500,
    );
    await fixture.controller.confirm();
    fixture.portfolios.refreshFailure = const OfflineException();
    final restarted = fixture.restart();

    await restarted.restorePending('portfolio-a');
    expect(restarted.phase, ContributionPhase.reconciliationRequired);
    expect(
      await restarted.prepare(
        portfolioId: 'portfolio-a',
        sourceId: 'source-a',
        minorUnits: 2500,
      ),
      isFalse,
    );
    await restarted.confirm();
    expect(fixture.service.keys, ['contribution-key']);

    fixture.portfolios.refreshFailure = null;
    await restarted.retryPendingReconciliation();
    expect(restarted.phase, ContributionPhase.restoredReview);
    expect(
      await restarted.prepare(
        portfolioId: 'portfolio-a',
        sourceId: 'source-a',
        minorUnits: 2500,
      ),
      isTrue,
    );
  });

  test(
    'same-key retries preserve the original protected creation time',
    () async {
      var clockCalls = 0;
      final fixture = await _Fixture.create(
        failure: const AmbiguousContributionFailure(),
        now: () => DateTime.utc(2026, 8, 25, 12, clockCalls++),
      );
      await fixture.controller.prepare(
        portfolioId: 'portfolio-a',
        sourceId: 'source-a',
        minorUnits: 2500,
      );
      await fixture.controller.confirm();
      final first = await fixture.store.restore(
        fixture.scope,
        fixture.controller.operation,
      );

      fixture.controller.reviewSameContribution();
      await fixture.controller.confirm();
      final retried = await fixture.store.restore(
        fixture.scope,
        fixture.controller.operation,
      );

      expect(retried?.command.createdAt, first?.command.createdAt);
      expect(clockCalls, 1);
    },
  );

  test('refresh-pending receipt blocks a new contribution and later publishes fresh watermark', () async {
    final fixture = await _Fixture.create(
      loseFirstResponse: false,
      refreshFailure: const OfflineException(),
    );
    final events = <InvalidationEvent>[];
    fixture.bus.eventsFor(fixture.scope).listen(events.add);
    await fixture.controller.prepare(
      portfolioId: 'portfolio-a',
      sourceId: 'source-a',
      minorUnits: 2500,
    );
    await fixture.controller.confirm();

    expect(events.single.ledgerWatermark, isNull);
    expect(
      await fixture.controller.prepare(
        portfolioId: 'portfolio-a',
        sourceId: 'source-a',
        minorUnits: 3000,
      ),
      isFalse,
    );
    fixture.portfolios.refreshFailure = null;
    await fixture.controller.retryPortfolioRefresh();

    expect(events.map((event) => event.ledgerWatermark), [null, 9]);
    expect(fixture.controller.phase, ContributionPhase.receipt);
  });

  test(
    'opening another portfolio clears volatile draft and receipt state',
    () async {
      final fixture = await _Fixture.create(loseFirstResponse: false);
      await fixture.controller.openPortfolio('portfolio-a');
      await fixture.controller.prepare(
        portfolioId: 'portfolio-a',
        sourceId: 'source-a',
        minorUnits: 2500,
      );
      await fixture.controller.confirm();
      expect(fixture.controller.receipt, isNotNull);

      await fixture.controller.openPortfolio('portfolio-b');

      expect(fixture.controller.phase, ContributionPhase.idle);
      expect(fixture.controller.receipt, isNull);
      expect(fixture.controller.draft, isNull);
      expect(
        fixture.controller.operation,
        'create_demo_contribution:portfolio-b',
      );
    },
  );

  test(
    'terminal command cleanup cannot reuse its discarded key in memory',
    () async {
      final fixture = await _Fixture.create(
        failure: const LoadFailure(LoadPhase.terminalFailure),
        keys: ['terminal-key', 'new-key'],
      );
      await fixture.controller.prepare(
        portfolioId: 'portfolio-a',
        sourceId: 'source-a',
        minorUnits: 2500,
      );
      await fixture.controller.confirm();
      fixture.service.failure = null;

      await fixture.controller.prepare(
        portfolioId: 'portfolio-a',
        sourceId: 'source-a',
        minorUnits: 2500,
      );
      await fixture.controller.confirm();

      expect(fixture.service.keys, ['terminal-key', 'new-key']);
    },
  );
}

class _Fixture {
  _Fixture({
    required this.scope,
    required this.store,
    required this.bus,
    required this.service,
    required this.portfolios,
    required this.controller,
    required this.keys,
  });

  static Future<_Fixture> create({
    Object? failure,
    bool loseFirstResponse = true,
    Object? refreshFailure,
    List<String> keys = const ['contribution-key', 'replacement-key'],
    DateTime Function()? now,
  }) async {
    const scope = CacheScope(accountId: 'account-a', resetGeneration: 3);
    final store = PendingCommandStore(storage: _MemoryProtectedStorage());
    final bus = InvalidationBus();
    final service = _ContributionService(
      failure: failure,
      loseFirstResponse: loseFirstResponse,
    );
    final portfolios = _PortfolioRepository()..refreshFailure = refreshFailure;
    final portfolioController = PortfolioController(
      repository: portfolios,
      bootstrapDefaultPortfolioId: 'portfolio-a',
      createKey: () => 'portfolio-key',
    );
    await portfolioController.load();
    await portfolioController.open('portfolio-a');
    final queue = List<String>.of(keys);
    final controller = ContributionController(
      repository: CachedFundingRepository(
        service: service,
        cache: MemoryReadCache(),
      ),
      portfolioController: portfolioController,
      pendingStore: store,
      invalidationBus: bus,
      scope: scope,
      createKey: () => queue.removeAt(0),
      now: now ?? () => DateTime.utc(2026, 8, 25, 12),
      rhythm: MemberContributionRhythm.weekly,
    );
    return _Fixture(
      scope: scope,
      store: store,
      bus: bus,
      service: service,
      portfolios: portfolios,
      controller: controller,
      keys: queue,
    );
  }

  final CacheScope scope;
  final PendingCommandStore store;
  final InvalidationBus bus;
  final _ContributionService service;
  final _PortfolioRepository portfolios;
  final ContributionController controller;
  final List<String> keys;

  ContributionController restart() => ContributionController(
    repository: CachedFundingRepository(
      service: service,
      cache: MemoryReadCache(),
    ),
    portfolioController: controller.portfolioController,
    pendingStore: store,
    invalidationBus: bus,
    scope: scope,
    createKey: () => keys.removeAt(0),
    now: () => DateTime.utc(2026, 8, 25, 12),
    rhythm: MemberContributionRhythm.weekly,
  );
}

class _ContributionService implements FundingService {
  _ContributionService({
    required this.failure,
    required this.loseFirstResponse,
  });
  Object? failure;
  final bool loseFirstResponse;
  final List<String> keys = [];
  int effectCount = 0;
  ContributionReceipt? committed;

  @override
  Future<ContributionReceipt> contribute(ContributionCommand command) async {
    keys.add(command.idempotencyKey);
    if (failure case final value?) throw value;
    committed ??= ContributionReceipt(
      commandId: 'command-a',
      portfolioVersion: 9,
      ledgerTransactionIds: const ['transaction-a'],
      demo: _fundingDemo,
    );
    if (effectCount == 0) effectCount += 1;
    if (loseFirstResponse && keys.length == 1) {
      throw const AmbiguousContributionFailure();
    }
    return committed!;
  }

  @override
  Future<List<FundingSource>> fetchSources() async => const [];
  @override
  Future<FundingSource> createSource({
    required FundingFixture fixture,
    required String idempotencyKey,
  }) => throw UnimplementedError();
  @override
  Future<void> deleteSource(String sourceId) => throw UnimplementedError();
}

class _PortfolioRepository implements PortfolioRepository {
  int refreshes = 0;
  int listLoads = 0;
  int watermark = 7;
  Object? refreshFailure;

  @override
  Future<RepositoryRead<PortfolioCollection>> loadList() async {
    listLoads += 1;
    if (listLoads > 1) refreshes += 1;
    if (listLoads > 1) {
      if (refreshFailure case final failure?) {
        throw failure;
      }
    }
    return RepositoryRead(
      value: PortfolioCollection(items: [_portfolio(watermark)]),
      isStale: false,
      committedAt: DateTime.utc(2026, 8, 25),
    );
  }

  @override
  Future<RepositoryRead<PortfolioDetail>> loadDetail(String portfolioId) async {
    if (refreshes > 0) watermark = 9;
    return RepositoryRead(
      value: PortfolioDetail(
        portfolio: _portfolio(watermark),
        holdings: const [],
        activity: const [],
        snapshots: const [],
      ),
      isStale: false,
      committedAt: DateTime.utc(2026, 8, 25),
    );
  }

  @override
  Future<void> archive({
    required String portfolioId,
    required int expectedVersion,
  }) => throw UnimplementedError();
  @override
  Future<PortfolioSummary> create({
    required String name,
    required String idempotencyKey,
  }) => throw UnimplementedError();
  @override
  Future<PortfolioSummary> rename({
    required String portfolioId,
    required String name,
    required int expectedVersion,
  }) => throw UnimplementedError();
}

PortfolioSummary _portfolio(int watermark) => PortfolioSummary(
  id: 'portfolio-a',
  name: 'Demo Portfolio',
  cashMinor: 5000,
  valuationMinor: 5000,
  currency: PortfolioCurrency.usd,
  status: PortfolioStatus.active,
  isDefault: true,
  version: watermark == 9 ? 9 : 8,
  ledgerWatermark: watermark,
  asOfTransactionId: 'transaction-a',
  demo: PortfolioDemoDisclosure(
    isDemo: true,
    observedAt: DateTime.utc(2026, 8, 25),
    sourceLabel: 'Demo ledger',
    limitations: const ['No real money.'],
  ),
  targetAllocation: const [],
);

final _fundingDemo = FundingDemoDisclosure(
  isDemo: true,
  observedAt: DateTime.utc(2026, 8, 25),
  sourceLabel: 'Demo ledger',
  limitations: const ['No real money moves.'],
);

class _MemoryProtectedStorage implements ProtectedStorage {
  final Map<String, String> values = {};
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<Map<String, String>> readAll() async => Map.of(values);
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
