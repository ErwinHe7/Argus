// ignore_for_file: prefer_initializing_formals

import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../domain/model.dart';

abstract interface class PortfolioService {
  Future<PortfolioCollection> fetch();

  Future<ContributionReceipt> contribute({
    required String portfolioId,
    required String sourceId,
    required int minorUnits,
    required String idempotencyKey,
  });
}

abstract interface class PortfolioRepository {
  Future<RepositoryRead<PortfolioCollection>> load();

  Future<ContributionReceipt> contribute({
    required String portfolioId,
    required String sourceId,
    required int minorUnits,
    required String idempotencyKey,
  });
}

class CachedPortfolioRepository implements PortfolioRepository {
  CachedPortfolioRepository({
    required PortfolioService service,
    required ReadCache cache,
  }) : _service = service,
       _cache = cache;

  final PortfolioService _service;
  final ReadCache _cache;

  @override
  Future<RepositoryRead<PortfolioCollection>> load() =>
      cachedRead(key: 'demo-portfolios', cache: _cache, fetch: _service.fetch);

  @override
  Future<ContributionReceipt> contribute({
    required String portfolioId,
    required String sourceId,
    required int minorUnits,
    required String idempotencyKey,
  }) => _service.contribute(
    portfolioId: portfolioId,
    sourceId: sourceId,
    minorUnits: minorUnits,
    idempotencyKey: idempotencyKey,
  );
}
