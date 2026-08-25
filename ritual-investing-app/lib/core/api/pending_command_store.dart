import 'dart:convert';

import '../cache/read_cache.dart';

abstract interface class ProtectedStorage {
  Future<Map<String, String>> readAll();
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PendingCommand {
  PendingCommand({
    required this.scope,
    required this.operation,
    required this.key,
    required this.precondition,
    required this.canonicalPayloadHash,
    required this.createdAt,
  }) {
    if (operation.trim().isEmpty || key.trim().isEmpty) {
      throw ArgumentError('Pending command operation and key are required.');
    }
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(canonicalPayloadHash)) {
      throw ArgumentError('Canonical payload hash must be lowercase SHA-256.');
    }
  }

  final CacheScope scope;
  final String operation;
  final String key;
  final String precondition;
  final String canonicalPayloadHash;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is PendingCommand &&
      other.scope == scope &&
      other.operation == operation &&
      other.key == key &&
      other.precondition == precondition &&
      other.canonicalPayloadHash == canonicalPayloadHash &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    scope,
    operation,
    key,
    precondition,
    canonicalPayloadHash,
    createdAt,
  );
}

class RestoredPendingCommand {
  const RestoredPendingCommand(this.command);

  final PendingCommand command;
  bool get requiresAuthoritativeReconciliation => true;
  bool get canAutoSubmit => false;
}

class PendingCommandStore {
  PendingCommandStore({required this.storage});

  final ProtectedStorage storage;

  Future<void> save(PendingCommand command) => storage.write(
    _storageKey(command.scope, command.operation),
    jsonEncode({
      'schema_version': 1,
      'account_id': command.scope.accountId,
      'reset_generation': command.scope.resetGeneration,
      'operation': command.operation,
      'key': command.key,
      'precondition': command.precondition,
      'canonical_payload_hash': command.canonicalPayloadHash,
      'created_at': command.createdAt.toUtc().toIso8601String(),
    }),
  );

  Future<RestoredPendingCommand?> restore(
    CacheScope scope,
    String operation,
  ) async {
    final storageKey = _storageKey(scope, operation);
    final encoded = (await storage.readAll())[storageKey];
    if (encoded == null) return null;
    try {
      final value = jsonDecode(encoded) as Map<String, dynamic>;
      final command = PendingCommand(
        scope: CacheScope(
          accountId: value['account_id'] as String,
          resetGeneration: value['reset_generation'] as int,
        ),
        operation: value['operation'] as String,
        key: value['key'] as String,
        precondition: value['precondition'] as String,
        canonicalPayloadHash: value['canonical_payload_hash'] as String,
        createdAt: DateTime.parse(value['created_at'] as String).toUtc(),
      );
      if (value['schema_version'] != 1 ||
          command.scope != scope ||
          command.operation != operation) {
        await storage.delete(storageKey);
        return null;
      }
      return RestoredPendingCommand(command);
    } on Object {
      await storage.delete(storageKey);
      return null;
    }
  }

  Future<void> clearScope(CacheScope scope) async {
    final prefix = _scopePrefix(scope);
    final keys = (await storage.readAll()).keys
        .where((key) => key.startsWith(prefix))
        .toList(growable: false);
    await Future.wait(keys.map(storage.delete));
  }

  Future<void> clear(CacheScope scope, String operation) =>
      storage.delete(_storageKey(scope, operation));

  String _scopePrefix(CacheScope scope) =>
      'pending-command:v1:${Uri.encodeComponent(scope.accountId)}:'
      '${scope.resetGeneration}:';

  String _storageKey(CacheScope scope, String operation) =>
      '${_scopePrefix(scope)}${Uri.encodeComponent(operation)}';
}
