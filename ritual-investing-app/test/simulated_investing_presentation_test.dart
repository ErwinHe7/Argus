import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/api/invalidation_bus.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/cache/cached_read.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/funding/application/funding_source_controller.dart';
import 'package:ritual_investing_app/features/funding/data/repository.dart';
import 'package:ritual_investing_app/features/funding/domain/model.dart';
import 'package:ritual_investing_app/features/orders/application/order_controller.dart';
import 'package:ritual_investing_app/features/orders/data/repository.dart';
import 'package:ritual_investing_app/features/orders/domain/model.dart';
import 'package:ritual_investing_app/features/orders/presentation/order_screen.dart';
import 'package:ritual_investing_app/features/portfolio/application/controller.dart';
import 'package:ritual_investing_app/features/portfolio/data/repository.dart';
import 'package:ritual_investing_app/features/portfolio/domain/model.dart';
import 'package:ritual_investing_app/features/rebalancing/application/rebalance_controller.dart';
import 'package:ritual_investing_app/features/rebalancing/data/repository.dart';
import 'package:ritual_investing_app/features/rebalancing/domain/model.dart';
import 'package:ritual_investing_app/features/rebalancing/presentation/rebalance_screen.dart';
import 'package:ritual_investing_app/features/recurring/application/recurring_plan_controller.dart';
import 'package:ritual_investing_app/features/recurring/data/repository.dart';
import 'package:ritual_investing_app/features/recurring/domain/model.dart';
import 'package:ritual_investing_app/features/recurring/presentation/recurring_plan_screen.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'order entry uses labeled Codex choice at 2x in ${brightness.name}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final fixture = _Fixture();
        await tester.pumpWidget(
          _app(
            brightness,
            OrderScreen(
              portfolioId: _portfolioId,
              controller: fixture.orders,
              portfolioController: fixture.portfolios,
              preselectedAssetId: _assetId,
              preselectedSymbol: 'QPW',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('QPW · from Asset Codex'), findsOneWidget);
        expect(find.textContaining('Demo asset ID'), findsNothing);
        expect(find.textContaining('No brokerage order'), findsOneWidget);
        final button = find.byKey(const Key('preview-order'));
        await tester.scrollUntilVisible(button, 200);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'recurring entry labels source and holding without provider data',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = _Fixture();
      await tester.pumpWidget(
        _app(
          Brightness.dark,
          RecurringPlansScreen(
            portfolioId: _portfolioId,
            controller: fixture.recurring,
            portfolioController: fixture.portfolios,
            fundingSourceController: fixture.funding,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No bank credentials'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('recurring-source')),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        fixture.funding.state.value?.items.single.displayLabel,
        'Moon Reserve (fictional)',
      );
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const Key('recurring-source')),
            )
            .initialValue,
        _sourceId,
      );
      expect(find.text('Moon Reserve (fictional)'), findsOneWidget);
      expect(find.text('QPW'), findsOneWidget);
      final button = find.byKey(const Key('review-recurring-create'));
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rebalance entry and review use human symbols at 2x', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = _Fixture();
    await tester.pumpWidget(
      _app(
        Brightness.light,
        RebalanceScreen(
          portfolioId: _portfolioId,
          controller: fixture.rebalance,
          portfolioController: fixture.portfolios,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('rebalance-asset-id')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(fixture.portfolios.detailState.value?.holdings.single.symbol, 'QPW');
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('rebalance-asset-id')),
          )
          .initialValue,
      _assetId,
    );
    expect(find.text('QPW · 1.250000 held'), findsOneWidget);
    expect(find.textContaining('Demo asset ID'), findsNothing);
    final button = find.byKey(const Key('preview-rebalance'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.textContaining('BUY QPW'), findsOneWidget);
    final confirm = find.byKey(const Key('confirm-rebalance'));
    expect(tester.getSize(confirm).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Brightness brightness, Widget home) => MaterialApp(
  theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(2)),
    child: child!,
  ),
  home: home,
);

class _Fixture {
  _Fixture() {
    portfolios = PortfolioController(
      repository: _PortfolioRepository(),
      bootstrapDefaultPortfolioId: _portfolioId,
      createKey: () => 'portfolio-key-0001',
    );
    funding = FundingSourceController(
      repository: _FundingRepository(),
      createKey: () => 'funding-key-000001',
    );
    final storage = PendingCommandStore(storage: _Storage());
    const scope = CacheScope(accountId: 'account-a', resetGeneration: 1);
    orders = OrderController(
      repository: OrderRepository(service: _OrderService()),
      portfolioController: portfolios,
      pendingStore: storage,
      invalidationBus: InvalidationBus(),
      scope: scope,
      createKey: () => 'order-key-0000001',
      now: () => DateTime.utc(2026, 8, 25, 12),
    );
    recurring = RecurringPlanController(
      repository: RecurringPlanRepository(service: _RecurringService()),
      pendingStore: storage,
      scope: scope,
      createKey: () => 'recurring-key-001',
      now: () => DateTime.utc(2026, 8, 25, 12),
      rhythm: MemberContributionRhythm.monthly,
      isFundingSourceActive: (sourceId) async => sourceId == _sourceId,
    );
    rebalance = RebalanceController(
      repository: RebalanceRepository(service: _RebalanceService()),
      portfolioController: portfolios,
      pendingStore: storage,
      invalidationBus: InvalidationBus(),
      scope: scope,
      createKey: () => 'rebalance-key-0001',
      now: () => DateTime.utc(2026, 8, 25, 12),
    );
  }

  late final PortfolioController portfolios;
  late final FundingSourceController funding;
  late final OrderController orders;
  late final RecurringPlanController recurring;
  late final RebalanceController rebalance;
}

class _PortfolioRepository implements PortfolioRepository {
  @override
  Future<RepositoryRead<PortfolioCollection>> loadList() async =>
      RepositoryRead(
        value: PortfolioCollection(items: [_portfolio]),
        isStale: false,
        committedAt: DateTime.utc(2026, 8, 25),
      );
  @override
  Future<RepositoryRead<PortfolioDetail>> loadDetail(
    String portfolioId,
  ) async => RepositoryRead(
    value: PortfolioDetail(
      portfolio: _portfolio,
      holdings: const [_holding],
      activity: const [],
      snapshots: const [],
    ),
    isStale: false,
    committedAt: DateTime.utc(2026, 8, 25),
  );
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

class _FundingRepository implements FundingRepository {
  @override
  Future<RepositoryRead<FundingCollection>> loadSources() async =>
      RepositoryRead(
        value: FundingCollection(items: [_source]),
        isStale: false,
        committedAt: DateTime.utc(2026, 8, 25),
      );
  @override
  Future<FundingSource> createSource({
    required FundingFixture fixture,
    required String idempotencyKey,
  }) async => _source;
  @override
  Future<void> deleteSource(String sourceId) async {}
  @override
  Future<ContributionReceipt> contribute(ContributionCommand command) =>
      throw UnimplementedError();
}

class _OrderService implements OrderService {
  @override
  Future<List<OrderView>> list(String portfolioId) async => const [];
  @override
  Future<OrderView> get(String orderId) => throw UnimplementedError();
  @override
  Future<OrderPreview> preview(OrderDraft draft) => throw UnimplementedError();
  @override
  Future<OrderReceipt> commit(OrderCommit command) =>
      throw UnimplementedError();
}

class _RecurringService implements RecurringPlanService {
  @override
  Future<List<RecurringPlan>> list(String portfolioId) async => const [];
  @override
  Future<RecurringPlan> get(String planId) => throw UnimplementedError();
  @override
  Future<RecurringPlan> create(RecurringPlanCreate command) =>
      throw UnimplementedError();
  @override
  Future<RecurringPlan> edit(RecurringPlanEdit command) =>
      throw UnimplementedError();
  @override
  Future<RecurringPlan> pause(String planId, int expectedVersion) =>
      throw UnimplementedError();
  @override
  Future<RecurringPlan> resume(String planId, int expectedVersion) =>
      throw UnimplementedError();
  @override
  Future<void> cancel(String planId, int expectedVersion) =>
      throw UnimplementedError();
}

class _RebalanceService implements RebalanceService {
  @override
  Future<RebalancePreview> preview(
    String portfolioId,
    List<RebalanceAllocation> allocations,
  ) async => RebalancePreview(
    id: 'preview-a',
    portfolioId: portfolioId,
    portfolioVersion: 7,
    targetAllocation: allocations,
    trades: const [
      RebalanceTrade(
        assetId: _assetId,
        side: RebalanceSide.buy,
        quantityValue: '0.125',
        quantityScale: 3,
        notionalMinor: 2500,
      ),
    ],
    expiresAt: DateTime.utc(2026, 8, 25, 12, 15),
    status: RebalancePreviewStatus.active,
    demo: _rebalanceDemo,
  );
  @override
  Future<RebalanceReceipt> commit(RebalanceCommit command) =>
      throw UnimplementedError();
}

const _portfolioId = '00000000-0000-4000-8000-000000000701';
const _assetId = '00000000-0000-4000-8000-000000000703';
const _sourceId = '00000000-0000-4000-8000-000000000702';

final _portfolio = PortfolioSummary(
  id: _portfolioId,
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
    observedAt: _observedAt,
    sourceLabel: 'Demo ledger',
    limitations: ['No real money moves.'],
  ),
  targetAllocation: [],
);
const _holding = PortfolioHolding(
  assetId: _assetId,
  symbol: 'QPW',
  quantityValue: '1.250000',
  quantityScale: 6,
  marketValueMinor: 2500,
  currency: PortfolioCurrency.usd,
  ledgerWatermark: 11,
  asOfTransactionId: 'transaction-a',
);
final _source = FundingSource(
  id: _sourceId,
  fixture: FundingFixture.moonReserve,
  displayLabel: 'Moon Reserve (fictional)',
  fictionalLast4: '1108',
  status: FundingSourceStatus.active,
  demo: FundingDemoDisclosure(
    isDemo: true,
    observedAt: _observedAt,
    sourceLabel: 'Demo ledger',
    limitations: ['No credentials collected.'],
  ),
);
final _rebalanceDemo = RebalanceDemoDisclosure(
  isDemo: true,
  observedAt: _observedAt,
  sourceLabel: 'Demo ledger',
  limitations: ['No real money moves.'],
);
final _observedAt = DateTime.utc(2026, 8, 25);

class _Storage implements ProtectedStorage {
  final Map<String, String> values = {};
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<Map<String, String>> readAll() async => Map.of(values);
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
