//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

import 'dart:async';

// ignore: unused_import
import 'dart:convert';
import 'package:ritual_investing_api_client/generated/deserialize.dart';
import 'package:dio/dio.dart';

import 'package:ritual_investing_api_client/generated/model/create_admin_asset_codex201_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_rowan_script_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_rowan_script_revision_request.dart';
import 'package:ritual_investing_api_client/generated/model/decide_admin_asset_codex_review_request.dart';
import 'package:ritual_investing_api_client/generated/model/error_response.dart';
import 'package:ritual_investing_api_client/generated/model/get_admin_asset_codex_revision200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response.dart';
import 'package:ritual_investing_api_client/generated/model/patch_rowan_script_revision_request.dart';
import 'package:ritual_investing_api_client/generated/model/publish_admin_asset_codex_revision_request.dart';
import 'package:ritual_investing_api_client/generated/model/request_admin_asset_codex_review_request.dart';
import 'package:ritual_investing_api_client/generated/model/withdraw_admin_asset_codex_request.dart';

class AdminRowanScriptApi {
  final Dio _dio;

  const AdminRowanScriptApi(this._dio);

  /// createAdminRowanScript
  ///
  ///
  /// Parameters:
  /// * [idempotencyKey] - A retry-stable, tenant-and-operation-scoped command key.
  /// * [createRowanScriptRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [CreateAdminAssetCodex201Response] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<CreateAdminAssetCodex201Response>> createAdminRowanScript({
    required String idempotencyKey,
    required CreateRowanScriptRequest createRowanScriptRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/admin/rowan-scripts';
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
      _bodyData = jsonEncode(createRowanScriptRequest);
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

    CreateAdminAssetCodex201Response? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<
              CreateAdminAssetCodex201Response,
              CreateAdminAssetCodex201Response
            >(rawData, 'CreateAdminAssetCodex201Response', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<CreateAdminAssetCodex201Response>(
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

  /// createAdminRowanScriptRevision
  ///
  ///
  /// Parameters:
  /// * [itemId]
  /// * [idempotencyKey] - A retry-stable, tenant-and-operation-scoped command key.
  /// * [createRowanScriptRevisionRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [CreateAdminAssetCodex201Response] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<CreateAdminAssetCodex201Response>>
  createAdminRowanScriptRevision({
    required String itemId,
    required String idempotencyKey,
    required CreateRowanScriptRevisionRequest createRowanScriptRevisionRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/admin/rowan-scripts/{item_id}/revisions'.replaceAll(
      '{'
      r'item_id'
      '}',
      itemId.toString(),
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
      _bodyData = jsonEncode(createRowanScriptRevisionRequest);
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

    CreateAdminAssetCodex201Response? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<
              CreateAdminAssetCodex201Response,
              CreateAdminAssetCodex201Response
            >(rawData, 'CreateAdminAssetCodex201Response', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<CreateAdminAssetCodex201Response>(
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

  /// decideAdminRowanScriptReview
  ///
  ///
  /// Parameters:
  /// * [itemId]
  /// * [revisionId]
  /// * [idempotencyKey] - A retry-stable, tenant-and-operation-scoped command key.
  /// * [decideAdminAssetCodexReviewRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [GetAdminAssetCodexRevision200Response] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<GetAdminAssetCodexRevision200Response>>
  decideAdminRowanScriptReview({
    required String itemId,
    required String revisionId,
    required String idempotencyKey,
    required DecideAdminAssetCodexReviewRequest
    decideAdminAssetCodexReviewRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path =
        r'/v1/admin/rowan-scripts/{item_id}/revisions/{revision_id}/review-decisions'
            .replaceAll(
              '{'
              r'item_id'
              '}',
              itemId.toString(),
            )
            .replaceAll(
              '{'
              r'revision_id'
              '}',
              revisionId.toString(),
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
      _bodyData = jsonEncode(decideAdminAssetCodexReviewRequest);
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

    GetAdminAssetCodexRevision200Response? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<
              GetAdminAssetCodexRevision200Response,
              GetAdminAssetCodexRevision200Response
            >(rawData, 'GetAdminAssetCodexRevision200Response', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<GetAdminAssetCodexRevision200Response>(
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

  /// getAdminRowanScript
  ///
  ///
  /// Parameters:
  /// * [itemId]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [CreateAdminAssetCodex201Response] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<CreateAdminAssetCodex201Response>> getAdminRowanScript({
    required String itemId,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/admin/rowan-scripts/{item_id}'.replaceAll(
      '{'
      r'item_id'
      '}',
      itemId.toString(),
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

    CreateAdminAssetCodex201Response? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<
              CreateAdminAssetCodex201Response,
              CreateAdminAssetCodex201Response
            >(rawData, 'CreateAdminAssetCodex201Response', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<CreateAdminAssetCodex201Response>(
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

  /// getAdminRowanScriptRevision
  ///
  ///
  /// Parameters:
  /// * [itemId]
  /// * [revisionId]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [GetAdminAssetCodexRevision200Response] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<GetAdminAssetCodexRevision200Response>>
  getAdminRowanScriptRevision({
    required String itemId,
    required String revisionId,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/admin/rowan-scripts/{item_id}/revisions/{revision_id}'
        .replaceAll(
          '{'
          r'item_id'
          '}',
          itemId.toString(),
        )
        .replaceAll(
          '{'
          r'revision_id'
          '}',
          revisionId.toString(),
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

    GetAdminAssetCodexRevision200Response? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<
              GetAdminAssetCodexRevision200Response,
              GetAdminAssetCodexRevision200Response
            >(rawData, 'GetAdminAssetCodexRevision200Response', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<GetAdminAssetCodexRevision200Response>(
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

  /// listAdminRowanScript
  ///
  ///
  /// Parameters:
  /// * [state]
  /// * [authorStaffId]
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
  /// Returns a [Future] containing a [Response] with a [ListAdminAssetCodex200Response] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<ListAdminAssetCodex200Response>> listAdminRowanScript({
    String? state,
    String? authorStaffId,
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
    final _path = r'/v1/admin/rowan-scripts';
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
      if (state != null) r'state': state,
      if (authorStaffId != null) r'author_staff_id': authorStaffId,
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

    ListAdminAssetCodex200Response? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<
              ListAdminAssetCodex200Response,
              ListAdminAssetCodex200Response
            >(rawData, 'ListAdminAssetCodex200Response', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<ListAdminAssetCodex200Response>(
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

  /// patchAdminRowanScriptRevision
  ///
  ///
  /// Parameters:
  /// * [itemId]
  /// * [revisionId]
  /// * [ifMatch]
  /// * [patchRowanScriptRevisionRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [GetAdminAssetCodexRevision200Response] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<GetAdminAssetCodexRevision200Response>>
  patchAdminRowanScriptRevision({
    required String itemId,
    required String revisionId,
    required String ifMatch,
    required PatchRowanScriptRevisionRequest patchRowanScriptRevisionRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/admin/rowan-scripts/{item_id}/revisions/{revision_id}'
        .replaceAll(
          '{'
          r'item_id'
          '}',
          itemId.toString(),
        )
        .replaceAll(
          '{'
          r'revision_id'
          '}',
          revisionId.toString(),
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
      _bodyData = jsonEncode(patchRowanScriptRevisionRequest);
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

    GetAdminAssetCodexRevision200Response? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<
              GetAdminAssetCodexRevision200Response,
              GetAdminAssetCodexRevision200Response
            >(rawData, 'GetAdminAssetCodexRevision200Response', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<GetAdminAssetCodexRevision200Response>(
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

  /// previewAdminRowanScriptRevision
  ///
  ///
  /// Parameters:
  /// * [itemId]
  /// * [revisionId]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [GetAdminAssetCodexRevision200Response] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<GetAdminAssetCodexRevision200Response>>
  previewAdminRowanScriptRevision({
    required String itemId,
    required String revisionId,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path =
        r'/v1/admin/rowan-scripts/{item_id}/revisions/{revision_id}/preview'
            .replaceAll(
              '{'
              r'item_id'
              '}',
              itemId.toString(),
            )
            .replaceAll(
              '{'
              r'revision_id'
              '}',
              revisionId.toString(),
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

    GetAdminAssetCodexRevision200Response? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<
              GetAdminAssetCodexRevision200Response,
              GetAdminAssetCodexRevision200Response
            >(rawData, 'GetAdminAssetCodexRevision200Response', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<GetAdminAssetCodexRevision200Response>(
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

  /// publishAdminRowanScriptRevision
  ///
  ///
  /// Parameters:
  /// * [itemId]
  /// * [revisionId]
  /// * [idempotencyKey] - A retry-stable, tenant-and-operation-scoped command key.
  /// * [publishAdminAssetCodexRevisionRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [CreateAdminAssetCodex201Response] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<CreateAdminAssetCodex201Response>>
  publishAdminRowanScriptRevision({
    required String itemId,
    required String revisionId,
    required String idempotencyKey,
    required PublishAdminAssetCodexRevisionRequest
    publishAdminAssetCodexRevisionRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path =
        r'/v1/admin/rowan-scripts/{item_id}/revisions/{revision_id}/publications'
            .replaceAll(
              '{'
              r'item_id'
              '}',
              itemId.toString(),
            )
            .replaceAll(
              '{'
              r'revision_id'
              '}',
              revisionId.toString(),
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
      _bodyData = jsonEncode(publishAdminAssetCodexRevisionRequest);
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

    CreateAdminAssetCodex201Response? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<
              CreateAdminAssetCodex201Response,
              CreateAdminAssetCodex201Response
            >(rawData, 'CreateAdminAssetCodex201Response', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<CreateAdminAssetCodex201Response>(
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

  /// requestAdminRowanScriptReview
  ///
  ///
  /// Parameters:
  /// * [itemId]
  /// * [revisionId]
  /// * [idempotencyKey] - A retry-stable, tenant-and-operation-scoped command key.
  /// * [requestAdminAssetCodexReviewRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [GetAdminAssetCodexRevision200Response] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<GetAdminAssetCodexRevision200Response>>
  requestAdminRowanScriptReview({
    required String itemId,
    required String revisionId,
    required String idempotencyKey,
    required RequestAdminAssetCodexReviewRequest
    requestAdminAssetCodexReviewRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path =
        r'/v1/admin/rowan-scripts/{item_id}/revisions/{revision_id}/review-requests'
            .replaceAll(
              '{'
              r'item_id'
              '}',
              itemId.toString(),
            )
            .replaceAll(
              '{'
              r'revision_id'
              '}',
              revisionId.toString(),
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
      _bodyData = jsonEncode(requestAdminAssetCodexReviewRequest);
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

    GetAdminAssetCodexRevision200Response? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<
              GetAdminAssetCodexRevision200Response,
              GetAdminAssetCodexRevision200Response
            >(rawData, 'GetAdminAssetCodexRevision200Response', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<GetAdminAssetCodexRevision200Response>(
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

  /// withdrawAdminRowanScript
  ///
  ///
  /// Parameters:
  /// * [itemId]
  /// * [idempotencyKey] - A retry-stable, tenant-and-operation-scoped command key.
  /// * [withdrawAdminAssetCodexRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [CreateAdminAssetCodex201Response] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<CreateAdminAssetCodex201Response>> withdrawAdminRowanScript({
    required String itemId,
    required String idempotencyKey,
    required WithdrawAdminAssetCodexRequest withdrawAdminAssetCodexRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/admin/rowan-scripts/{item_id}/withdrawals'.replaceAll(
      '{'
      r'item_id'
      '}',
      itemId.toString(),
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
      _bodyData = jsonEncode(withdrawAdminAssetCodexRequest);
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

    CreateAdminAssetCodex201Response? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<
              CreateAdminAssetCodex201Response,
              CreateAdminAssetCodex201Response
            >(rawData, 'CreateAdminAssetCodex201Response', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<CreateAdminAssetCodex201Response>(
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
