import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/invalidation_bus.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/core/cache/cached_read.dart';
import 'package:ritual_investing_app/features/portfolio/application/controller.dart';
import 'package:ritual_investing_app/features/portfolio/data/repository.dart';
import 'package:ritual_investing_app/features/portfolio/domain/model.dart';
import 'package:ritual_investing_app/features/rebalancing/application/rebalance_controller.dart';
import 'package:ritual_investing_app/features/rebalancing/data/repository.dart';
import 'package:ritual_investing_app/features/rebalancing/domain/model.dart';

void main() {
  test(
    'rebalance preview commits once and refreshes authoritative portfolio',
    () async {
      final fixture = await _RebalanceFixture.create();
      await fixture.controller.preview(
        portfolioId: 'portfolio-a',
        allocations: const [
          RebalanceAllocation(assetId: 'asset-a', targetBps: 10000),
        ],
      );
      await fixture.controller.confirm();

      expect(fixture.service.keys, ['rebalance-key']);
      expect(fixture.service.ledgerEffects, 1);
      expect(fixture.controller.phase, RebalancePhase.receipt);
      expect(fixture.portfolios.detailLoads, greaterThanOrEqualTo(1));
    },
  );

  test(
    'expired preview clears command and requires a fresh preview and key',
    () async {
      final fixture = await _RebalanceFixture.create(
        commitFailure: const RebalanceCommitFailure.stalePreview(),
        keys: ['rebalance-key-1', 'rebalance-key-2'],
      );
      await fixture.controller.preview(
        portfolioId: 'portfolio-a',
        allocations: const [
          RebalanceAllocation(assetId: 'asset-a', targetBps: 10000),
        ],
      );
      await fixture.controller.confirm();
      expect(fixture.controller.phase, RebalancePhase.previewInvalidated);
      expect(fixture.controller.activePreview, isNull);

      fixture.service.commitFailure = null;
      await fixture.controller.preview(
        portfolioId: 'portfolio-a',
        allocations: const [
          RebalanceAllocation(assetId: 'asset-a', targetBps: 10000),
        ],
      );
      await fixture.controller.confirm();
      expect(fixture.service.keys, ['rebalance-key-1', 'rebalance-key-2']);
    },
  );

  test('restored rebalance never auto-submits before authority reconciliation and review', () async {
    final fixture = await _RebalanceFixture.create(ambiguousFirst: true);
    await fixture.controller.preview(
      portfolioId: 'portfolio-a',
      allocations: const [
        RebalanceAllocation(assetId: 'asset-a', targetBps: 10000),
      ],
    );
    await fixture.controller.confirm();
    final restarted = fixture.restart();
    await restarted.openPortfolio('portfolio-a');

    expect(restarted.phase, RebalancePhase.restoredReview);
    expect(fixture.service.keys, ['rebalance-key']);
    await restarted.reviewRestoredCommit();
    await restarted.confirm();
    expect(fixture.service.keys, ['rebalance-key', 'rebalance-key']);
    expect(fixture.service.ledgerEffects, 1);
  });

  test(
    'allocation validation rejects duplicates, ranges, and non-100% totals',
    () async {
      final fixture = await _RebalanceFixture.create();
      for (final allocations in [
        const [
          RebalanceAllocation(assetId: 'asset-a', targetBps: 5000),
          RebalanceAllocation(assetId: 'asset-a', targetBps: 5000),
        ],
        const [RebalanceAllocation(assetId: 'asset-a', targetBps: 10001)],
        const [RebalanceAllocation(assetId: 'asset-a', targetBps: 9999)],
      ]) {
        expect(
          await fixture.controller.preview(
            portfolioId: 'portfolio-a',
            allocations: allocations,
          ),
          isFalse,
        );
      }
      expect(fixture.service.previewCalls, 0);
    },
  );

  test('client expiry prevents rebalance commit traffic', () async {
    final fixture = await _RebalanceFixture.create();
    await fixture.controller.preview(
      portfolioId: 'portfolio-a',
      allocations: const [
        RebalanceAllocation(assetId: 'asset-a', targetBps: 10000),
      ],
    );
    fixture.clock.value = DateTime.utc(2026, 8, 25, 12, 16);
    await fixture.controller.confirm();
    expect(fixture.service.keys, isEmpty);
    expect(fixture.controller.phase, RebalancePhase.previewInvalidated);
  });

  test('reconciliation lock blocks replacement and unsafe discard', () async {
    final fixture = await _RebalanceFixture.create(ambiguousFirst: true);
    fixture.portfolios.failDetail = true;
    await fixture.controller.preview(
      portfolioId: 'portfolio-a',
      allocations: const [
        RebalanceAllocation(assetId: 'asset-a', targetBps: 10000),
      ],
    );
    await fixture.controller.confirm();
    expect(fixture.controller.phase, RebalancePhase.reconciliationRequired);
    expect(
      await fixture.controller.preview(
        portfolioId: 'portfolio-a',
        allocations: const [
          RebalanceAllocation(assetId: 'asset-b', targetBps: 10000),
        ],
      ),
      isFalse,
    );
    await fixture.controller.discardPendingCommit();
    expect(
      await fixture.store.restore(fixture.scope, fixture.controller.operation),
      isNotNull,
    );
    fixture.portfolios.failDetail = false;
    await fixture.controller.retryReconciliation();
    await fixture.controller.discardPendingCommit();
    expect(
      await fixture.store.restore(fixture.scope, fixture.controller.operation),
      isNull,
    );
  });

  test(
    'committed receipt is retained until delayed fresh watermark arrives',
    () async {
      final fixture = await _RebalanceFixture.create();
      final events = <InvalidationEvent>[];
      final subscription = fixture.bus
          .eventsFor(fixture.scope)
          .listen(events.add);
      addTearDown(subscription.cancel);
      fixture.portfolios.failDetail = true;
      await fixture.controller.preview(
        portfolioId: 'portfolio-a',
        allocations: const [
          RebalanceAllocation(assetId: 'asset-a', targetBps: 10000),
        ],
      );
      await fixture.controller.confirm();
      expect(fixture.controller.receipt?.commandId, 'command-r');
      expect(fixture.controller.phase, RebalancePhase.receiptRefreshPending);
      await fixture.controller.confirm();
      expect(fixture.service.keys, ['rebalance-key']);
      fixture.portfolios
        ..failDetail = false
        ..ledgerWatermark = 23;
      await fixture.controller.retryReceiptRefresh();
      expect(fixture.controller.phase, RebalancePhase.receipt);
      expect(events.last.ledgerWatermark, 23);
    },
  );

  test('already-balanced preview is a deliberate no-op', () async {
    final fixture = await _RebalanceFixture.create();
    fixture.service.previewFailure = const RebalanceAlreadyBalanced();
    expect(
      await fixture.controller.preview(
        portfolioId: 'portfolio-a',
        allocations: const [
          RebalanceAllocation(assetId: 'asset-a', targetBps: 10000),
        ],
      ),
      isFalse,
    );
    expect(fixture.controller.phase, RebalancePhase.alreadyBalanced);
    expect(fixture.service.keys, isEmpty);
  });
}

class _RebalanceFixture {
  _RebalanceFixture(
    this.service,
    this.portfolios,
    this.store,
    this.scope,
    this.bus,
    this.keys,
    this.clock,
    this.controller,
  );
  static Future<_RebalanceFixture> create({
    Object? commitFailure,
    bool ambiguousFirst = false,
    List<String> keys = const ['rebalance-key'],
  }) async {
    final service = _RebalanceService()
      ..commitFailure = commitFailure
      ..ambiguousFirst = ambiguousFirst;
    final portfolios = _PortfolioRepository();
    final portfolioController = PortfolioController(
      repository: portfolios,
      bootstrapDefaultPortfolioId: 'portfolio-a',
      createKey: () => 'portfolio-key',
    );
    await portfolioController.load();
    final store = PendingCommandStore(storage: _Storage());
    const scope = CacheScope(accountId: 'account-a', resetGeneration: 3);
    final bus = InvalidationBus();
    final clock = _Clock(DateTime.utc(2026, 8, 25, 12));
    final queue = [...keys];
    final controller = RebalanceController(
      repository: RebalanceRepository(service: service),
      portfolioController: portfolioController,
      pendingStore: store,
      invalidationBus: bus,
      scope: scope,
      createKey: () => queue.removeAt(0),
      now: clock.call,
    );
    return _RebalanceFixture(
      service,
      portfolios,
      store,
      scope,
      bus,
      queue,
      clock,
      controller,
    );
  }

  final _RebalanceService service;
  final _PortfolioRepository portfolios;
  final PendingCommandStore store;
  final CacheScope scope;
  final InvalidationBus bus;
  final List<String> keys;
  final _Clock clock;
  final RebalanceController controller;
  RebalanceController restart() => RebalanceController(
    repository: RebalanceRepository(service: service),
    portfolioController: controller.portfolioController,
    pendingStore: store,
    invalidationBus: bus,
    scope: scope,
    createKey: () => keys.removeAt(0),
    now: clock.call,
  );
}

class _RebalanceService implements RebalanceService {
  Object? commitFailure;
  Object? previewFailure;
  bool ambiguousFirst = false;
  final List<String> keys = [];
  final Map<String, RebalanceReceipt> _receipts = {};
  int ledgerEffects = 0;
  int previewCalls = 0;
  @override
  Future<RebalancePreview> preview(
    String portfolioId,
    List<RebalanceAllocation> allocations,
  ) async {
    previewCalls += 1;
    if (previewFailure case final failure?) throw failure;
    return RebalancePreview(
      id: 'preview-r',
      portfolioId: portfolioId,
      portfolioVersion: 7,
      targetAllocation: allocations,
      trades: const [
        RebalanceTrade(
          assetId: 'asset-a',
          side: RebalanceSide.buy,
          quantityValue: '0.5',
          quantityScale: 1,
          notionalMinor: 2500,
        ),
      ],
      expiresAt: DateTime.utc(2026, 8, 25, 12, 15),
      status: RebalancePreviewStatus.active,
      demo: _demo,
    );
  }

  @override
  Future<RebalanceReceipt> commit(RebalanceCommit command) async {
    keys.add(command.idempotencyKey);
    if (commitFailure case final failure?) throw failure;
    final existing = _receipts[command.idempotencyKey];
    if (existing != null) return existing;
    final receipt = RebalanceReceipt(
      commandId: 'command-r',
      portfolioVersion: 8,
      ledgerTransactionIds: const ['transaction-r'],
      demo: _demo,
    );
    _receipts[command.idempotencyKey] = receipt;
    ledgerEffects += 1;
    if (ambiguousFirst && keys.length == 1) {
      throw const AmbiguousRebalanceFailure();
    }
    return receipt;
  }
}

class _PortfolioRepository implements PortfolioRepository {
  int detailLoads = 0;
  bool failDetail = false;
  int ledgerWatermark = 11;
  @override
  Future<RepositoryRead<PortfolioCollection>> loadList() async =>
      RepositoryRead(
        value: PortfolioCollection(items: [_portfolio]),
        isStale: false,
        committedAt: DateTime.utc(2026, 8, 25),
      );
  @override
  Future<RepositoryRead<PortfolioDetail>> loadDetail(String portfolioId) async {
    detailLoads += 1;
    if (failDetail) throw const OfflineException();
    return RepositoryRead(
      value: PortfolioDetail(
        portfolio: _portfolioAt(ledgerWatermark),
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
  }) async {}
  @override
  Future<PortfolioSummary> create({
    required String name,
    required String idempotencyKey,
  }) async => _portfolio;
  @override
  Future<PortfolioSummary> rename({
    required String portfolioId,
    required String name,
    required int expectedVersion,
  }) async => _portfolio;
}

final _portfolio = PortfolioSummary(
  id: 'portfolio-a',
  name: 'Steady Orbit',
  cashMinor: 5000,
  valuationMinor: 10000,
  currency: PortfolioCurrency.usd,
  status: PortfolioStatus.active,
  isDefault: true,
  version: 7,
  ledgerWatermark: 11,
  asOfTransactionId: 'transaction-a',
  demo: PortfolioDemoDisclosure(
    isDemo: true,
    observedAt: DateTime.utc(2026, 8, 25),
    sourceLabel: 'Demo ledger',
    limitations: const ['No real money moves.'],
  ),
  targetAllocation: const [],
);
PortfolioSummary _portfolioAt(int watermark) => PortfolioSummary(
  id: _portfolio.id,
  name: _portfolio.name,
  cashMinor: _portfolio.cashMinor,
  valuationMinor: _portfolio.valuationMinor,
  currency: _portfolio.currency,
  status: _portfolio.status,
  isDefault: _portfolio.isDefault,
  version: _portfolio.version,
  ledgerWatermark: watermark,
  asOfTransactionId: _portfolio.asOfTransactionId,
  demo: _portfolio.demo,
  targetAllocation: _portfolio.targetAllocation,
);
final _demo = RebalanceDemoDisclosure(
  isDemo: true,
  observedAt: DateTime.utc(2026, 8, 25),
  sourceLabel: 'Demo ledger',
  limitations: const ['No real money moves.'],
);

class _Storage implements ProtectedStorage {
  final Map<String, String> values = {};
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<Map<String, String>> readAll() async => Map.of(values);
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _Clock {
  _Clock(this.value);
  DateTime value;
  DateTime call() => value;
}
