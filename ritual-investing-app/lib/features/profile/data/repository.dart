// ignore_for_file: prefer_initializing_formals

import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../domain/model.dart';

abstract interface class ProfileService {
  Future<ProfileModel> fetch();
}

abstract interface class ProfileRepository {
  Future<RepositoryRead<ProfileModel>> load();
}

class CachedProfileRepository implements ProfileRepository {
  CachedProfileRepository({
    required ProfileService service,
    required ReadCache cache,
  }) : _service = service,
       _cache = cache;
  final ProfileService _service;
  final ReadCache _cache;
  @override
  Future<RepositoryRead<ProfileModel>> load() =>
      cachedRead(key: 'profile', cache: _cache, fetch: _service.fetch);
}
