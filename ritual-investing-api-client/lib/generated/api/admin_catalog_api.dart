//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

import 'dart:async';

// ignore: unused_import
import 'dart:convert';
import 'package:ritual_investing_api_client/generated/deserialize.dart';
import 'package:dio/dio.dart';

import 'package:ritual_investing_api_client/generated/model/create_admin_asset_metric_snapshot201_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_admin_asset_metric_snapshot_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_admin_coven_qualification201_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_admin_coven_qualification_request.dart';
import 'package:ritual_investing_api_client/generated/model/error_response.dart';
import 'package:ritual_investing_api_client/generated/model/verify_admin_coven_qualification201_response.dart';
import 'package:ritual_investing_api_client/generated/model/verify_admin_coven_qualification_request.dart';

class AdminCatalogApi {
  final Dio _dio;

  const AdminCatalogApi(this._dio);

  /// createAdminAssetMetricSnapshot
  ///
  ///
  /// Parameters:
  /// * [assetId]
  /// * [idempotencyKey] - A retry-stable, tenant-and-operation-scoped command key.
  /// * [createAdminAssetMetricSnapshotRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [CreateAdminAssetMetricSnapshot201Response] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<CreateAdminAssetMetricSnapshot201Response>>
  createAdminAssetMetricSnapshot({
    required String assetId,
    required String idempotencyKey,
    required CreateAdminAssetMetricSnapshotRequest
    createAdminAssetMetricSnapshotRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/admin/assets/{asset_id}/metric-snapshots'.replaceAll(
      '{'
      r'asset_id'
      '}',
      assetId.toString(),
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
      _bodyData = jsonEncode(createAdminAssetMetricSnapshotRequest);
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

    CreateAdminAssetMetricSnapshot201Response? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<
              CreateAdminAssetMetricSnapshot201Response,
              CreateAdminAssetMetricSnapshot201Response
            >(
              rawData,
              'CreateAdminAssetMetricSnapshot201Response',
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

    return Response<CreateAdminAssetMetricSnapshot201Response>(
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

  /// createAdminCovenQualification
  ///
  ///
  /// Parameters:
  /// * [entryId]
  /// * [idempotencyKey] - A retry-stable, tenant-and-operation-scoped command key.
  /// * [createAdminCovenQualificationRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [CreateAdminCovenQualification201Response] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<CreateAdminCovenQualification201Response>>
  createAdminCovenQualification({
    required String entryId,
    required String idempotencyKey,
    required CreateAdminCovenQualificationRequest
    createAdminCovenQualificationRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/admin/coven-entries/{entry_id}/qualifications'
        .replaceAll(
          '{'
          r'entry_id'
          '}',
          entryId.toString(),
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
      _bodyData = jsonEncode(createAdminCovenQualificationRequest);
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

    CreateAdminCovenQualification201Response? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<
              CreateAdminCovenQualification201Response,
              CreateAdminCovenQualification201Response
            >(
              rawData,
              'CreateAdminCovenQualification201Response',
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

    return Response<CreateAdminCovenQualification201Response>(
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

  /// verifyAdminCovenQualification
  ///
  ///
  /// Parameters:
  /// * [qualificationId]
  /// * [idempotencyKey] - A retry-stable, tenant-and-operation-scoped command key.
  /// * [verifyAdminCovenQualificationRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [VerifyAdminCovenQualification201Response] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<VerifyAdminCovenQualification201Response>>
  verifyAdminCovenQualification({
    required String qualificationId,
    required String idempotencyKey,
    required VerifyAdminCovenQualificationRequest
    verifyAdminCovenQualificationRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path =
        r'/v1/admin/coven-qualifications/{qualification_id}/verifications'
            .replaceAll(
              '{'
              r'qualification_id'
              '}',
              qualificationId.toString(),
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
      _bodyData = jsonEncode(verifyAdminCovenQualificationRequest);
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

    VerifyAdminCovenQualification201Response? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<
              VerifyAdminCovenQualification201Response,
              VerifyAdminCovenQualification201Response
            >(
              rawData,
              'VerifyAdminCovenQualification201Response',
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

    return Response<VerifyAdminCovenQualification201Response>(
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
