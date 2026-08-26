// ignore_for_file: prefer_initializing_formals

import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../domain/model.dart';

abstract interface class FundingService {
  Future<List<FundingSource>> fetchSources();
  Future<FundingSource> createSource({
    required FundingFixture fixture,
    required String idempotencyKey,
  });
  Future<void> deleteSource(String sourceId);
  Future<ContributionReceipt> contribute(ContributionCommand command);
}

abstract interface class FundingRepository {
  Future<RepositoryRead<FundingCollection>> loadSources();
  Future<FundingSource> createSource({
    required FundingFixture fixture,
    required String idempotencyKey,
  });
  Future<void> deleteSource(String sourceId);
  Future<ContributionReceipt> contribute(ContributionCommand command);
}

class CachedFundingRepository implements FundingRepository {
  CachedFundingRepository({
    required FundingService service,
    required ReadCache cache,
  }) : _service = service,
       _cache = cache;

  final FundingService _service;
  final ReadCache _cache;

  @override
  Future<RepositoryRead<FundingCollection>> loadSources() => cachedRead(
    key: 'demo-funding-sources',
    cache: _cache,
    fetch: () async => FundingCollection(items: await _service.fetchSources()),
  );

  @override
  Future<FundingSource> createSource({
    required FundingFixture fixture,
    required String idempotencyKey,
  }) => _service.createSource(
    fixture: fixture,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<void> deleteSource(String sourceId) =>
      _service.deleteSource(sourceId);

  @override
  Future<ContributionReceipt> contribute(ContributionCommand command) =>
      _service.contribute(command);
}
