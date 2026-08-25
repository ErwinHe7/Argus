// ignore_for_file: prefer_initializing_formals

import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../domain/model.dart';

class PortfolioAmbiguousMutation implements Exception {
  const PortfolioAmbiguousMutation();
}

abstract interface class PortfolioService {
  Future<PortfolioCollection> fetchList();
  Future<PortfolioSummary> fetchDetail(String portfolioId);
  Future<List<PortfolioHolding>> fetchHoldings(String portfolioId);
  Future<List<PortfolioActivityEntry>> fetchActivity(String portfolioId);
  Future<List<PortfolioSnapshotView>> fetchSnapshots(String portfolioId);
  Future<PortfolioSummary> create({
    required String name,
    required String idempotencyKey,
  });
  Future<PortfolioSummary> rename({
    required String portfolioId,
    required String name,
    required int expectedVersion,
  });
  Future<void> archive({
    required String portfolioId,
    required int expectedVersion,
  });
}

abstract interface class PortfolioRepository {
  Future<RepositoryRead<PortfolioCollection>> loadList();
  Future<RepositoryRead<PortfolioDetail>> loadDetail(String portfolioId);
  Future<PortfolioSummary> create({
    required String name,
    required String idempotencyKey,
  });
  Future<PortfolioSummary> rename({
    required String portfolioId,
    required String name,
    required int expectedVersion,
  });
  Future<void> archive({
    required String portfolioId,
    required int expectedVersion,
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
  Future<RepositoryRead<PortfolioCollection>> loadList() => cachedRead(
    key: 'demo-portfolios',
    cache: _cache,
    fetch: _service.fetchList,
  );

  @override
  Future<RepositoryRead<PortfolioDetail>> loadDetail(String portfolioId) =>
      cachedRead(
        key: 'demo-portfolio:$portfolioId',
        cache: _cache,
        fetch: () async {
          final values = await Future.wait<Object>([
            _service.fetchDetail(portfolioId),
            _service.fetchHoldings(portfolioId),
            _service.fetchActivity(portfolioId),
            _service.fetchSnapshots(portfolioId),
          ]);
          return PortfolioDetail(
            portfolio: values[0] as PortfolioSummary,
            holdings: values[1] as List<PortfolioHolding>,
            activity: values[2] as List<PortfolioActivityEntry>,
            snapshots: values[3] as List<PortfolioSnapshotView>,
          );
        },
      );

  @override
  Future<PortfolioSummary> create({
    required String name,
    required String idempotencyKey,
  }) => _service.create(name: name, idempotencyKey: idempotencyKey);

  @override
  Future<PortfolioSummary> rename({
    required String portfolioId,
    required String name,
    required int expectedVersion,
  }) => _service.rename(
    portfolioId: portfolioId,
    name: name,
    expectedVersion: expectedVersion,
  );

  @override
  Future<void> archive({
    required String portfolioId,
    required int expectedVersion,
  }) => _service.archive(
    portfolioId: portfolioId,
    expectedVersion: expectedVersion,
  );
}
