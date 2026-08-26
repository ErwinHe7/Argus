// ignore_for_file: prefer_initializing_formals

import '../../../core/api/view_state.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../domain/model.dart';

abstract interface class FutureMirrorService {
  Future<FutureMirror> generate(FutureMirrorGenerate command);
  Future<FutureMirror?> getLatest(String intentionId);
  Future<FutureMirror> get(String intentionId, String runId);
}

abstract interface class FutureMirrorRepository {
  Future<RepositoryRead<FutureMirror?>> latest(String intentionId);
  Future<RepositoryRead<FutureMirror>> get(String intentionId, String runId);
  Future<FutureMirror> generate(FutureMirrorGenerate command);
  Future<List<RepositoryRead<FutureMirror>>> recent(String intentionId);
  Future<void> remember(FutureMirror value);
}

class CachedFutureMirrorRepository implements FutureMirrorRepository {
  CachedFutureMirrorRepository({
    required FutureMirrorService service,
    required ReadCache cache,
  }) : _service = service,
       _cache = cache;

  final FutureMirrorService _service;
  final ReadCache _cache;

  @override
  Future<RepositoryRead<FutureMirror?>> latest(String intentionId) async {
    final key = 'future-mirror:$intentionId:latest';
    try {
      final value = await _service.getLatest(intentionId);
      final committedAt = DateTime.now().toUtc();
      if (value != null) {
        await _cache.put(key, value, committedAt);
        await remember(value);
      }
      return RepositoryRead(
        value: value,
        isStale: false,
        committedAt: committedAt,
      );
    } on OfflineException {
      final cached = await _cache.get<FutureMirror>(key);
      if (cached == null) rethrow;
      return RepositoryRead(
        value: cached.value,
        isStale: true,
        committedAt: cached.committedAt,
      );
    }
  }

  @override
  Future<RepositoryRead<FutureMirror>> get(
    String intentionId,
    String runId,
  ) async {
    final result = await cachedRead(
      key: 'future-mirror:$intentionId:$runId',
      cache: _cache,
      fetch: () => _service.get(intentionId, runId),
    );
    await remember(result.value);
    return result;
  }

  @override
  Future<FutureMirror> generate(FutureMirrorGenerate command) async {
    final value = await _service.generate(command);
    await remember(value);
    await _cache.put<FutureMirror>(
      'future-mirror:${command.intentionId}:latest',
      value,
      value.generatedAt,
    );
    return value;
  }

  @override
  Future<void> remember(FutureMirror value) async {
    final key = 'future-mirror:${value.intentionId}:recent-ids';
    final existing = await _cache.get<List<String>>(key);
    final ids = <String>[
      value.id,
      ...?existing?.value.where((id) => id != value.id),
    ].take(12).toList(growable: false);
    await _cache.put(key, ids, value.generatedAt);
  }

  @override
  Future<List<RepositoryRead<FutureMirror>>> recent(String intentionId) async {
    final ids = (await _cache.get<List<String>>(
      'future-mirror:$intentionId:recent-ids',
    ))?.value;
    if (ids == null || ids.isEmpty) return const [];
    final values = <RepositoryRead<FutureMirror>>[];
    for (final id in ids) {
      try {
        final value = await get(intentionId, id);
        if (value.value.intentionId != intentionId) {
          throw const LoadFailure(LoadPhase.forbidden);
        }
        values.add(value);
      } on LoadFailure catch (failure) {
        if (failure.phase != LoadPhase.empty) rethrow;
      }
    }
    return values;
  }
}
