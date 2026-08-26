//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

import 'dart:async';

// ignore: unused_import
import 'dart:convert';
import 'package:ritual_investing_api_client/generated/deserialize.dart';
import 'package:dio/dio.dart';

import 'package:ritual_investing_api_client/generated/model/create_admin_moderation_case_request.dart';
import 'package:ritual_investing_api_client/generated/model/error_response.dart';
import 'package:ritual_investing_api_client/generated/model/get_admin_moderation_case200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_moderation_reports200_response.dart';
import 'package:ritual_investing_api_client/generated/model/patch_admin_moderation_case_request.dart';

class AdminModerationApi {
  final Dio _dio;

  const AdminModerationApi(this._dio);

  /// createAdminModerationCase
  ///
  ///
  /// Parameters:
  /// * [reportId]
  /// * [idempotencyKey] - A retry-stable, tenant-and-operation-scoped command key.
  /// * [createAdminModerationCaseRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [GetAdminModerationCase200Response] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<GetAdminModerationCase200Response>>
  createAdminModerationCase({
    required String reportId,
    required String idempotencyKey,
    required CreateAdminModerationCaseRequest createAdminModerationCaseRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/admin/moderation/reports/{report_id}/cases'.replaceAll(
      '{'
      r'report_id'
      '}',
      reportId.toString(),
    );
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{
        r'idempotency-key': idempotencyKey,
        ...?headers,
      },
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {'type': 'oauth2', 'name': 'Auth0OAuth'},
          {
            'type': 'apiKey',
            'name': 'CloudflareAccess',
            'keyName': 'Cf-Access-Jwt-Assertion',
            'where': 'header',
          },
        ],
        ...?extra,
      },
      contentType: 'application/json',
      validateStatus: validateStatus,
    );

    dynamic _bodyData;

    try {
      _bodyData = jsonEncode(createAdminModerationCaseRequest);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _options.compose(_dio.options, _path),
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    final _response = await _dio.request<Object>(
      _path,
      data: _bodyData,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    GetAdminModerationCase200Response? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<
              GetAdminModerationCase200Response,
              GetAdminModerationCase200Response
            >(rawData, 'GetAdminModerationCase200Response', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<GetAdminModerationCase200Response>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

  /// getAdminModerationCase
  ///
  ///
  /// Parameters:
  /// * [caseId]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [GetAdminModerationCase200Response] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<GetAdminModerationCase200Response>> getAdminModerationCase({
    required String caseId,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/admin/moderation/cases/{case_id}'.replaceAll(
      '{'
      r'case_id'
      '}',
      caseId.toString(),
    );
    final _options = Options(
      method: r'GET',
      headers: <String, dynamic>{...?headers},
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {'type': 'oauth2', 'name': 'Auth0OAuth'},
          {
            'type': 'apiKey',
            'name': 'CloudflareAccess',
            'keyName': 'Cf-Access-Jwt-Assertion',
            'where': 'header',
          },
        ],
        ...?extra,
      },
      validateStatus: validateStatus,
    );

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    GetAdminModerationCase200Response? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<
              GetAdminModerationCase200Response,
              GetAdminModerationCase200Response
            >(rawData, 'GetAdminModerationCase200Response', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<GetAdminModerationCase200Response>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

  /// listAdminModerationReports
  ///
  ///
  /// Parameters:
  /// * [status]
  /// * [targetKind]
  /// * [from]
  /// * [to]
  /// * [limit]
  /// * [cursor]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [ListAdminModerationReports200Response] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<ListAdminModerationReports200Response>>
  listAdminModerationReports({
    String? status,
    String? targetKind,
    DateTime? from,
    DateTime? to,
    int? limit = 20,
    String? cursor,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/admin/moderation/reports';
    final _options = Options(
      method: r'GET',
      headers: <String, dynamic>{...?headers},
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {'type': 'oauth2', 'name': 'Auth0OAuth'},
          {
            'type': 'apiKey',
            'name': 'CloudflareAccess',
            'keyName': 'Cf-Access-Jwt-Assertion',
            'where': 'header',
          },
        ],
        ...?extra,
      },
      validateStatus: validateStatus,
    );

    final _queryParameters = <String, dynamic>{
      if (status != null) r'status': status,
      if (targetKind != null) r'target_kind': targetKind,
      if (from != null) r'from': from,
      if (to != null) r'to': to,
      if (limit != null) r'limit': limit,
      if (cursor != null) r'cursor': cursor,
    };

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      queryParameters: _queryParameters,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    ListAdminModerationReports200Response? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<
              ListAdminModerationReports200Response,
              ListAdminModerationReports200Response
            >(rawData, 'ListAdminModerationReports200Response', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<ListAdminModerationReports200Response>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

  /// patchAdminModerationCase
  ///
  ///
  /// Parameters:
  /// * [caseId]
  /// * [ifMatch]
  /// * [patchAdminModerationCaseRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [GetAdminModerationCase200Response] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<GetAdminModerationCase200Response>> patchAdminModerationCase({
    required String caseId,
    required String ifMatch,
    required PatchAdminModerationCaseRequest patchAdminModerationCaseRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/admin/moderation/cases/{case_id}'.replaceAll(
      '{'
      r'case_id'
      '}',
      caseId.toString(),
    );
    final _options = Options(
      method: r'PATCH',
      headers: <String, dynamic>{r'if-match': ifMatch, ...?headers},
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {'type': 'oauth2', 'name': 'Auth0OAuth'},
          {
            'type': 'apiKey',
            'name': 'CloudflareAccess',
            'keyName': 'Cf-Access-Jwt-Assertion',
            'where': 'header',
          },
        ],
        ...?extra,
      },
      contentType: 'application/json',
      validateStatus: validateStatus,
    );

    dynamic _bodyData;

    try {
      _bodyData = jsonEncode(patchAdminModerationCaseRequest);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _options.compose(_dio.options, _path),
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    final _response = await _dio.request<Object>(
      _path,
      data: _bodyData,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    GetAdminModerationCase200Response? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<
              GetAdminModerationCase200Response,
              GetAdminModerationCase200Response
            >(rawData, 'GetAdminModerationCase200Response', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<GetAdminModerationCase200Response>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }
}
