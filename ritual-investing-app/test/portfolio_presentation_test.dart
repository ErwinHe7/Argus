import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/api/invalidation_bus.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/cache/cached_read.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/funding/application/contribution_controller.dart';
import 'package:ritual_investing_app/features/funding/application/funding_source_controller.dart';
import 'package:ritual_investing_app/features/funding/data/repository.dart';
import 'package:ritual_investing_app/features/funding/domain/model.dart';
import 'package:ritual_investing_app/features/portfolio/application/controller.dart';
import 'package:ritual_investing_app/features/portfolio/data/repository.dart';
import 'package:ritual_investing_app/features/portfolio/domain/model.dart';
import 'package:ritual_investing_app/features/portfolio/presentation/portfolio_screen.dart';

void main() {
  testWidgets(
    'portfolio presents authoritative Demo detail and explicit contribution receipt',
    (tester) async {
      final fixture = await _Fixture.create();
      String? openedAsset;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PortfolioScreen(
            portfolioId: 'portfolio-a',
            portfolioController: fixture.portfolios,
            fundingSourceController: fixture.sources,
            contributionController: fixture.contribution,
            onOpenAsset: (id) => openedAsset = id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DEMO'), findsOneWidget);
      expect(find.textContaining('Provider-free'), findsOneWidget);
      expect(find.textContaining('No real money'), findsWidgets);
      expect(find.text('Default portfolio'), findsOneWidget);
      expect(find.textContaining('Routing number'), findsNothing);
      expect(find.textContaining('Card number'), findsNothing);
      expect(find.textContaining('Bank login'), findsNothing);
      expect(find.byKey(const Key('portfolio-create')), findsOneWidget);
      await tester.tap(find.byKey(const Key('portfolio-create')));
      await tester.pumpAndSettle();
      expect(find.text('Create Demo portfolio'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('portfolio-rename')),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const Key('portfolio-rename')));
      await tester.pumpAndSettle();
      expect(find.text('Rename portfolio'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('portfolio-archive')));
      await tester.pumpAndSettle();
      expect(find.text('Archive Demo portfolio?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('QPW'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('demo contribution'), findsOneWidget);
      expect(find.text('Valuation history'), findsOneWidget);
      await tester.tap(find.text('QPW'));
      expect(openedAsset, 'asset-a');

      await tester.scrollUntilVisible(
        find.text('Moon Reserve (fictional) • fictional 1108'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.byKey(const Key('funding-add-moon-reserve')), findsOneWidget);
      expect(
        find.byKey(const Key('funding-add-constellation')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('funding-delete-source-a')));
      await tester.pumpAndSettle();
      expect(find.text('Delete fictional source?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('review-contribution')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        tester.getSize(find.byKey(const Key('review-contribution'))).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.byKey(const Key('review-contribution')));
      await tester.pump();
      expect(find.text('Review contribution'), findsOneWidget);
      expect(find.text('Nothing moves until you confirm.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm-contribution')));
      await tester.pumpAndSettle();
      expect(find.text('Authoritative Demo receipt'), findsOneWidget);
      expect(find.textContaining('command-a'), findsOneWidget);
    },
  );

  testWidgets('portfolio remains usable in dark mode at 2x text', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: PortfolioScreen(
          portfolioId: 'portfolio-a',
          portfolioController: fixture.portfolios,
          fundingSourceController: fixture.sources,
          contributionController: fixture.contribution,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

class _Fixture {
  const _Fixture(this.portfolios, this.sources, this.contribution);

  static Future<_Fixture> create() async {
    const scope = CacheScope(accountId: 'account-a', resetGeneration: 2);
    final portfolio = PortfolioController(
      repository: _PortfolioRepository(),
      bootstrapDefaultPortfolioId: 'portfolio-a',
      createKey: () => 'portfolio-key',
    );
    final service = _FundingService();
    final repository = CachedFundingRepository(
      service: service,
      cache: MemoryReadCache(),
    );
    final sources = FundingSourceController(
      repository: repository,
      createKey: () => 'source-key',
    );
    final contribution = ContributionController(
      repository: repository,
      portfolioController: portfolio,
      pendingStore: PendingCommandStore(storage: _Storage()),
      invalidationBus: InvalidationBus(),
      scope: scope,
      createKey: () => 'contribution-key',
      now: () => DateTime.utc(2026, 8, 25),
      rhythm: MemberContributionRhythm.weekly,
    );
    await portfolio.load();
    return _Fixture(portfolio, sources, contribution);
  }

  final PortfolioController portfolios;
  final FundingSourceController sources;
  final ContributionController contribution;
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
      holdings: const [
        PortfolioHolding(
          assetId: 'asset-a',
          symbol: 'QPW',
          quantityValue: '1.250000',
          quantityScale: 6,
          marketValueMinor: 2200,
          currency: PortfolioCurrency.usd,
          ledgerWatermark: 6,
          asOfTransactionId: 'transaction-a',
        ),
      ],
      activity: [
        PortfolioActivityEntry(
          id: 'activity-a',
          type: PortfolioActivityType.contribution,
          descriptionCode: 'demo_contribution',
          effectiveAt: DateTime.utc(2026, 8, 25),
          cashMinor: 2500,
          currency: PortfolioCurrency.usd,
          ledgerWatermark: 6,
          demo: _portfolio.demo,
        ),
      ],
      snapshots: [
        PortfolioSnapshotView(
          id: 'snapshot-a',
          asOfTransactionId: 'transaction-a',
          ledgerWatermark: 6,
          asOf: DateTime.utc(2026, 8, 25),
          cashMinor: 5000,
          marketValueMinor: 2200,
          currency: PortfolioCurrency.usd,
          demo: _portfolio.demo,
        ),
      ],
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

class _FundingService implements FundingService {
  @override
  Future<List<FundingSource>> fetchSources() async => [_source];
  @override
  Future<FundingSource> createSource({
    required FundingFixture fixture,
    required String idempotencyKey,
  }) async => _source;
  @override
  Future<void> deleteSource(String sourceId) async {}
  @override
  Future<ContributionReceipt> contribute(ContributionCommand command) async =>
      ContributionReceipt(
        commandId: 'command-a',
        portfolioVersion: 8,
        ledgerTransactionIds: const ['transaction-a'],
        demo: _fundingDemo,
      );
}

final _portfolio = PortfolioSummary(
  id: 'portfolio-a',
  name: 'Steady Orbit',
  cashMinor: 5000,
  valuationMinor: 7200,
  currency: PortfolioCurrency.usd,
  status: PortfolioStatus.active,
  isDefault: true,
  version: 7,
  ledgerWatermark: 6,
  asOfTransactionId: 'transaction-a',
  demo: PortfolioDemoDisclosure(
    isDemo: true,
    observedAt: DateTime.utc(2026, 8, 25),
    sourceLabel: 'Deterministic Demo ledger',
    limitations: const ['No real money moves.'],
  ),
  targetAllocation: const [],
);

final _source = FundingSource(
  id: 'source-a',
  fixture: FundingFixture.moonReserve,
  displayLabel: 'Moon Reserve (fictional)',
  fictionalLast4: '1108',
  status: FundingSourceStatus.active,
  demo: _fundingDemo,
);

final _fundingDemo = FundingDemoDisclosure(
  isDemo: true,
  observedAt: DateTime.utc(2026, 8, 25),
  sourceLabel: 'Deterministic Demo ledger',
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
