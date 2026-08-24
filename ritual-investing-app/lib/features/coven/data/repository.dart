// ignore_for_file: prefer_initializing_formals

import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../domain/model.dart';

abstract interface class CovenService {
  Future<CovenModel> fetch();
}

abstract interface class CovenRepository {
  Future<RepositoryRead<CovenModel>> load();
}

class CachedCovenRepository implements CovenRepository {
  CachedCovenRepository({
    required CovenService service,
    required ReadCache cache,
  }) : _service = service,
       _cache = cache;
  final CovenService _service;
  final ReadCache _cache;
  @override
  Future<RepositoryRead<CovenModel>> load() =>
      cachedRead(key: 'coven', cache: _cache, fetch: _service.fetch);
}
