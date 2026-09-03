import 'dart:convert';

import '../../../core/api/pending_command_store.dart';
import '../../../core/cache/read_cache.dart';

enum LeonidasVoicePreference { pending, enabled, disabled }

abstract interface class LeonidasVoicePreferencePersistence {
  Future<LeonidasVoicePreference> read(CacheScope scope);
  Future<void> write(CacheScope scope, {required bool enabled});
  Future<void> clearScope(CacheScope scope);
}

/// Device-local, account-generation-scoped preference for Leonidas playback.
///
/// Reads fail quiet because the complete caption is always the authority. Only
/// a genuinely absent record defaults to playback enabled.
class LeonidasVoicePreferenceStore
    implements LeonidasVoicePreferencePersistence {
  LeonidasVoicePreferenceStore(this._storage);

  static const _schemaVersion = 1;
  static const _namespace = 'leonidas-voice-preference:v1';

  final ProtectedStorage _storage;

  String storageKeyFor(CacheScope scope) =>
      '$_namespace:${Uri.encodeComponent(scope.accountId)}:'
      '${scope.resetGeneration}';

  @override
  Future<LeonidasVoicePreference> read(CacheScope scope) async {
    final key = storageKeyFor(scope);
    try {
      final encoded = (await _storage.readAll())[key];
      if (encoded == null) return LeonidasVoicePreference.enabled;
      try {
        final envelope = jsonDecode(encoded) as Map<String, dynamic>;
        if (envelope.length != 4 ||
            envelope['schema_version'] != _schemaVersion ||
            envelope['account_id'] != scope.accountId ||
            envelope['reset_generation'] != scope.resetGeneration ||
            envelope['enabled'] is! bool) {
          await _deleteBestEffort(key);
          return LeonidasVoicePreference.disabled;
        }
        return envelope['enabled'] as bool
            ? LeonidasVoicePreference.enabled
            : LeonidasVoicePreference.disabled;
      } on Object {
        await _deleteBestEffort(key);
        return LeonidasVoicePreference.disabled;
      }
    } on Object {
      return LeonidasVoicePreference.disabled;
    }
  }

  @override
  Future<void> write(CacheScope scope, {required bool enabled}) =>
      _storage.write(
        storageKeyFor(scope),
        jsonEncode({
          'schema_version': _schemaVersion,
          'account_id': scope.accountId,
          'reset_generation': scope.resetGeneration,
          'enabled': enabled,
        }),
      );

  @override
  Future<void> clearScope(CacheScope scope) =>
      _storage.delete(storageKeyFor(scope));

  Future<void> _deleteBestEffort(String key) async {
    try {
      await _storage.delete(key);
    } on Object {
      // The invalid record remains fenced by its scoped key and validation.
    }
  }
}
