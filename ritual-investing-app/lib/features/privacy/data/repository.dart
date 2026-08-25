// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart'
    as api;

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

class GeneratedPrivacyService implements PrivacyService {
  GeneratedPrivacyService(api.RitualInvestingApiClient client)
    : _privacy = api.PrivacyApi(client.dio),
      _simulation = api.SimulationApi(client.dio),
      _session = api.SessionApi(client.dio),
      _apiOrigin = Uri.parse(client.dio.options.baseUrl);

  final api.PrivacyApi _privacy;
  final api.SimulationApi _simulation;
  final api.SessionApi _session;
  final Uri _apiOrigin;
  final Map<String, String> _downloadTokens = {};
  CancelToken? _downloadCancellation;
  int _cancellationVersion = 0;

  @override
  Future<PrivacyExport> requestExport(String idempotencyKey) async {
    _requireKey(idempotencyKey);
    try {
      return _export(
        (await _privacy.requestPrivacyExport(
          idempotencyKey: idempotencyKey,
          requestPrivacyExportRequest: api.RequestPrivacyExportRequest(
            format: api.RequestPrivacyExportRequestFormatEnum.zip,
          ),
        )).data!.data,
      );
    } on DioException catch (error) {
      _throwMutation(error);
    } on PrivacyFailure {
      rethrow;
    } on Object {
      _terminal();
    }
  }

  @override
  Future<PrivacyExport> getExport(String requestId) async {
    _requireUuid(requestId);
    _downloadTokens.remove(requestId);
    try {
      final value = (await _privacy.getPrivacyExport(requestId: requestId))
          .data!
          .data;
      if (value.id != requestId) _terminal();
      return _export(value);
    } on DioException catch (error) {
      _throwRead(error);
    } on PrivacyFailure {
      rethrow;
    } on Object {
      _terminal();
    }
  }

  @override
  Future<Uint8List> downloadLatest(String requestId) async {
    _requireUuid(requestId);
    final token = _downloadTokens.remove(requestId);
    if (token == null) _terminal();
    final cancellationVersion = _cancellationVersion;
    final cancellation = CancelToken();
    _downloadCancellation?.cancel('superseded');
    _downloadCancellation = cancellation;
    try {
      final bytes = (await _privacy.downloadPrivacyExport(
        requestId: requestId,
        token: token,
        cancelToken: cancellation,
      )).data;
      if (bytes == null || bytes.isEmpty) _terminal();
      return bytes;
    } on DioException catch (error) {
      final code = _errorCode(error);
      if (code == 'recent_auth_required') {
        if (cancellationVersion == _cancellationVersion) {
          _downloadTokens.putIfAbsent(requestId, () => token);
        }
        throw const RecentAuthRequired();
      }
      if (code == 'not_found') {
        throw const PrivacyFailure(PrivacyFailureKind.retryable);
      }
      _throwRead(error);
    } on PrivacyFailure {
      rethrow;
    } on Object {
      _terminal();
    } finally {
      if (identical(_downloadCancellation, cancellation)) {
        _downloadCancellation = null;
      }
    }
  }

  @override
  Future<PrivacyDeletionReceipt> requestDeletion(String idempotencyKey) async {
    _requireKey(idempotencyKey);
    try {
      final value = (await _privacy.requestAccountDeletion(
        idempotencyKey: idempotencyKey,
        requestAccountDeletionRequest: api.RequestAccountDeletionRequest(
          confirmation:
              api.RequestAccountDeletionRequestConfirmationEnum.DELETE,
        ),
      )).data!.data;
      _requireUuid(value.requestId);
      _requireUuid(value.tombstoneId);
      if (value.status !=
              api.RequestAccountDeletion202ResponseDataStatusEnum.queued ||
          value.purgeGeneration <= 0 ||
          !value.effectiveAt.isUtc ||
          !value.purgeBy.isUtc ||
          !value.purgeBy.isAfter(value.effectiveAt)) {
        _terminal();
      }
      return PrivacyDeletionReceipt(
        requestId: value.requestId,
        tombstoneId: value.tombstoneId,
        effectiveAt: value.effectiveAt.toUtc(),
        purgeBy: value.purgeBy.toUtc(),
        purgeGeneration: value.purgeGeneration,
      );
    } on DioException catch (error) {
      _throwMutation(error);
    } on PrivacyFailure {
      rethrow;
    } on Object {
      _terminal();
    }
  }

  @override
  Future<bool> accountInactive() async {
    try {
      await _session.bootstrapSession();
      return false;
    } on DioException catch (error) {
      final code = _errorCode(error);
      if (code == 'account_inactive') return true;
      _throwRead(error);
    } on PrivacyFailure {
      rethrow;
    } on Object {
      _terminal();
    }
  }

  @override
  Future<DemoResetReceipt> resetDemo(
    int seedVersion,
    String idempotencyKey,
  ) async {
    if (seedVersion <= 0) _terminal();
    _requireKey(idempotencyKey);
    try {
      final value = (await _simulation.resetDemoState(
        idempotencyKey: idempotencyKey,
        resetDemoStateRequest: api.ResetDemoStateRequest(
          confirmation: api.ResetDemoStateRequestConfirmationEnum.RESET_DEMO,
          seedVersion: seedVersion,
        ),
      )).data!.data;
      _requireUuid(value.defaultPortfolio.id);
      _requireUuid(value.entitlement.id);
      final disclosureSource = value.demo.sourceLabel.trim();
      final disclosureLimitations = value.demo.limitations
          .map((item) => item.trim())
          .toList(growable: false);
      if (value.resetGeneration <= 0 ||
          !value.demo.isDemo ||
          !value.demo.observedAt.isUtc ||
          disclosureSource.isEmpty ||
          disclosureLimitations.isEmpty ||
          disclosureLimitations.any((item) => item.isEmpty) ||
          !disclosureLimitations.any(
            (item) =>
                item.toLowerCase().contains('no money') ||
                item.toLowerCase().contains('no real'),
          ) ||
          value.defaultPortfolio.currency !=
              api.DemoResetResultDefaultPortfolioCurrencyEnum.USD ||
          value.defaultPortfolio.status !=
              api.DemoResetResultDefaultPortfolioStatusEnum.active ||
          value.defaultPortfolio.version <= 0 ||
          value.defaultPortfolio.name.trim().isEmpty ||
          value.entitlement.planCode !=
              api.DemoResetResultEntitlementPlanCodeEnum.free ||
          value.entitlement.source_ !=
              api.DemoResetResultEntitlementSource_Enum.demo ||
          value.entitlement.status !=
              api.DemoResetResultEntitlementStatusEnum.active ||
          value.entitlement.version <= 0) {
        _terminal();
      }
      return DemoResetReceipt(
        resetGeneration: value.resetGeneration,
        defaultPortfolioId: value.defaultPortfolio.id,
      );
    } on DioException catch (error) {
      _throwMutation(error);
    } on PrivacyFailure {
      rethrow;
    } on Object {
      _terminal();
    }
  }

  PrivacyExport _export(api.RequestPrivacyExport202ResponseData value) {
    _requireUuid(value.id);
    if (value.requestType !=
            api.RequestPrivacyExport202ResponseDataRequestTypeEnum.export_ ||
        value.format != api.RequestPrivacyExport202ResponseDataFormatEnum.zip ||
        (value.expiresAt != null && !value.expiresAt!.isUtc) ||
        (value.completedAt != null && !value.completedAt!.isUtc) ||
        (value.snapshotAt != null && !value.snapshotAt!.isUtc)) {
      _terminal();
    }
    final status = switch (value.status) {
      api.RequestPrivacyExport202ResponseDataStatusEnum.requested =>
        PrivacyExportStatus.requested,
      api.RequestPrivacyExport202ResponseDataStatusEnum.verified =>
        PrivacyExportStatus.verified,
      api.RequestPrivacyExport202ResponseDataStatusEnum.queued =>
        PrivacyExportStatus.queued,
      api.RequestPrivacyExport202ResponseDataStatusEnum.processing =>
        PrivacyExportStatus.processing,
      api.RequestPrivacyExport202ResponseDataStatusEnum.completed =>
        PrivacyExportStatus.completed,
      api.RequestPrivacyExport202ResponseDataStatusEnum.failed =>
        PrivacyExportStatus.failed,
      api.RequestPrivacyExport202ResponseDataStatusEnum.cancelled =>
        PrivacyExportStatus.cancelled,
      api.RequestPrivacyExport202ResponseDataStatusEnum.unknownDefaultOpenApi =>
        _terminal(),
    };
    final link = value.downloadLink;
    if (link != null && status != PrivacyExportStatus.completed ||
        (status == PrivacyExportStatus.failed) !=
            (value.failureCode != null && value.failureCode!.isNotEmpty)) {
      _terminal();
    }
    if (link != null) {
      final grant = _parseGrant(value.id, link);
      _downloadTokens[value.id] = grant;
    }
    return PrivacyExport(
      id: value.id,
      status: status,
      format: PrivacyExportFormat.zip,
      hasDownloadGrant: link != null,
      snapshotAt: value.snapshotAt?.toUtc(),
      completedAt: value.completedAt?.toUtc(),
      expiresAt: value.expiresAt?.toUtc(),
      failureCode: value.failureCode,
    );
  }

  String _parseGrant(
    String requestId,
    api.RequestPrivacyExport202ResponseDataDownloadLink link,
  ) {
    final uri = Uri.tryParse(link.url);
    final expectedPath = '/v1/me/privacy/exports/$requestId/download';
    final token = uri?.queryParameters['token'];
    if (uri == null ||
        !uri.hasScheme ||
        uri.scheme != _apiOrigin.scheme ||
        uri.host != _apiOrigin.host ||
        uri.port != _apiOrigin.port ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        uri.path != expectedPath ||
        uri.queryParameters.length != 1 ||
        token == null ||
        !_token.hasMatch(token) ||
        !link.expiresAt.isUtc) {
      _terminal();
    }
    return token;
  }

  @override
  void cancel() {
    _cancellationVersion += 1;
    _downloadTokens.clear();
    _downloadCancellation?.cancel('privacy_scope_disposed');
    _downloadCancellation = null;
  }
}

bool _transport(DioException error) =>
    error.type == DioExceptionType.connectionError ||
    error.type == DioExceptionType.connectionTimeout ||
    error.type == DioExceptionType.receiveTimeout ||
    error.type == DioExceptionType.sendTimeout ||
    error.type == DioExceptionType.cancel;

Never _throwRead(DioException error) {
  final code = _errorCode(error);
  if (code == 'recent_auth_required') throw const RecentAuthRequired();
  if (code == 'account_inactive') throw const AccountInactive();
  if (_transport(error)) {
    throw const PrivacyFailure(PrivacyFailureKind.retryable);
  }
  throw PrivacyFailure(_failureKind(error, code));
}

Never _throwMutation(DioException error) {
  final code = _errorCode(error);
  if (code == 'recent_auth_required') throw const RecentAuthRequired();
  if (code == 'account_inactive') throw const AccountInactive();
  if (_transport(error)) throw const AmbiguousPrivacyMutation();
  throw PrivacyFailure(_failureKind(error, code));
}

PrivacyFailureKind _failureKind(DioException error, String? code) {
  if (code == 'forbidden' || code == 'insufficient_scope') {
    return PrivacyFailureKind.forbidden;
  }
  if (code == 'conflict' ||
      code == 'idempotency_conflict' ||
      code == 'active_export_exists' ||
      code == 'deletion_in_progress') {
    return PrivacyFailureKind.conflict;
  }
  if (code == 'rate_limited' || code == 'throttled') {
    return PrivacyFailureKind.throttled;
  }
  if (code == 'service_unavailable' ||
      code == 'temporarily_unavailable' ||
      (error.response?.statusCode ?? 0) >= 500) {
    return PrivacyFailureKind.retryable;
  }
  return PrivacyFailureKind.terminal;
}

String? _errorCode(DioException error) {
  var data = error.response?.data;
  if (data is api.ErrorResponse) return data.error.code;
  if (data is Uint8List && data.length <= 64 * 1024) {
    try {
      data = jsonDecode(utf8.decode(data));
    } on Object {
      return null;
    }
  }
  if (data is! Map || data['error'] is! Map) return null;
  final code = (data['error'] as Map)['code'];
  return code is String ? code : null;
}

void _requireKey(String value) {
  if (value.length < 16 ||
      value.length > 64 ||
      value.codeUnits.any((unit) => unit < 0x21 || unit > 0x7e)) {
    _terminal();
  }
}

void _requireUuid(String value) {
  if (!_uuid.hasMatch(value)) _terminal();
}

Never _terminal() => throw const PrivacyFailure(PrivacyFailureKind.terminal);

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);
final _token = RegExp(r'^[a-f0-9]{64}$');
