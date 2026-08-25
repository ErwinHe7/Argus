import 'cache_entry.dart';

class CacheScope {
  const CacheScope({required this.accountId, required this.resetGeneration});

  final String accountId;
  final int resetGeneration;

  String get storagePrefix =>
      'member-cache:v1:${Uri.encodeComponent(accountId)}:$resetGeneration:';

  @override
  bool operator ==(Object other) =>
      other is CacheScope &&
      other.accountId == accountId &&
      other.resetGeneration == resetGeneration;

  @override
  int get hashCode => Object.hash(accountId, resetGeneration);
}

abstract interface class ReadCache {
  Future<CacheEntry<T>?> get<T>(String key);
  Future<void> put<T>(String key, T value, DateTime committedAt);
  Future<void> clearLegacyMutations();
}

abstract interface class ScopedReadCacheStorage implements ReadCache {
  Future<void> clearScope(CacheScope scope);
}

class MemoryReadCache implements ScopedReadCacheStorage {
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

  @override
  Future<void> clearScope(CacheScope scope) async {
    _entries.removeWhere((key, _) => key.startsWith(scope.storagePrefix));
  }
}

class ScopedReadCache implements ReadCache {
  ScopedReadCache({required this.storage, required this.scope});

  final ScopedReadCacheStorage storage;
  final CacheScope scope;

  String _key(String resource) =>
      '${scope.storagePrefix}${Uri.encodeComponent(resource)}';

  @override
  Future<CacheEntry<T>?> get<T>(String key) => storage.get<T>(_key(key));

  @override
  Future<void> put<T>(String key, T value, DateTime committedAt) =>
      storage.put<T>(_key(key), value, committedAt);

  @override
  Future<void> clearLegacyMutations() => storage.clearLegacyMutations();

  Future<void> clear() => storage.clearScope(scope);
}
