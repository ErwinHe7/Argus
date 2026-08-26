// ignore_for_file: prefer_initializing_formals

import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../domain/model.dart';

abstract interface class IntentionService {
  Future<IntentionPage> list({String? cursor, IntentionStatus? status});
  Future<Intention> get(String intentionId);
  Future<Intention> create(IntentionCreate command);
  Future<Intention> patch(IntentionPatch command);
  Future<void> archive(String intentionId, int expectedVersion);
}

abstract interface class IntentionRepository {
  Future<RepositoryRead<IntentionPage>> load({
    String? cursor,
    IntentionStatus? status,
  });
  Future<RepositoryRead<Intention>> get(String intentionId);
  Future<Intention> create(IntentionCreate command);
  Future<Intention> patch(IntentionPatch command);
  Future<void> archive(String intentionId, int expectedVersion);
}

class CachedIntentionRepository implements IntentionRepository {
  CachedIntentionRepository({
    required IntentionService service,
    required ReadCache cache,
  }) : _service = service,
       _cache = cache;

  final IntentionService _service;
  final ReadCache _cache;

  @override
  Future<RepositoryRead<IntentionPage>> load({
    String? cursor,
    IntentionStatus? status,
  }) => cachedRead(
    key: 'intentions:${status?.name ?? 'all'}:${cursor ?? 'first'}',
    cache: _cache,
    fetch: () => _service.list(cursor: cursor, status: status),
  );

  @override
  Future<RepositoryRead<Intention>> get(String intentionId) => cachedRead(
    key: 'intention:$intentionId',
    cache: _cache,
    fetch: () => _service.get(intentionId),
  );

  @override
  Future<Intention> create(IntentionCreate command) => _service.create(command);

  @override
  Future<Intention> patch(IntentionPatch command) => _service.patch(command);

  @override
  Future<void> archive(String intentionId, int expectedVersion) =>
      _service.archive(intentionId, expectedVersion);
}
