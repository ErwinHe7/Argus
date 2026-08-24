// ignore_for_file: prefer_initializing_formals

import '../../../core/cache/read_cache.dart';
import '../../../core/cache/cached_read.dart';
import '../domain/daily_ritual.dart';

export '../../../core/cache/cached_read.dart'
    show OfflineException, RepositoryRead;

abstract interface class DailyRitualService {
  Future<DailyRitual> fetchDaily();
}

class DailyRitualRepository {
  DailyRitualRepository({
    required DailyRitualService service,
    required ReadCache cache,
  }) : _service = service,
       _cache = cache;
  final DailyRitualService _service;
  final ReadCache _cache;
  Future<RepositoryRead<DailyRitual>> load() => cachedRead(
    key: 'daily-ritual',
    cache: _cache,
    fetch: _service.fetchDaily,
  );
}
