import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/invalidation_bus.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';

void main() {
  test('account and reset generation isolate identical read keys', () async {
    final storage = MemoryReadCache();
    const accountA0 = CacheScope(accountId: 'account-a', resetGeneration: 0);
    const accountA1 = CacheScope(accountId: 'account-a', resetGeneration: 1);
    const accountB0 = CacheScope(accountId: 'account-b', resetGeneration: 0);
    final a0 = ScopedReadCache(storage: storage, scope: accountA0);
    final a1 = ScopedReadCache(storage: storage, scope: accountA1);
    final b0 = ScopedReadCache(storage: storage, scope: accountB0);

    await a0.put('profile', 'A before reset', DateTime.utc(2026, 8, 24));
    await a1.put('profile', 'A after reset', DateTime.utc(2026, 8, 24));
    await b0.put('profile', 'B', DateTime.utc(2026, 8, 24));
    await storage.clearScope(accountA0);

    expect(await a0.get<String>('profile'), isNull);
    expect((await a1.get<String>('profile'))?.value, 'A after reset');
    expect((await b0.get<String>('profile'))?.value, 'B');
  });

  test(
    'old-generation invalidations never reach the active generation',
    () async {
      final bus = InvalidationBus();
      const beforeReset = CacheScope(
        accountId: 'account-a',
        resetGeneration: 0,
      );
      const afterReset = CacheScope(accountId: 'account-a', resetGeneration: 1);
      final observed = <InvalidationEvent>[];
      final subscription = bus.eventsFor(afterReset).listen(observed.add);

      bus.publish(
        const InvalidationEvent(scope: beforeReset, resource: 'portfolios'),
      );
      bus.publish(
        const InvalidationEvent(scope: afterReset, resource: 'portfolios'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(observed, [
        const InvalidationEvent(scope: afterReset, resource: 'portfolios'),
      ]);
      await subscription.cancel();
      await bus.dispose();
    },
  );
}
