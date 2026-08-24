// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_privacy_export202_response_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RequestPrivacyExport202ResponseDataCWProxy {
  RequestPrivacyExport202ResponseData completedAt(DateTime? completedAt);

  RequestPrivacyExport202ResponseData downloadLink(
    RequestPrivacyExport202ResponseDataDownloadLink? downloadLink,
  );

  RequestPrivacyExport202ResponseData expiresAt(DateTime? expiresAt);

  RequestPrivacyExport202ResponseData failureCode(String? failureCode);

  RequestPrivacyExport202ResponseData format(
    RequestPrivacyExport202ResponseDataFormatEnum format,
  );

  RequestPrivacyExport202ResponseData id(String id);

  RequestPrivacyExport202ResponseData requestType(
    RequestPrivacyExport202ResponseDataRequestTypeEnum requestType,
  );

  RequestPrivacyExport202ResponseData snapshotAt(DateTime? snapshotAt);

  RequestPrivacyExport202ResponseData status(
    RequestPrivacyExport202ResponseDataStatusEnum status,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestPrivacyExport202ResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestPrivacyExport202ResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestPrivacyExport202ResponseData call({
    DateTime? completedAt,
    RequestPrivacyExport202ResponseDataDownloadLink? downloadLink,
    DateTime? expiresAt,
    String? failureCode,
    RequestPrivacyExport202ResponseDataFormatEnum format,
    String id,
    RequestPrivacyExport202ResponseDataRequestTypeEnum requestType,
    DateTime? snapshotAt,
    RequestPrivacyExport202ResponseDataStatusEnum status,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRequestPrivacyExport202ResponseData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRequestPrivacyExport202ResponseData.copyWith.fieldName(...)`
class _$RequestPrivacyExport202ResponseDataCWProxyImpl
    implements _$RequestPrivacyExport202ResponseDataCWProxy {
  const _$RequestPrivacyExport202ResponseDataCWProxyImpl(this._value);

  final RequestPrivacyExport202ResponseData _value;

  @override
  RequestPrivacyExport202ResponseData completedAt(DateTime? completedAt) =>
      this(completedAt: completedAt);

  @override
  RequestPrivacyExport202ResponseData downloadLink(
    RequestPrivacyExport202ResponseDataDownloadLink? downloadLink,
  ) => this(downloadLink: downloadLink);

  @override
  RequestPrivacyExport202ResponseData expiresAt(DateTime? expiresAt) =>
      this(expiresAt: expiresAt);

  @override
  RequestPrivacyExport202ResponseData failureCode(String? failureCode) =>
      this(failureCode: failureCode);

  @override
  RequestPrivacyExport202ResponseData format(
    RequestPrivacyExport202ResponseDataFormatEnum format,
  ) => this(format: format);

  @override
  RequestPrivacyExport202ResponseData id(String id) => this(id: id);

  @override
  RequestPrivacyExport202ResponseData requestType(
    RequestPrivacyExport202ResponseDataRequestTypeEnum requestType,
  ) => this(requestType: requestType);

  @override
  RequestPrivacyExport202ResponseData snapshotAt(DateTime? snapshotAt) =>
      this(snapshotAt: snapshotAt);

  @override
  RequestPrivacyExport202ResponseData status(
    RequestPrivacyExport202ResponseDataStatusEnum status,
  ) => this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestPrivacyExport202ResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestPrivacyExport202ResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestPrivacyExport202ResponseData call({
    Object? completedAt = const $CopyWithPlaceholder(),
    Object? downloadLink = const $CopyWithPlaceholder(),
    Object? expiresAt = const $CopyWithPlaceholder(),
    Object? failureCode = const $CopyWithPlaceholder(),
    Object? format = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? requestType = const $CopyWithPlaceholder(),
    Object? snapshotAt = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return RequestPrivacyExport202ResponseData(
      completedAt: completedAt == const $CopyWithPlaceholder()
          ? _value.completedAt
          // ignore: cast_nullable_to_non_nullable
          : completedAt as DateTime?,
      downloadLink: downloadLink == const $CopyWithPlaceholder()
          ? _value.downloadLink
          // ignore: cast_nullable_to_non_nullable
          : downloadLink as RequestPrivacyExport202ResponseDataDownloadLink?,
      expiresAt: expiresAt == const $CopyWithPlaceholder()
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime?,
      failureCode: failureCode == const $CopyWithPlaceholder()
          ? _value.failureCode
          // ignore: cast_nullable_to_non_nullable
          : failureCode as String?,
      format: format == const $CopyWithPlaceholder()
          ? _value.format
          // ignore: cast_nullable_to_non_nullable
          : format as RequestPrivacyExport202ResponseDataFormatEnum,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      requestType: requestType == const $CopyWithPlaceholder()
          ? _value.requestType
          // ignore: cast_nullable_to_non_nullable
          : requestType as RequestPrivacyExport202ResponseDataRequestTypeEnum,
      snapshotAt: snapshotAt == const $CopyWithPlaceholder()
          ? _value.snapshotAt
          // ignore: cast_nullable_to_non_nullable
          : snapshotAt as DateTime?,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as RequestPrivacyExport202ResponseDataStatusEnum,
    );
  }
}

extension $RequestPrivacyExport202ResponseDataCopyWith
    on RequestPrivacyExport202ResponseData {
  /// Returns a callable class that can be used as follows: `instanceOfRequestPrivacyExport202ResponseData.copyWith(...)` or like so:`instanceOfRequestPrivacyExport202ResponseData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RequestPrivacyExport202ResponseDataCWProxy get copyWith =>
      _$RequestPrivacyExport202ResponseDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestPrivacyExport202ResponseData
_$RequestPrivacyExport202ResponseDataFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'RequestPrivacyExport202ResponseData',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'completed_at',
            'download_link',
            'expires_at',
            'failure_code',
            'format',
            'id',
            'request_type',
            'snapshot_at',
            'status',
          ],
        );
        final val = RequestPrivacyExport202ResponseData(
          completedAt: $checkedConvert(
            'completed_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          downloadLink: $checkedConvert(
            'download_link',
            (v) => v == null
                ? null
                : RequestPrivacyExport202ResponseDataDownloadLink.fromJson(
                    v as Map<String, dynamic>,
                  ),
          ),
          expiresAt: $checkedConvert(
            'expires_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          failureCode: $checkedConvert('failure_code', (v) => v as String?),
          format: $checkedConvert(
            'format',
            (v) => $enumDecode(
              _$RequestPrivacyExport202ResponseDataFormatEnumEnumMap,
              v,
              unknownValue: RequestPrivacyExport202ResponseDataFormatEnum
                  .unknownDefaultOpenApi,
            ),
          ),
          id: $checkedConvert('id', (v) => v as String),
          requestType: $checkedConvert(
            'request_type',
            (v) => $enumDecode(
              _$RequestPrivacyExport202ResponseDataRequestTypeEnumEnumMap,
              v,
              unknownValue: RequestPrivacyExport202ResponseDataRequestTypeEnum
                  .unknownDefaultOpenApi,
            ),
          ),
          snapshotAt: $checkedConvert(
            'snapshot_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$RequestPrivacyExport202ResponseDataStatusEnumEnumMap,
              v,
              unknownValue: RequestPrivacyExport202ResponseDataStatusEnum
                  .unknownDefaultOpenApi,
            ),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'completedAt': 'completed_at',
        'downloadLink': 'download_link',
        'expiresAt': 'expires_at',
        'failureCode': 'failure_code',
        'requestType': 'request_type',
        'snapshotAt': 'snapshot_at',
      },
    );

Map<String, dynamic> _$RequestPrivacyExport202ResponseDataToJson(
  RequestPrivacyExport202ResponseData instance,
) => <String, dynamic>{
  'completed_at': instance.completedAt?.toIso8601String(),
  'download_link': instance.downloadLink?.toJson(),
  'expires_at': instance.expiresAt?.toIso8601String(),
  'failure_code': instance.failureCode,
  'format':
      _$RequestPrivacyExport202ResponseDataFormatEnumEnumMap[instance.format]!,
  'id': instance.id,
  'request_type':
      _$RequestPrivacyExport202ResponseDataRequestTypeEnumEnumMap[instance
          .requestType]!,
  'snapshot_at': instance.snapshotAt?.toIso8601String(),
  'status':
      _$RequestPrivacyExport202ResponseDataStatusEnumEnumMap[instance.status]!,
};

const _$RequestPrivacyExport202ResponseDataFormatEnumEnumMap = {
  RequestPrivacyExport202ResponseDataFormatEnum.zip: 'zip',
  RequestPrivacyExport202ResponseDataFormatEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$RequestPrivacyExport202ResponseDataRequestTypeEnumEnumMap = {
  RequestPrivacyExport202ResponseDataRequestTypeEnum.export_: 'export',
  RequestPrivacyExport202ResponseDataRequestTypeEnum.delete: 'delete',
  RequestPrivacyExport202ResponseDataRequestTypeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$RequestPrivacyExport202ResponseDataStatusEnumEnumMap = {
  RequestPrivacyExport202ResponseDataStatusEnum.requested: 'requested',
  RequestPrivacyExport202ResponseDataStatusEnum.verified: 'verified',
  RequestPrivacyExport202ResponseDataStatusEnum.queued: 'queued',
  RequestPrivacyExport202ResponseDataStatusEnum.processing: 'processing',
  RequestPrivacyExport202ResponseDataStatusEnum.completed: 'completed',
  RequestPrivacyExport202ResponseDataStatusEnum.failed: 'failed',
  RequestPrivacyExport202ResponseDataStatusEnum.cancelled: 'cancelled',
  RequestPrivacyExport202ResponseDataStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
