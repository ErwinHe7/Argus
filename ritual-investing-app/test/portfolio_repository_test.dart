import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/portfolio/data/repository.dart';
import 'package:ritual_investing_app/features/portfolio/domain/model.dart';

void main() {
  test('portfolio reads use the read-only cache and mutations preserve the caller key', () async {
    final service = _PortfolioService();
    final repository = CachedPortfolioRepository(
      service: service,
      cache: MemoryReadCache(),
    );

    final first = await repository.load();
    final second = await repository.load();
    expect(first.value.items.single.name, 'Demo Portfolio');
    expect(second.value.items.single.ledgerWatermark, 7);
    expect(service.fetches, 2);

    for (var attempt = 0; attempt < 2; attempt += 1) {
      await repository.contribute(
        portfolioId: 'portfolio',
        sourceId: 'fixture',
        minorUnits: 1000,
        idempotencyKey: 'stable-key',
      );
    }
    expect(service.keys, ['stable-key', 'stable-key']);
  });
}

class _PortfolioService implements PortfolioService {
  int fetches = 0;
  final List<String> keys = [];

  @override
  Future<PortfolioCollection> fetch() async {
    fetches += 1;
    return const PortfolioCollection(
      items: [
        PortfolioSummary(
          id: 'portfolio',
          name: 'Demo Portfolio',
          cashMinor: 5000,
          valuationMinor: 7000,
          version: 3,
          ledgerWatermark: 7,
        ),
      ],
    );
  }

  @override
  Future<ContributionReceipt> contribute({
    required String portfolioId,
    required String sourceId,
    required int minorUnits,
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    return const ContributionReceipt(commandId: 'command', portfolioVersion: 4);
  }
}
