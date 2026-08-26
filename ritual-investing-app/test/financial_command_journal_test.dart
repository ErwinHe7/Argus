import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/financial_command_journal.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';

void main() {
  test('reuse fails closed for altered payload, operation, or restored snapshot', () async {
    final storage = _Storage();
    final journal = _journal(storage);
    final protected = await journal.protect(
      operation: 'order:a',
      payload: const {'preview_id': 'p1', 'version': 1},
      precondition: const {'symbol': 'QPW', 'price': 2500},
    );

    await expectLater(
      journal.protect(
        operation: 'order:a',
        payload: const {'preview_id': 'p2', 'version': 1},
        precondition: const {'symbol': 'QPW', 'price': 2500},
        reuse: protected,
      ),
      throwsStateError,
    );
    await expectLater(
      journal.protect(
        operation: 'rebalance:a',
        payload: const {'preview_id': 'p1', 'version': 1},
        precondition: const {'symbol': 'QPW', 'price': 2500},
        reuse: protected,
      ),
      throwsStateError,
    );

    final restored = await journal.restore('order:a');
    final same = await journal.protect(
      operation: 'order:a',
      payload: const {'preview_id': 'p1', 'version': 1},
      precondition: const {'symbol': 'QPW', 'price': 2500},
      reuse: restored,
    );
    expect(same.key, protected.key);
    expect(same.createdAt, protected.createdAt);
    await expectLater(
      journal.protect(
        operation: 'order:a',
        payload: const {'preview_id': 'p1', 'version': 1},
        precondition: const {'symbol': 'QPW', 'price': 2600},
        reuse: restored,
      ),
      throwsStateError,
    );
  });

  test('snapshot and payload integrity fail closed and clear only that operation', () async {
    final storage = _Storage();
    final journal = _journal(storage);
    await journal.protect(
      operation: 'order:a',
      payload: const {'preview_id': 'p1', 'version': 1},
      precondition: const {'symbol': 'QPW', 'price': 2500},
    );
    await journal.protect(
      operation: 'rebalance:a',
      payload: const {'preview_id': 'r1', 'version': 1},
      precondition: const {'trades': 1},
    );
    final orderKey = storage.values.keys.singleWhere((key) => key.endsWith('order%3Aa'));
    final outer = jsonDecode(storage.values[orderKey]!) as Map<String, dynamic>;
    final wrapper = jsonDecode(outer['precondition'] as String) as Map<String, dynamic>;
    (wrapper['data'] as Map<String, dynamic>)['price'] = 999999;
    outer['precondition'] = jsonEncode(wrapper);
    storage.values[orderKey] = jsonEncode(outer);

    expect(await journal.restore('order:a'), isNull);
    expect(await journal.restore('rebalance:a'), isNotNull);
  });

  test('account/reset mismatch and corrupt JSON clear only the addressed slot', () async {
    final storage = _Storage();
    final journal = _journal(storage);
    await journal.protect(
      operation: 'order:a',
      payload: const {'preview_id': 'p1'},
      precondition: const {'symbol': 'QPW'},
    );
    await journal.protect(
      operation: 'rebalance:a',
      payload: const {'preview_id': 'r1'},
      precondition: const {'trades': 1},
    );
    final orderKey = storage.values.keys.singleWhere((key) => key.endsWith('order%3Aa'));
    storage.values[orderKey] = '{corrupt';

    expect(await journal.restore('order:a'), isNull);
    expect(await journal.restore('rebalance:a'), isNotNull);

    final foreign = FinancialCommandJournal(
      store: PendingCommandStore(storage: storage),
      scope: const CacheScope(accountId: 'account-b', resetGeneration: 9),
      createKey: () => 'foreign-key',
      now: () => DateTime.utc(2026, 8, 25),
    );
    await foreign.protect(
      operation: 'order:a',
      payload: const {'preview_id': 'foreign'},
      precondition: const {'symbol': 'FOREIGN'},
    );
    final foreignKey = storage.values.keys.singleWhere(
      (key) => key.contains('account-b') && key.endsWith('order%3Aa'),
    );
    final outer = jsonDecode(storage.values[foreignKey]!) as Map<String, dynamic>;
    outer['account_id'] = 'account-a';
    storage.values[foreignKey] = jsonEncode(outer);
    expect(await foreign.restore('order:a'), isNull);
    expect(await journal.restore('rebalance:a'), isNotNull);
  });
}

FinancialCommandJournal _journal(_Storage storage) => FinancialCommandJournal(
  store: PendingCommandStore(storage: storage),
  scope: const CacheScope(accountId: 'account-a', resetGeneration: 3),
  createKey: () => 'command-key',
  now: () => DateTime.utc(2026, 8, 25),
);

class _Storage implements ProtectedStorage {
  final Map<String, String> values = {};
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<Map<String, String>> readAll() async => Map.of(values);
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
