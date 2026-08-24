import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/api/ritual_api.dart';
import 'package:ritual_investing_app/core/bootstrap/dependency_container.dart';
import 'package:ritual_investing_app/core/auth/auth_controller.dart';
import 'package:ritual_investing_app/core/cache/cache_entry.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';

void main() {
  test(
    'first authenticated bootstrap clears legacy Demo mutation state',
    () async {
      final cache = _TrackingCache();
      final sessionBootstrap = _TrackingSessionBootstrapService();
      final container = DependencyContainer.fixture(
        cache: cache,
        sessionBootstrapService: sessionBootstrap,
      );
      await container.bootstrap();
      await container.bootstrap();
      expect(cache.legacyClears, 1);
      expect(sessionBootstrap.calls, 2);
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

  test('account bootstrap failure prevents account-scoped reads', () async {
    final cache = _TrackingCache();
    final container = DependencyContainer.fixture(
      cache: cache,
      sessionBootstrapService: _FailingSessionBootstrapService(),
    );

    await container.bootstrap();

    expect(container.authController.state.phase, AuthPhase.failure);
    expect(cache.legacyClears, 0);
    expect(container.dailyRitualController.state.phase, LoadPhase.idle);
  });
}

class _TrackingSessionBootstrapService implements SessionBootstrapService {
  int calls = 0;

  @override
  Future<void> bootstrap() async {
    calls++;
  }
}

class _FailingSessionBootstrapService implements SessionBootstrapService {
  @override
  Future<void> bootstrap() => Future.error(StateError('bootstrap failed'));
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
