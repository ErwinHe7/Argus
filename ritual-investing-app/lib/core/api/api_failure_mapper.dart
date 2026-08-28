import 'package:dio/dio.dart';

import '../cache/cached_read.dart';
import 'view_state.dart';

/// Maps generated-client failures into stable member-app failure semantics.
class ApiFailureMapper {
  const ApiFailureMapper._();

  static bool isTransportFailure(DioException error) =>
      error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout;

  static Never throwFailure(DioException error) {
    if (isTransportFailure(error)) {
      throw const OfflineException();
    }
    throw map(error);
  }

  static Never terminalContract() => throw const LoadFailure(
    LoadPhase.terminalFailure,
    message: 'The server data format is not supported by this app version.',
  );

  static String? errorCode(Object? data) {
    if (data is! Map) return null;
    final envelope = data['error'];
    if (envelope is! Map) return null;
    final code = envelope['code'];
    return code is String ? code : null;
  }

  static LoadFailure map(DioException error) {
    final code = errorCode(error.response?.data);
    final message = _errorMessage(error.response?.data);
    if (code != null) {
      return LoadFailure(switch (code) {
        'forbidden' || 'insufficient_scope' => LoadPhase.forbidden,
        'not_found' || 'resource_not_found' => LoadPhase.empty,
        'conflict' ||
        'version_conflict' ||
        'idempotency_conflict' ||
        'portfolio_archive_blocked' => LoadPhase.conflict,
        'rate_limited' || 'throttled' => LoadPhase.throttled,
        'temporarily_unavailable' ||
        'service_unavailable' => LoadPhase.retryableFailure,
        _ => LoadPhase.terminalFailure,
      }, message: message);
    }
    return LoadFailure(switch (error.response?.statusCode) {
      403 => LoadPhase.forbidden,
      404 => LoadPhase.empty,
      409 => LoadPhase.conflict,
      429 => LoadPhase.throttled,
      final status when status != null && status >= 500 =>
        LoadPhase.retryableFailure,
      _ => LoadPhase.terminalFailure,
    });
  }

  static String? _errorMessage(Object? data) {
    if (data is! Map) return null;
    final envelope = data['error'];
    if (envelope is! Map) return null;
    final message = envelope['message'];
    return message is String && message.trim().isNotEmpty ? message : null;
  }
}
