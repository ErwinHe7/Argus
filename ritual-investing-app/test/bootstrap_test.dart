import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/bootstrap/dependency_container.dart';
import 'package:ritual_investing_app/core/cache/cache_entry.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';

void main() {
  test(
    'first authenticated bootstrap clears legacy Demo mutation state',
    () async {
      final cache = _TrackingCache();
      final container = DependencyContainer.fixture(cache: cache);
      await container.bootstrap();
      await container.bootstrap();
      expect(cache.legacyClears, 1);
      expect(container.dailyRitualController.state.phase, LoadPhase.ready);
      expect(container.discoverController.state.phase, LoadPhase.ready);
      expect(container.covenController.state.phase, LoadPhase.ready);
      expect(container.profileController.state.phase, LoadPhase.ready);
      expect(
        container.discoverController.state.value?.grimoires.first.title,
        'Quiet Power',
      );
    },
  );
}

class _TrackingCache implements ReadCache {
  final Map<String, CacheEntry<Object>> values = {};
  int legacyClears = 0;
  @override
  Future<void> clearLegacyMutations() async {
    legacyClears++;
  }

  @override
  Future<CacheEntry<T>?> get<T>(String key) async {
    final value = values[key];
    return value == null
        ? null
        : CacheEntry(value: value.value as T, committedAt: value.committedAt);
  }

  @override
  Future<void> put<T>(String key, T value, DateTime committedAt) async {
    values[key] = CacheEntry<Object>(
      value: value as Object,
      committedAt: committedAt,
    );
  }
}
