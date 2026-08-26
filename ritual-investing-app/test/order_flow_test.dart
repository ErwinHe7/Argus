import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/invalidation_bus.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/cache/cached_read.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/orders/application/order_controller.dart';
import 'package:ritual_investing_app/features/orders/data/repository.dart';
import 'package:ritual_investing_app/features/orders/domain/model.dart';
import 'package:ritual_investing_app/features/portfolio/application/controller.dart';
import 'package:ritual_investing_app/features/portfolio/data/repository.dart';
import 'package:ritual_investing_app/features/portfolio/domain/model.dart';

void main() {
  test(
    'fractional order uses one protected key and never retries automatically',
    () async {
      final fixture = await _OrderFixture.create(ambiguousFirstCommit: true);

      await fixture.controller.preview(
        const OrderDraft.quantity(
          portfolioId: 'portfolio-a',
          assetId: 'asset-a',
          side: OrderSide.buy,
          quantityValue: '0.125',
          quantityScale: 3,
        ),
      );
      await fixture.controller.confirm();

      expect(fixture.controller.phase, OrderCommandPhase.retryableFailure);
      expect(fixture.service.commitKeys, ['order-key']);
      expect(fixture.service.ledgerEffects, 1);
      expect(
        await fixture.store.restore(
          fixture.scope,
          fixture.controller.operation,
        ),
        isNotNull,
      );

      final restarted = fixture.restart();
      await restarted.openPortfolio('portfolio-a');
      expect(restarted.phase, OrderCommandPhase.restoredReview);
      expect(fixture.service.commitKeys, ['order-key']);

      await restarted.reviewRestoredCommit();
      await restarted.confirm();
      expect(fixture.service.commitKeys, ['order-key', 'order-key']);
      expect(fixture.service.ledgerEffects, 1);
      expect(restarted.phase, OrderCommandPhase.receipt);
      expect(fixture.portfolios.detailLoads, greaterThanOrEqualTo(2));
    },
  );

  test(
    'stale preview is discarded and requires a new preview and key',
    () async {
      final fixture = await _OrderFixture.create(
        commitFailure: const OrderCommitFailure.stalePreview(),
        keys: ['order-key-1', 'order-key-2'],
      );
      await fixture.controller.preview(
        const OrderDraft.notional(
          portfolioId: 'portfolio-a',
          assetId: 'asset-a',
          side: OrderSide.buy,
          minorUnits: 2500,
        ),
      );
      await fixture.controller.confirm();

      expect(fixture.controller.phase, OrderCommandPhase.previewInvalidated);
      expect(fixture.controller.activePreview, isNull);
      expect(
        await fixture.store.restore(
          fixture.scope,
          fixture.controller.operation,
        ),
        isNull,
      );

      fixture.service.commitFailure = null;
      await fixture.controller.preview(
        const OrderDraft.notional(
          portfolioId: 'portfolio-a',
          assetId: 'asset-a',
          side: OrderSide.buy,
          minorUnits: 2500,
        ),
      );
      await fixture.controller.confirm();
      expect(fixture.service.commitKeys, ['order-key-1', 'order-key-2']);
    },
  );

  test(
    'order list and detail preserve immutable fill and Demo disclosure',
    () async {
      final fixture = await _OrderFixture.create();
      await fixture.controller.openPortfolio('portfolio-a');
      await fixture.controller.openOrder('order-a');

      expect(fixture.controller.orders.single.commandId, 'command-a');
      expect(fixture.controller.selectedOrder?.fill?.quantityValue, '0.125');
      expect(fixture.controller.selectedOrder?.demo.isDemo, isTrue);
    },
  );

  test(
    'client expiry prevents commit traffic and clears protected review',
    () async {
      final fixture = await _OrderFixture.create();
      await fixture.controller.preview(
        const OrderDraft.notional(
          portfolioId: 'portfolio-a',
          assetId: 'asset-a',
          side: OrderSide.buy,
          minorUnits: 2500,
        ),
      );
      fixture.clock.value = DateTime.utc(2026, 8, 25, 12, 16);
      await fixture.controller.confirm();

      expect(fixture.service.commitKeys, isEmpty);
      expect(fixture.controller.phase, OrderCommandPhase.previewInvalidated);
      expect(
        await fixture.store.restore(
          fixture.scope,
          fixture.controller.operation,
        ),
        isNull,
      );
    },
  );

  test(
    'unresolved ambiguity blocks edits and discard until authority succeeds',
    () async {
      final fixture = await _OrderFixture.create(ambiguousFirstCommit: true);
      fixture.portfolios.failDetail = true;
      await fixture.controller.preview(
        const OrderDraft.notional(
          portfolioId: 'portfolio-a',
          assetId: 'asset-a',
          side: OrderSide.buy,
          minorUnits: 2500,
        ),
      );
      await fixture.controller.confirm();

      expect(
        fixture.controller.phase,
        OrderCommandPhase.reconciliationRequired,
      );
      expect(
        await fixture.controller.preview(
          const OrderDraft.notional(
            portfolioId: 'portfolio-a',
            assetId: 'asset-b',
            side: OrderSide.buy,
            minorUnits: 5000,
          ),
        ),
        isFalse,
      );
      await fixture.controller.discardPendingCommit();
      expect(
        await fixture.store.restore(
          fixture.scope,
          fixture.controller.operation,
        ),
        isNotNull,
      );

      fixture.portfolios.failDetail = false;
      await fixture.controller.retryReconciliation();
      await fixture.controller.discardPendingCommit();
      expect(
        await fixture.store.restore(
          fixture.scope,
          fixture.controller.operation,
        ),
        isNull,
      );
    },
  );

  test(
    'committed receipt survives failed refresh and publishes delayed watermark',
    () async {
      final fixture = await _OrderFixture.create();
      final events = <InvalidationEvent>[];
      final subscription = fixture.bus
          .eventsFor(fixture.scope)
          .listen(events.add);
      addTearDown(subscription.cancel);
      fixture.portfolios.failDetail = true;
      await fixture.controller.preview(
        const OrderDraft.notional(
          portfolioId: 'portfolio-a',
          assetId: 'asset-a',
          side: OrderSide.buy,
          minorUnits: 2500,
        ),
      );
      await fixture.controller.confirm();

      expect(fixture.controller.receipt?.commandId, 'command-a');
      expect(fixture.controller.phase, OrderCommandPhase.receiptRefreshPending);
      await fixture.controller.confirm();
      expect(fixture.service.commitKeys, ['order-key']);

      fixture.portfolios
        ..failDetail = false
        ..ledgerWatermark = 19;
      await fixture.controller.retryReceiptRefresh();
      expect(fixture.controller.phase, OrderCommandPhase.receipt);
      expect(events.last.ledgerWatermark, 19);
    },
  );

  test('cross-portfolio detail fails closed', () async {
    final fixture = await _OrderFixture.create();
    await fixture.controller.openPortfolio('portfolio-b');
    await fixture.controller.openOrder('order-a');
    expect(fixture.controller.selectedOrder, isNull);
    expect(fixture.controller.phase, OrderCommandPhase.forbidden);
  });

  test(
    'throttling preserves unchanged review while terminal rejection clears it',
    () async {
      final throttled = await _OrderFixture.create(
        commitFailure: const LoadFailure(LoadPhase.throttled),
      );
      await throttled.controller.preview(
        const OrderDraft.notional(
          portfolioId: 'portfolio-a',
          assetId: 'asset-a',
          side: OrderSide.buy,
          minorUnits: 2500,
        ),
      );
      await throttled.controller.confirm();
      expect(throttled.controller.phase, OrderCommandPhase.throttled);
      expect(
        await throttled.store.restore(
          throttled.scope,
          throttled.controller.operation,
        ),
        isNotNull,
      );
      await throttled.controller.reviewRestoredCommit();
      expect(throttled.controller.phase, OrderCommandPhase.review);

      final terminal = await _OrderFixture.create(
        commitFailure: const LoadFailure(LoadPhase.terminalFailure),
      );
      await terminal.controller.preview(
        const OrderDraft.notional(
          portfolioId: 'portfolio-a',
          assetId: 'asset-a',
          side: OrderSide.buy,
          minorUnits: 2500,
        ),
      );
      await terminal.controller.confirm();
      expect(terminal.controller.phase, OrderCommandPhase.terminalFailure);
      expect(terminal.controller.activePreview, isNull);
      expect(
        await terminal.store.restore(
          terminal.scope,
          terminal.controller.operation,
        ),
        isNull,
      );
    },
  );
}

class _OrderFixture {
  _OrderFixture({
    required this.service,
    required this.portfolios,
    required this.store,
    required this.scope,
    required this.bus,
    required this.clock,
    required this.keys,
    required this.controller,
  });

  static Future<_OrderFixture> create({
    bool ambiguousFirstCommit = false,
    Object? commitFailure,
    List<String> keys = const ['order-key'],
  }) async {
    final service = _OrderService()
      ..ambiguousFirstCommit = ambiguousFirstCommit
      ..commitFailure = commitFailure;
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
    late final _OrderFixture fixture;
    final controller = OrderController(
      repository: OrderRepository(service: service),
      portfolioController: portfolioController,
      pendingStore: store,
      invalidationBus: bus,
      scope: scope,
      createKey: () => queue.removeAt(0),
      now: clock.call,
    );
    fixture = _OrderFixture(
      service: service,
      portfolios: portfolios,
      store: store,
      scope: scope,
      bus: bus,
      clock: clock,
      keys: queue,
      controller: controller,
    );
    return fixture;
  }

  final _OrderService service;
  final _PortfolioRepository portfolios;
  final PendingCommandStore store;
  final CacheScope scope;
  final InvalidationBus bus;
  final _Clock clock;
  final List<String> keys;
  final OrderController controller;

  OrderController restart() => OrderController(
    repository: OrderRepository(service: service),
    portfolioController: controller.portfolioController,
    pendingStore: store,
    invalidationBus: bus,
    scope: scope,
    createKey: () => keys.removeAt(0),
    now: clock.call,
  );
}

class _OrderService implements OrderService {
  bool ambiguousFirstCommit = false;
  Object? commitFailure;
  final List<String> commitKeys = [];
  final Map<String, OrderReceipt> _receipts = {};
  int ledgerEffects = 0;

  @override
  Future<OrderPreview> preview(OrderDraft draft) async => OrderPreview(
    id: 'preview-a',
    portfolioId: draft.portfolioId,
    portfolioVersion: 7,
    assetId: draft.assetId,
    symbol: 'QPW',
    side: draft.side,
    notionalMinor: 2500,
    quantityValue: '0.125',
    quantityScale: 3,
    frozenPriceMinor: 20000,
    quoteSnapshotId: 'quote-a',
    observedAt: DateTime.utc(2026, 8, 25, 12),
    expiresAt: DateTime.utc(2026, 8, 25, 12, 15),
    status: OrderPreviewStatus.active,
    demo: _demo,
  );

  @override
  Future<OrderReceipt> commit(OrderCommit command) async {
    commitKeys.add(command.idempotencyKey);
    if (commitFailure case final failure?) throw failure;
    final existing = _receipts[command.idempotencyKey];
    if (existing != null) return existing;
    final receipt = OrderReceipt(
      commandId: 'command-a',
      portfolioVersion: 8,
      ledgerTransactionIds: const ['transaction-a'],
      demo: _demo,
    );
    _receipts[command.idempotencyKey] = receipt;
    ledgerEffects += 1;
    if (ambiguousFirstCommit && commitKeys.length == 1) {
      throw const AmbiguousOrderFailure();
    }
    return receipt;
  }

  @override
  Future<List<OrderView>> list(String portfolioId) async => [_order];

  @override
  Future<OrderView> get(String orderId) async => _order;
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

final _demo = OrderDemoDisclosure(
  isDemo: true,
  observedAt: DateTime.utc(2026, 8, 25),
  sourceLabel: 'Deterministic Demo ledger',
  limitations: const ['No real money moves.'],
);

final _order = OrderView(
  id: 'order-a',
  portfolioId: 'portfolio-a',
  commandId: 'command-a',
  assetId: 'asset-a',
  symbol: 'QPW',
  side: OrderSide.buy,
  status: OrderStatus.accepted,
  notionalMinor: 2500,
  quantityValue: '0.125',
  quantityScale: 3,
  fill: OrderFill(
    quantityValue: '0.125',
    quantityScale: 3,
    priceMinor: 20000,
    filledAt: DateTime.utc(2026, 8, 25),
  ),
  demo: _demo,
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
