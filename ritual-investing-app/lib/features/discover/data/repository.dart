// ignore_for_file: prefer_initializing_formals

import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../domain/model.dart';

export '../../../core/cache/cached_read.dart' show OfflineException;

abstract interface class DiscoverService {
  Future<DiscoverModel> fetch();
}

abstract interface class DiscoverRepository {
  Future<RepositoryRead<DiscoverModel>> load();
}

class CachedDiscoverRepository implements DiscoverRepository {
  CachedDiscoverRepository({
    required DiscoverService service,
    required ReadCache cache,
  }) : _service = service,
       _cache = cache;
  final DiscoverService _service;
  final ReadCache _cache;
  @override
  Future<RepositoryRead<DiscoverModel>> load() =>
      cachedRead(key: 'discover', cache: _cache, fetch: _service.fetch);
}
