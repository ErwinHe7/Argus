// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:typed_data';

import '../../../core/api/pending_command_store.dart';
import '../../../core/cache/read_cache.dart';
import '../domain/model.dart';

abstract interface class PrivacyRepository {
  Future<void> clearStaleLocalFiles();
  Future<String?> restoreExportId();
  Future<void> rememberExportId(String requestId);
  Future<void> forgetExportId(String requestId);
  Future<PrivacyExport> requestExport(String idempotencyKey);
  Future<PrivacyExport> getExport(String requestId);
  Future<void> downloadAndShare(String requestId);
  Future<PrivacyDeletionReceipt> requestDeletion(String idempotencyKey);
  Future<bool> accountInactive();
  Future<DemoResetReceipt> resetDemo(int seedVersion, String idempotencyKey);
  Future<void> cancelAndClearLocal();
}

abstract interface class PrivacyService {
  Future<PrivacyExport> requestExport(String idempotencyKey);
  Future<PrivacyExport> getExport(String requestId);
  Future<Uint8List> downloadLatest(String requestId);
  Future<PrivacyDeletionReceipt> requestDeletion(String idempotencyKey);
  Future<bool> accountInactive();
  Future<DemoResetReceipt> resetDemo(int seedVersion, String idempotencyKey);
  void cancel();
}

abstract interface class PrivateExportFiles {
  Future<void> share(CacheScope scope, String requestId, Uint8List bytes);
  Future<void> clear(CacheScope scope);
}

class ScopedPrivacyRepository implements PrivacyRepository {
  ScopedPrivacyRepository({
    required PrivacyService service,
    required PrivacyExportRequestStore requestStore,
    required PrivateExportFiles files,
    required this.scope,
  }) : _service = service,
       _requestStore = requestStore,
       _files = files;

  final PrivacyService _service;
  final PrivacyExportRequestStore _requestStore;
  final PrivateExportFiles _files;
  final CacheScope scope;

  @override
  Future<void> clearStaleLocalFiles() => _files.clear(scope);

  @override
  Future<String?> restoreExportId() => _requestStore.read(scope);

  @override
  Future<void> rememberExportId(String requestId) =>
      _requestStore.write(scope, requestId);

  @override
  Future<void> forgetExportId(String requestId) =>
      _requestStore.clearIfMatches(scope, requestId);

  @override
  Future<PrivacyExport> requestExport(String idempotencyKey) =>
      _service.requestExport(idempotencyKey);

  @override
  Future<PrivacyExport> getExport(String requestId) =>
      _service.getExport(requestId);

  @override
  Future<void> downloadAndShare(String requestId) async {
    final bytes = await _service.downloadLatest(requestId);
    try {
      await _files.share(scope, requestId, bytes);
    } on FormatException {
      throw const PrivacyFailure(PrivacyFailureKind.terminal);
    } on PrivacyFailure {
      rethrow;
    } on Object {
      throw const PrivacyFailure(PrivacyFailureKind.retryable);
    }
  }

  @override
  Future<PrivacyDeletionReceipt> requestDeletion(String idempotencyKey) =>
      _service.requestDeletion(idempotencyKey);

  @override
  Future<bool> accountInactive() => _service.accountInactive();

  @override
  Future<DemoResetReceipt> resetDemo(int seedVersion, String idempotencyKey) =>
      _service.resetDemo(seedVersion, idempotencyKey);

  @override
  Future<void> cancelAndClearLocal() async {
    _service.cancel();
    await Future.wait([_requestStore.clear(scope), _files.clear(scope)]);
  }
}

class PrivacyExportRequestStore {
  PrivacyExportRequestStore({required ProtectedStorage storage})
    : _storage = storage;

  final ProtectedStorage _storage;

  Future<String?> read(CacheScope scope) async {
    final key = _key(scope);
    final encoded = (await _storage.readAll())[key];
    if (encoded == null) return null;
    try {
      final value = jsonDecode(encoded) as Map<String, dynamic>;
      final requestId = value['request_id'] as String;
      if (value.length != 4 ||
          value['schema_version'] != 1 ||
          value['account_id'] != scope.accountId ||
          value['reset_generation'] != scope.resetGeneration ||
          !_uuid.hasMatch(requestId)) {
        throw const FormatException();
      }
      return requestId;
    } on Object {
      await _storage.delete(key);
      return null;
    }
  }

  Future<void> write(CacheScope scope, String requestId) async {
    _requireUuid(requestId);
    await _storage.write(
      _key(scope),
      jsonEncode({
        'schema_version': 1,
        'account_id': scope.accountId,
        'reset_generation': scope.resetGeneration,
        'request_id': requestId,
      }),
    );
  }

  Future<void> clearIfMatches(CacheScope scope, String requestId) async {
    final current = await read(scope);
    if (current == requestId) await clear(scope);
  }

  Future<void> clear(CacheScope scope) => _storage.delete(_key(scope));

  String _key(CacheScope scope) =>
      'privacy-export:v1:${Uri.encodeComponent(scope.accountId)}:'
      '${scope.resetGeneration}';
}

void _requireUuid(String value) {
  if (!_uuid.hasMatch(value)) {
    throw const PrivacyFailure(PrivacyFailureKind.terminal);
  }
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);
