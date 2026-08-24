import 'cache_entry.dart';

abstract interface class ReadCache {
  Future<CacheEntry<T>?> get<T>(String key);
  Future<void> put<T>(String key, T value, DateTime committedAt);
  Future<void> clearLegacyMutations();
}

class MemoryReadCache implements ReadCache {
  final Map<String, CacheEntry<Object>> _entries = {};
  @override
  Future<CacheEntry<T>?> get<T>(String key) async {
    final entry = _entries[key];
    return entry == null
        ? null
        : CacheEntry<T>(
            value: entry.value as T,
            committedAt: entry.committedAt,
          );
  }

  @override
  Future<void> put<T>(String key, T value, DateTime committedAt) async {
    _entries[key] = CacheEntry<Object>(
      value: value as Object,
      committedAt: committedAt,
    );
  }

  @override
  Future<void> clearLegacyMutations() async {}
}
