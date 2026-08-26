import 'read_cache.dart';

class OfflineException implements Exception {
  const OfflineException();
}

class RepositoryRead<T> {
  const RepositoryRead({
    required this.value,
    required this.isStale,
    required this.committedAt,
  });

  final T value;
  final bool isStale;
  final DateTime committedAt;
}

Future<RepositoryRead<T>> cachedRead<T>({
  required String key,
  required ReadCache cache,
  required Future<T> Function() fetch,
  DateTime Function()? now,
}) async {
  try {
    final value = await fetch();
    final committedAt = (now ?? DateTime.now)().toUtc();
    await cache.put(key, value, committedAt);
    return RepositoryRead(
      value: value,
      isStale: false,
      committedAt: committedAt,
    );
  } on OfflineException {
    final cached = await cache.get<T>(key);
    if (cached == null) rethrow;
    return RepositoryRead(
      value: cached.value,
      isStale: true,
      committedAt: cached.committedAt,
    );
  }
}
