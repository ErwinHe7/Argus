import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/portfolio/data/repository.dart';
import 'package:ritual_investing_app/features/portfolio/domain/model.dart';

void main() {
  test('portfolio repository preserves every authoritative read model', () async {
    final service = _PortfolioService();
    final repository = CachedPortfolioRepository(
      service: service,
      cache: MemoryReadCache(),
    );

    final list = await repository.loadList();
    final detail = await repository.loadDetail('portfolio-b');

    expect(list.value.items[1].isDefault, isTrue);
    expect(list.value.items[1].currency, PortfolioCurrency.usd);
    expect(list.value.items[1].demo.isDemo, isTrue);
    expect(detail.value.portfolio.id, 'portfolio-b');
    expect(detail.value.holdings.single.assetId, 'asset-a');
    expect(detail.value.activity.single.type, PortfolioActivityType.contribution);
    expect(detail.value.snapshots.single.ledgerWatermark, 7);
    expect(service.detailFetches, 1);
    expect(service.holdingsFetches, 1);
    expect(service.activityFetches, 1);
    expect(service.snapshotFetches, 1);
  });

  test('portfolio writes preserve command keys and exact versions', () async {
    final service = _PortfolioService();
    final repository = CachedPortfolioRepository(
      service: service,
      cache: MemoryReadCache(),
    );

    await repository.create(name: 'Moon Garden', idempotencyKey: 'create-key');
    await repository.rename(
      portfolioId: 'portfolio-b',
      name: 'Steady Orbit',
      expectedVersion: 8,
    );
    await repository.archive(portfolioId: 'portfolio-a', expectedVersion: 3);

    expect(service.createKeys, ['create-key']);
    expect(service.renames.single, ('portfolio-b', 'Steady Orbit', 8));
    expect(service.archives.single, ('portfolio-a', 3));
  });
}

class _PortfolioService implements PortfolioService {
  int detailFetches = 0;
  int holdingsFetches = 0;
  int activityFetches = 0;
  int snapshotFetches = 0;
  final List<String> createKeys = [];
  final List<(String, String, int)> renames = [];
  final List<(String, int)> archives = [];

  @override
  Future<PortfolioCollection> fetchList() async => PortfolioCollection(
    items: [
      _portfolio(id: 'portfolio-a', version: 3),
      _portfolio(id: 'portfolio-b', isDefault: true, version: 8),
    ],
  );

  @override
  Future<PortfolioSummary> fetchDetail(String portfolioId) async {
    detailFetches += 1;
    return _portfolio(id: portfolioId, isDefault: portfolioId == 'portfolio-b', version: 8);
  }

  @override
  Future<List<PortfolioHolding>> fetchHoldings(String portfolioId) async {
    holdingsFetches += 1;
    return const [
      PortfolioHolding(
        assetId: 'asset-a',
        symbol: 'QPW',
        quantityValue: '1.250000',
        quantityScale: 6,
        marketValueMinor: 2500,
        currency: PortfolioCurrency.usd,
        ledgerWatermark: 7,
        asOfTransactionId: 'transaction-a',
      ),
    ];
  }

  @override
  Future<List<PortfolioActivityEntry>> fetchActivity(String portfolioId) async {
    activityFetches += 1;
    return [_activity()];
  }

  @override
  Future<List<PortfolioSnapshotView>> fetchSnapshots(String portfolioId) async {
    snapshotFetches += 1;
    return [_snapshot()];
  }

  @override
  Future<PortfolioSummary> create({required String name, required String idempotencyKey}) async {
    createKeys.add(idempotencyKey);
    return _portfolio(id: 'portfolio-c', version: 1);
  }

  @override
  Future<PortfolioSummary> rename({required String portfolioId, required String name, required int expectedVersion}) async {
    renames.add((portfolioId, name, expectedVersion));
    return _portfolio(id: portfolioId, name: name, version: expectedVersion + 1);
  }

  @override
  Future<void> archive({required String portfolioId, required int expectedVersion}) async {
    archives.add((portfolioId, expectedVersion));
  }
}

PortfolioSummary _portfolio({
  required String id,
  String name = 'Demo Portfolio',
  bool isDefault = false,
  required int version,
}) => PortfolioSummary(
  id: id,
  name: name,
  cashMinor: 5000,
  valuationMinor: 7000,
  currency: PortfolioCurrency.usd,
  status: PortfolioStatus.active,
  isDefault: isDefault,
  version: version,
  ledgerWatermark: 7,
  asOfTransactionId: 'transaction-a',
  demo: _demo,
  targetAllocation: const [],
);

PortfolioActivityEntry _activity() => PortfolioActivityEntry(
  id: 'activity-a',
  type: PortfolioActivityType.contribution,
  descriptionCode: 'demo_contribution',
  effectiveAt: DateTime.utc(2026, 8, 25),
  cashMinor: 1000,
  currency: PortfolioCurrency.usd,
  ledgerWatermark: 7,
  demo: _demo,
);

PortfolioSnapshotView _snapshot() => PortfolioSnapshotView(
  id: 'snapshot-a',
  asOfTransactionId: 'transaction-a',
  ledgerWatermark: 7,
  asOf: DateTime.utc(2026, 8, 25),
  cashMinor: 5000,
  marketValueMinor: 2000,
  currency: PortfolioCurrency.usd,
  demo: _demo,
);

final _demo = PortfolioDemoDisclosure(
  isDemo: true,
  observedAt: DateTime.utc(2026, 8, 25),
  sourceLabel: 'Deterministic Demo ledger',
  limitations: const ['No real money moves.'],
);
