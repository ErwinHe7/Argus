//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

import 'dart:async';

// ignore: unused_import
import 'dart:convert';
import 'package:ritual_investing_api_client/generated/deserialize.dart';
import 'package:dio/dio.dart';

import 'package:ritual_investing_api_client/generated/model/complete_media_upload202_response.dart';
import 'package:ritual_investing_api_client/generated/model/complete_media_upload_request.dart';
import 'package:ritual_investing_api_client/generated/model/error_response.dart';
import 'package:ritual_investing_api_client/generated/model/get_admin_media200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_media200_response.dart';
import 'package:ritual_investing_api_client/generated/model/request_media_upload201_response.dart';
import 'package:ritual_investing_api_client/generated/model/request_media_upload_request.dart';
import 'package:ritual_investing_api_client/generated/model/retry_admin_job_request.dart';

class AdminMediaApi {
  final Dio _dio;

  const AdminMediaApi(this._dio);

  /// completeMediaUpload
  ///
  ///
  /// Parameters:
  /// * [mediaId]
  /// * [idempotencyKey] - A retry-stable, tenant-and-operation-scoped command key.
  /// * [completeMediaUploadRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [CompleteMediaUpload202Response] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<CompleteMediaUpload202Response>> completeMediaUpload({
    required String mediaId,
    required String idempotencyKey,
    required CompleteMediaUploadRequest completeMediaUploadRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/admin/media/{media_id}/complete'.replaceAll(
      '{'
      r'media_id'
      '}',
      mediaId.toString(),
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
      _bodyData = jsonEncode(completeMediaUploadRequest);
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

    CompleteMediaUpload202Response? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<
              CompleteMediaUpload202Response,
              CompleteMediaUpload202Response
            >(rawData, 'CompleteMediaUpload202Response', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<CompleteMediaUpload202Response>(
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

  /// deleteAdminMedia
  ///
  ///
  /// Parameters:
  /// * [mediaId]
  /// * [ifMatch]
  /// * [retryAdminJobRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future]
  /// Throws [DioException] if API call or serialization fails
  Future<Response<void>> deleteAdminMedia({
    required String mediaId,
    required String ifMatch,
    required RetryAdminJobRequest retryAdminJobRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/admin/media/{media_id}'.replaceAll(
      '{'
      r'media_id'
      '}',
      mediaId.toString(),
    );
    final _options = Options(
      method: r'DELETE',
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
      _bodyData = jsonEncode(retryAdminJobRequest);
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

    return _response;
  }

  /// getAdminMedia
  ///
  ///
  /// Parameters:
  /// * [mediaId]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [GetAdminMedia200Response] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<GetAdminMedia200Response>> getAdminMedia({
    required String mediaId,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/admin/media/{media_id}'.replaceAll(
      '{'
      r'media_id'
      '}',
      mediaId.toString(),
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

    GetAdminMedia200Response? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<GetAdminMedia200Response, GetAdminMedia200Response>(
              rawData,
              'GetAdminMedia200Response',
              growable: true,
            );
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<GetAdminMedia200Response>(
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

  /// listAdminMedia
  ///
  ///
  /// Parameters:
  /// * [status]
  /// * [mimeType]
  /// * [search]
  /// * [limit]
  /// * [cursor]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [ListAdminMedia200Response] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<ListAdminMedia200Response>> listAdminMedia({
    String? status,
    String? mimeType,
    String? search,
    int? limit = 20,
    String? cursor,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/admin/media';
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
      if (mimeType != null) r'mime_type': mimeType,
      if (search != null) r'search': search,
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

    ListAdminMedia200Response? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<ListAdminMedia200Response, ListAdminMedia200Response>(
              rawData,
              'ListAdminMedia200Response',
              growable: true,
            );
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<ListAdminMedia200Response>(
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

  /// requestMediaUpload
  ///
  ///
  /// Parameters:
  /// * [idempotencyKey] - A retry-stable, tenant-and-operation-scoped command key.
  /// * [requestMediaUploadRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [RequestMediaUpload201Response] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<RequestMediaUpload201Response>> requestMediaUpload({
    required String idempotencyKey,
    required RequestMediaUploadRequest requestMediaUploadRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/admin/media/upload-requests';
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
      _bodyData = jsonEncode(requestMediaUploadRequest);
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

    RequestMediaUpload201Response? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<
              RequestMediaUpload201Response,
              RequestMediaUpload201Response
            >(rawData, 'RequestMediaUpload201Response', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<RequestMediaUpload201Response>(
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

  /// uploadMediaQuarantineContent
  ///
  ///
  /// Parameters:
  /// * [mediaId]
  /// * [body]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future]
  /// Throws [DioException] if API call or serialization fails
  Future<Response<void>> uploadMediaQuarantineContent({
    required String mediaId,
    required MultipartFile body,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/admin/media/upload-requests/{media_id}/content'
        .replaceAll(
          '{'
          r'media_id'
          '}',
          mediaId.toString(),
        );
    final _options = Options(
      method: r'PUT',
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
      contentType: 'application/octet-stream',
      validateStatus: validateStatus,
    );

    final _bodyData = body;

    final _response = await _dio.request<Object>(
      _path,
      data: _bodyData,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    return _response;
  }
}
