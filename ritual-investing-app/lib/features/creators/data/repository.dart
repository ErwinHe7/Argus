// ignore_for_file: prefer_initializing_formals

import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../../discover/domain/model.dart';

export '../../../core/cache/cached_read.dart' show OfflineException;

abstract interface class CreatorService {
  Future<SeededCreatorView> fetchById(String creatorId);
}

class CreatorRepository {
  CreatorRepository({required CreatorService service, required ReadCache cache})
    : _service = service,
      _cache = cache;

  final CreatorService _service;
  final ReadCache _cache;

  Future<RepositoryRead<SeededCreatorView>> load(String creatorId) =>
      cachedRead(
        key: 'seeded-creator:$creatorId',
        cache: _cache,
        fetch: () => _service.fetchById(creatorId),
      );
}
