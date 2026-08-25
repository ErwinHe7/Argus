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
  final Set<Future<void>> _pendingWrites = {};
  bool _isRevoked = false;
  Future<void>? _clearance;

  String _key(String resource) =>
      '${scope.storagePrefix}${Uri.encodeComponent(resource)}';

  @override
  Future<CacheEntry<T>?> get<T>(String key) async {
    if (_isRevoked) return null;
    final value = await storage.get<T>(_key(key));
    return _isRevoked ? null : value;
  }

  @override
  Future<void> put<T>(String key, T value, DateTime committedAt) async {
    if (_isRevoked) return;
    final pending = storage.put<T>(_key(key), value, committedAt);
    _pendingWrites.add(pending);
    try {
      await pending;
    } finally {
      _pendingWrites.remove(pending);
    }
  }

  @override
  Future<void> clearLegacyMutations() async {
    if (_isRevoked) return;
    await storage.clearLegacyMutations();
  }

  Future<void> clear() {
    revoke();
    return _clearance ??= _finishClear();
  }

  void revoke() => _isRevoked = true;

  Future<void> _finishClear() async {
    try {
      await Future.wait(_pendingWrites.toList(growable: false));
    } finally {
      await storage.clearScope(scope);
    }
  }
}
