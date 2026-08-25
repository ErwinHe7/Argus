import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';

void main() {
  test('restored command retains proof fields for reconciliation', () async {
    final storage = _MemoryProtectedStorage();
    final journal = PendingCommandStore(storage: storage);
    final command = PendingCommand(
      scope: const CacheScope(accountId: 'account-a', resetGeneration: 3),
      operation: 'create_demo_contribution',
      key: 'command-key',
      precondition: 'portfolio-version:8',
      canonicalPayloadHash:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      createdAt: DateTime.utc(2026, 8, 24, 12),
    );

    await journal.save(command);
    final restored = await journal.restore(command.scope, command.operation);

    expect(restored?.command, command);
    expect(
      storage.values.values.single,
      allOf(contains('canonical_payload_hash'), isNot(contains('payload":'))),
    );
  });

  test('reset generation cannot restore or clear another scope', () async {
    final storage = _MemoryProtectedStorage();
    final journal = PendingCommandStore(storage: storage);
    const oldScope = CacheScope(accountId: 'account-a', resetGeneration: 2);
    const newScope = CacheScope(accountId: 'account-a', resetGeneration: 3);
    final command = PendingCommand(
      scope: oldScope,
      operation: 'place_order',
      key: 'command-key',
      precondition: 'preview:4',
      canonicalPayloadHash:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      createdAt: DateTime.utc(2026, 8, 24, 12),
    );
    await journal.save(command);

    expect(await journal.restore(newScope, command.operation), isNull);
    await journal.clearScope(newScope);
    expect(
      (await journal.restore(oldScope, command.operation))?.command,
      command,
    );
  });

  test(
    'corrupt or forged current-scope entries fail closed and are deleted',
    () async {
      final storage = _MemoryProtectedStorage();
      final journal = PendingCommandStore(storage: storage);
      const scope = CacheScope(accountId: 'account-a', resetGeneration: 3);
      final command = PendingCommand(
        scope: scope,
        operation: 'place_order',
        key: 'command-key',
        precondition: 'preview:4',
        canonicalPayloadHash:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        createdAt: DateTime.utc(2026, 8, 24, 12),
      );
      await journal.save(command);
      final storageKey = storage.values.keys.single;

      storage.values[storageKey] = '{not-json';
      expect(await journal.restore(scope, command.operation), isNull);
      expect(storage.values, isEmpty);

      await journal.save(command);
      storage.values[storageKey] = storage.values[storageKey]!.replaceFirst(
        '"reset_generation":3',
        '"reset_generation":2',
      );
      expect(await journal.restore(scope, command.operation), isNull);
      expect(storage.values, isEmpty);
    },
  );

  test(
    'clearing one committed operation preserves unrelated pending commands',
    () async {
      final storage = _MemoryProtectedStorage();
      final journal = PendingCommandStore(storage: storage);
      const scope = CacheScope(accountId: 'account-a', resetGeneration: 3);
      final contribution = PendingCommand(
        scope: scope,
        operation: 'create_demo_contribution',
        key: 'contribution-key',
        precondition: 'portfolio:portfolio-a:v8',
        canonicalPayloadHash:
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        createdAt: DateTime.utc(2026, 8, 24, 12),
      );
      final order = PendingCommand(
        scope: scope,
        operation: 'place_order',
        key: 'order-key',
        precondition: 'preview:4',
        canonicalPayloadHash:
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        createdAt: DateTime.utc(2026, 8, 24, 12),
      );
      await journal.save(contribution);
      await journal.save(order);

      await journal.clear(scope, contribution.operation);

      expect(await journal.restore(scope, contribution.operation), isNull);
      expect((await journal.restore(scope, order.operation))?.command, order);
    },
  );
}

class _MemoryProtectedStorage implements ProtectedStorage {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
