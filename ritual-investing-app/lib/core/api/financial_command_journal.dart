// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../cache/read_cache.dart';
import 'pending_command_store.dart';

/// Shared KTD7 boundary for commands that can be retried only with the same
/// idempotency key and canonical payload after authoritative reconciliation.
class FinancialCommandJournal {
  FinancialCommandJournal({
    required PendingCommandStore store,
    required this.scope,
    required String Function() createKey,
    required DateTime Function() now,
  }) : _store = store,
       _createKey = createKey,
       _now = now;

  final PendingCommandStore _store;
  final CacheScope scope;
  final String Function() _createKey;
  final DateTime Function() _now;

  Future<JournaledFinancialCommand> protect({
    required String operation,
    required Map<String, Object?> payload,
    required Map<String, Object?> precondition,
    JournaledFinancialCommand? reuse,
  }) async {
    final canonicalPayloadHash = canonicalFinancialPayloadHash(payload);
    final snapshotHash = canonicalFinancialPayloadHash(precondition);
    if (reuse != null &&
        (reuse.operation != operation ||
            !reuse.matchesPayload(payload) ||
            reuse.snapshotHash != snapshotHash)) {
      throw StateError(
        'A protected financial command can reuse only its exact operation and payload.',
      );
    }
    final command = PendingCommand(
      scope: scope,
      operation: operation,
      key: reuse?.key ?? _createKey(),
      precondition: jsonEncode(
        _canonicalize({
          'snapshot_schema': 1,
          'account_id': scope.accountId,
          'reset_generation': scope.resetGeneration,
          'operation': operation,
          'payload': payload,
          'data': precondition,
          'snapshot_hash': snapshotHash,
        }),
      ),
      canonicalPayloadHash: canonicalPayloadHash,
      createdAt: reuse?.createdAt ?? _now().toUtc(),
    );
    await _store.save(command);
    return JournaledFinancialCommand(
      operation: operation,
      key: command.key,
      payloadHash: canonicalPayloadHash,
      snapshotHash: snapshotHash,
      precondition: Map.unmodifiable(precondition),
      createdAt: command.createdAt,
      restored: false,
    );
  }

  Future<JournaledFinancialCommand?> restore(String operation) async {
    final restored = await _store.restore(scope, operation);
    if (restored == null) return null;
    try {
      final decoded = jsonDecode(restored.command.precondition);
      if (decoded is! Map<String, dynamic> ||
          decoded.length != 7 ||
          decoded['snapshot_schema'] != 1 ||
          decoded['account_id'] != scope.accountId ||
          decoded['reset_generation'] != scope.resetGeneration ||
          decoded['operation'] != operation ||
          decoded['payload'] is! Map<String, dynamic> ||
          decoded['snapshot_hash'] is! String ||
          decoded['data'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final data = (decoded['data']! as Map<String, dynamic>)
          .cast<String, Object?>();
      final payload = (decoded['payload']! as Map<String, dynamic>)
          .cast<String, Object?>();
      if (canonicalFinancialPayloadHash(data) != decoded['snapshot_hash'] ||
          canonicalFinancialPayloadHash(payload) !=
              restored.command.canonicalPayloadHash) {
        throw const FormatException();
      }
      return JournaledFinancialCommand(
        operation: operation,
        key: restored.command.key,
        payloadHash: restored.command.canonicalPayloadHash,
        snapshotHash: decoded['snapshot_hash']! as String,
        precondition: Map.unmodifiable(data),
        createdAt: restored.command.createdAt,
        restored: true,
      );
    } on Object {
      await clear(operation);
      return null;
    }
  }

  Future<void> clear(String operation) => _store.clear(scope, operation);
}

class JournaledFinancialCommand {
  const JournaledFinancialCommand({
    required this.operation,
    required this.key,
    required this.payloadHash,
    required this.snapshotHash,
    required this.precondition,
    required this.createdAt,
    required this.restored,
  });

  final String operation;
  final String key;
  final String payloadHash;
  final String snapshotHash;
  final Map<String, Object?> precondition;
  final DateTime createdAt;
  final bool restored;

  bool matchesPayload(Map<String, Object?> payload) =>
      payloadHash == canonicalFinancialPayloadHash(payload);
}

String canonicalFinancialPayloadHash(Map<String, Object?> payload) =>
    sha256.convert(utf8.encode(jsonEncode(_canonicalize(payload)))).toString();

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is Iterable) return value.map(_canonicalize).toList(growable: false);
  if (value is DateTime) return value.toUtc().toIso8601String();
  return value;
}
