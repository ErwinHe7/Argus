import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../domain/model.dart';

abstract interface class RowanService {
  Future<RowanCounselResult> fetch(RowanRequest request);
}

class RowanRepository {
  const RowanRepository({required this.service, required this.cache});

  final RowanService service;
  final ReadCache cache;

  Future<RepositoryRead<RowanCounselResult>> load(RowanRequest request) =>
      cachedRead(
        key: request.cacheKey,
        cache: cache,
        fetch: () => service.fetch(request),
      );
}
