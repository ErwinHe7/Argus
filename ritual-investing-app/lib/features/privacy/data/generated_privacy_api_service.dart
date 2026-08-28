// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart'
    as api;

import '../domain/model.dart';
import 'repository.dart';

class GeneratedPrivacyService implements PrivacyService {
  GeneratedPrivacyService(api.RitualInvestingApiClient client)
    : _privacy = api.PrivacyApi(client.dio),
      _session = api.SessionApi(client.dio),
      _download = Dio(),
      _apiOrigin = Uri.parse(client.dio.options.baseUrl);

  final api.PrivacyApi _privacy;
  final api.SessionApi _session;
  final Dio _download;
  final Uri _apiOrigin;
  CancelToken? _downloadCancellation;

  @override
  Future<PrivacyExport> requestExport(String idempotencyKey) async {
    _requireKey(idempotencyKey);
    try {
      final value = (await _privacy.requestPrivacyAction(
        idempotencyKey: idempotencyKey,
        requestPrivacyActionRequest: api.RequestPrivacyActionRequest(
          requestType: api.RequestPrivacyActionRequestRequestTypeEnum.export_,
        ),
      )).data?.data;
      if (value == null) _terminal();
      return _export(value);
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
    try {
      final values = (await _privacy.listPrivacyRequests()).data?.data;
      if (values == null) _terminal();
      final matches = values.where((value) => value.id == requestId).toList();
      if (matches.length != 1) _terminal();
      return _export(matches.single);
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
    final cancellation = CancelToken();
    _downloadCancellation?.cancel('superseded');
    _downloadCancellation = cancellation;
    try {
      final grant = (await _privacy.createPrivacyDownloadUrl(
        requestId: requestId,
        cancelToken: cancellation,
      )).data?.data;
      if (grant == null || !grant.expiresAt.isAfter(DateTime.now().toUtc())) {
        _terminal();
      }
      final uri = Uri.tryParse(grant.url);
      if (uri == null ||
          uri.scheme != _apiOrigin.scheme ||
          uri.host != _apiOrigin.host ||
          uri.port != _apiOrigin.port ||
          uri.userInfo.isNotEmpty ||
          uri.fragment.isNotEmpty) {
        _terminal();
      }
      final response = await _download.get<List<int>>(
        uri.toString(),
        options: Options(responseType: ResponseType.bytes),
        cancelToken: cancellation,
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) _terminal();
      return Uint8List.fromList(bytes);
    } on DioException catch (error) {
      final code = _errorCode(error);
      if (code == 'recent_auth_required' || error.response?.statusCode == 403) {
        throw const RecentAuthRequired();
      }
      if (code == 'not_found' || error.response?.statusCode == 404) {
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
  Future<PrivacyDeletionReceipt> requestDeletion(
    String idempotencyKey,
    String stepUpReceipt,
  ) async {
    _requireKey(idempotencyKey);
    if (stepUpReceipt.length < 32 ||
        stepUpReceipt.length > 512 ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(stepUpReceipt)) {
      throw const RecentAuthRequired();
    }
    try {
      final value = (await _privacy.requestPrivacyAction(
        idempotencyKey: idempotencyKey,
        requestPrivacyActionRequest: api.RequestPrivacyActionRequest(
          requestType: api.RequestPrivacyActionRequestRequestTypeEnum.deletion,
          stepUpReceipt: stepUpReceipt,
        ),
      )).data?.data;
      if (value == null ||
          value.requestType != api.PrivacyRequestRequestTypeEnum.deletion) {
        _terminal();
      }
      _requireUuid(value.id);
      return PrivacyDeletionReceipt(
        requestId: value.id,
        status: _deletionStatus(value.status),
        requestedAt: value.requestedAt.toUtc(),
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
      if (code == 'account_inactive') {
        return true;
      }
      _throwRead(error);
    } on PrivacyFailure {
      rethrow;
    } on Object {
      _terminal();
    }
  }

  PrivacyExport _export(api.PrivacyRequest value) {
    _requireUuid(value.id);
    if (value.requestType != api.PrivacyRequestRequestTypeEnum.export_) {
      _terminal();
    }
    final status = _status(value.status);
    if ((status == PrivacyExportStatus.failed) !=
        (value.failureCode != null && value.failureCode!.trim().isNotEmpty)) {
      _terminal();
    }
    return PrivacyExport(
      id: value.id,
      status: status,
      format: PrivacyExportFormat.zip,
      hasDownloadGrant: status == PrivacyExportStatus.completed,
      completedAt: value.completedAt?.toUtc(),
      failureCode: value.failureCode,
    );
  }

  PrivacyExportStatus _status(api.PrivacyRequestStatusEnum value) =>
      switch (value) {
        api.PrivacyRequestStatusEnum.requested => PrivacyExportStatus.requested,
        api.PrivacyRequestStatusEnum.verified => PrivacyExportStatus.verified,
        api.PrivacyRequestStatusEnum.queued => PrivacyExportStatus.queued,
        api.PrivacyRequestStatusEnum.processing =>
          PrivacyExportStatus.processing,
        api.PrivacyRequestStatusEnum.completed => PrivacyExportStatus.completed,
        api.PrivacyRequestStatusEnum.failed => PrivacyExportStatus.failed,
        api.PrivacyRequestStatusEnum.cancelled => PrivacyExportStatus.cancelled,
        api.PrivacyRequestStatusEnum.unknownDefaultOpenApi => _terminal(),
      };

  PrivacyDeletionStatus _deletionStatus(
    api.PrivacyRequestStatusEnum value,
  ) => switch (value) {
    api.PrivacyRequestStatusEnum.requested => PrivacyDeletionStatus.requested,
    api.PrivacyRequestStatusEnum.verified => PrivacyDeletionStatus.verified,
    api.PrivacyRequestStatusEnum.queued => PrivacyDeletionStatus.queued,
    api.PrivacyRequestStatusEnum.processing => PrivacyDeletionStatus.processing,
    api.PrivacyRequestStatusEnum.completed => PrivacyDeletionStatus.completed,
    api.PrivacyRequestStatusEnum.failed => PrivacyDeletionStatus.failed,
    api.PrivacyRequestStatusEnum.cancelled => PrivacyDeletionStatus.cancelled,
    api.PrivacyRequestStatusEnum.unknownDefaultOpenApi => _terminal(),
  };

  @override
  void cancel() {
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
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);
