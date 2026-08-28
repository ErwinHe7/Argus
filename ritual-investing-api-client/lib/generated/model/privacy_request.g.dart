// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'privacy_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PrivacyRequestCWProxy {
  PrivacyRequest completedAt(DateTime? completedAt);

  PrivacyRequest deletionEpoch(int? deletionEpoch);

  PrivacyRequest failureCode(String? failureCode);

  PrivacyRequest id(String id);

  PrivacyRequest requestType(PrivacyRequestRequestTypeEnum requestType);

  PrivacyRequest requestedAt(DateTime requestedAt);

  PrivacyRequest status(PrivacyRequestStatusEnum status);

  PrivacyRequest userId(String userId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PrivacyRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PrivacyRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PrivacyRequest call({
    DateTime? completedAt,
    int? deletionEpoch,
    String? failureCode,
    String id,
    PrivacyRequestRequestTypeEnum requestType,
    DateTime requestedAt,
    PrivacyRequestStatusEnum status,
    String userId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPrivacyRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPrivacyRequest.copyWith.fieldName(...)`
class _$PrivacyRequestCWProxyImpl implements _$PrivacyRequestCWProxy {
  const _$PrivacyRequestCWProxyImpl(this._value);

  final PrivacyRequest _value;

  @override
  PrivacyRequest completedAt(DateTime? completedAt) =>
      this(completedAt: completedAt);

  @override
  PrivacyRequest deletionEpoch(int? deletionEpoch) =>
      this(deletionEpoch: deletionEpoch);

  @override
  PrivacyRequest failureCode(String? failureCode) =>
      this(failureCode: failureCode);

  @override
  PrivacyRequest id(String id) => this(id: id);

  @override
  PrivacyRequest requestType(PrivacyRequestRequestTypeEnum requestType) =>
      this(requestType: requestType);

  @override
  PrivacyRequest requestedAt(DateTime requestedAt) =>
      this(requestedAt: requestedAt);

  @override
  PrivacyRequest status(PrivacyRequestStatusEnum status) =>
      this(status: status);

  @override
  PrivacyRequest userId(String userId) => this(userId: userId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PrivacyRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PrivacyRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PrivacyRequest call({
    Object? completedAt = const $CopyWithPlaceholder(),
    Object? deletionEpoch = const $CopyWithPlaceholder(),
    Object? failureCode = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? requestType = const $CopyWithPlaceholder(),
    Object? requestedAt = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? userId = const $CopyWithPlaceholder(),
  }) {
    return PrivacyRequest(
      completedAt: completedAt == const $CopyWithPlaceholder()
          ? _value.completedAt
          // ignore: cast_nullable_to_non_nullable
          : completedAt as DateTime?,
      deletionEpoch: deletionEpoch == const $CopyWithPlaceholder()
          ? _value.deletionEpoch
          // ignore: cast_nullable_to_non_nullable
          : deletionEpoch as int?,
      failureCode: failureCode == const $CopyWithPlaceholder()
          ? _value.failureCode
          // ignore: cast_nullable_to_non_nullable
          : failureCode as String?,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      requestType: requestType == const $CopyWithPlaceholder()
          ? _value.requestType
          // ignore: cast_nullable_to_non_nullable
          : requestType as PrivacyRequestRequestTypeEnum,
      requestedAt: requestedAt == const $CopyWithPlaceholder()
          ? _value.requestedAt
          // ignore: cast_nullable_to_non_nullable
          : requestedAt as DateTime,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as PrivacyRequestStatusEnum,
      userId: userId == const $CopyWithPlaceholder()
          ? _value.userId
          // ignore: cast_nullable_to_non_nullable
          : userId as String,
    );
  }
}

extension $PrivacyRequestCopyWith on PrivacyRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPrivacyRequest.copyWith(...)` or like so:`instanceOfPrivacyRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PrivacyRequestCWProxy get copyWith => _$PrivacyRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrivacyRequest _$PrivacyRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'PrivacyRequest',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'completed_at',
            'deletion_epoch',
            'failure_code',
            'id',
            'request_type',
            'requested_at',
            'status',
            'user_id',
          ],
        );
        final val = PrivacyRequest(
          completedAt: $checkedConvert(
            'completed_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          deletionEpoch: $checkedConvert(
            'deletion_epoch',
            (v) => (v as num?)?.toInt(),
          ),
          failureCode: $checkedConvert('failure_code', (v) => v as String?),
          id: $checkedConvert('id', (v) => v as String),
          requestType: $checkedConvert(
            'request_type',
            (v) => $enumDecode(
              _$PrivacyRequestRequestTypeEnumEnumMap,
              v,
              unknownValue: PrivacyRequestRequestTypeEnum.unknownDefaultOpenApi,
            ),
          ),
          requestedAt: $checkedConvert(
            'requested_at',
            (v) => DateTime.parse(v as String),
          ),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$PrivacyRequestStatusEnumEnumMap,
              v,
              unknownValue: PrivacyRequestStatusEnum.unknownDefaultOpenApi,
            ),
          ),
          userId: $checkedConvert('user_id', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'completedAt': 'completed_at',
        'deletionEpoch': 'deletion_epoch',
        'failureCode': 'failure_code',
        'requestType': 'request_type',
        'requestedAt': 'requested_at',
        'userId': 'user_id',
      },
    );

Map<String, dynamic> _$PrivacyRequestToJson(
  PrivacyRequest instance,
) => <String, dynamic>{
  'completed_at': instance.completedAt?.toIso8601String(),
  'deletion_epoch': instance.deletionEpoch,
  'failure_code': instance.failureCode,
  'id': instance.id,
  'request_type': _$PrivacyRequestRequestTypeEnumEnumMap[instance.requestType]!,
  'requested_at': instance.requestedAt.toIso8601String(),
  'status': _$PrivacyRequestStatusEnumEnumMap[instance.status]!,
  'user_id': instance.userId,
};

const _$PrivacyRequestRequestTypeEnumEnumMap = {
  PrivacyRequestRequestTypeEnum.export_: 'export',
  PrivacyRequestRequestTypeEnum.deletion: 'deletion',
  PrivacyRequestRequestTypeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$PrivacyRequestStatusEnumEnumMap = {
  PrivacyRequestStatusEnum.requested: 'requested',
  PrivacyRequestStatusEnum.verified: 'verified',
  PrivacyRequestStatusEnum.queued: 'queued',
  PrivacyRequestStatusEnum.processing: 'processing',
  PrivacyRequestStatusEnum.completed: 'completed',
  PrivacyRequestStatusEnum.failed: 'failed',
  PrivacyRequestStatusEnum.cancelled: 'cancelled',
  PrivacyRequestStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
