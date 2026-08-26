// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_account_deletion202_response_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RequestAccountDeletion202ResponseDataCWProxy {
  RequestAccountDeletion202ResponseData effectiveAt(DateTime effectiveAt);

  RequestAccountDeletion202ResponseData purgeBy(DateTime purgeBy);

  RequestAccountDeletion202ResponseData purgeGeneration(int purgeGeneration);

  RequestAccountDeletion202ResponseData requestId(String requestId);

  RequestAccountDeletion202ResponseData status(
    RequestAccountDeletion202ResponseDataStatusEnum status,
  );

  RequestAccountDeletion202ResponseData tombstoneId(String tombstoneId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestAccountDeletion202ResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestAccountDeletion202ResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestAccountDeletion202ResponseData call({
    DateTime effectiveAt,
    DateTime purgeBy,
    int purgeGeneration,
    String requestId,
    RequestAccountDeletion202ResponseDataStatusEnum status,
    String tombstoneId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRequestAccountDeletion202ResponseData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRequestAccountDeletion202ResponseData.copyWith.fieldName(...)`
class _$RequestAccountDeletion202ResponseDataCWProxyImpl
    implements _$RequestAccountDeletion202ResponseDataCWProxy {
  const _$RequestAccountDeletion202ResponseDataCWProxyImpl(this._value);

  final RequestAccountDeletion202ResponseData _value;

  @override
  RequestAccountDeletion202ResponseData effectiveAt(DateTime effectiveAt) =>
      this(effectiveAt: effectiveAt);

  @override
  RequestAccountDeletion202ResponseData purgeBy(DateTime purgeBy) =>
      this(purgeBy: purgeBy);

  @override
  RequestAccountDeletion202ResponseData purgeGeneration(int purgeGeneration) =>
      this(purgeGeneration: purgeGeneration);

  @override
  RequestAccountDeletion202ResponseData requestId(String requestId) =>
      this(requestId: requestId);

  @override
  RequestAccountDeletion202ResponseData status(
    RequestAccountDeletion202ResponseDataStatusEnum status,
  ) => this(status: status);

  @override
  RequestAccountDeletion202ResponseData tombstoneId(String tombstoneId) =>
      this(tombstoneId: tombstoneId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestAccountDeletion202ResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestAccountDeletion202ResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestAccountDeletion202ResponseData call({
    Object? effectiveAt = const $CopyWithPlaceholder(),
    Object? purgeBy = const $CopyWithPlaceholder(),
    Object? purgeGeneration = const $CopyWithPlaceholder(),
    Object? requestId = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? tombstoneId = const $CopyWithPlaceholder(),
  }) {
    return RequestAccountDeletion202ResponseData(
      effectiveAt: effectiveAt == const $CopyWithPlaceholder()
          ? _value.effectiveAt
          // ignore: cast_nullable_to_non_nullable
          : effectiveAt as DateTime,
      purgeBy: purgeBy == const $CopyWithPlaceholder()
          ? _value.purgeBy
          // ignore: cast_nullable_to_non_nullable
          : purgeBy as DateTime,
      purgeGeneration: purgeGeneration == const $CopyWithPlaceholder()
          ? _value.purgeGeneration
          // ignore: cast_nullable_to_non_nullable
          : purgeGeneration as int,
      requestId: requestId == const $CopyWithPlaceholder()
          ? _value.requestId
          // ignore: cast_nullable_to_non_nullable
          : requestId as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as RequestAccountDeletion202ResponseDataStatusEnum,
      tombstoneId: tombstoneId == const $CopyWithPlaceholder()
          ? _value.tombstoneId
          // ignore: cast_nullable_to_non_nullable
          : tombstoneId as String,
    );
  }
}

extension $RequestAccountDeletion202ResponseDataCopyWith
    on RequestAccountDeletion202ResponseData {
  /// Returns a callable class that can be used as follows: `instanceOfRequestAccountDeletion202ResponseData.copyWith(...)` or like so:`instanceOfRequestAccountDeletion202ResponseData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RequestAccountDeletion202ResponseDataCWProxy get copyWith =>
      _$RequestAccountDeletion202ResponseDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestAccountDeletion202ResponseData
_$RequestAccountDeletion202ResponseDataFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'RequestAccountDeletion202ResponseData',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'effective_at',
            'purge_by',
            'purge_generation',
            'request_id',
            'status',
            'tombstone_id',
          ],
        );
        final val = RequestAccountDeletion202ResponseData(
          effectiveAt: $checkedConvert(
            'effective_at',
            (v) => DateTime.parse(v as String),
          ),
          purgeBy: $checkedConvert(
            'purge_by',
            (v) => DateTime.parse(v as String),
          ),
          purgeGeneration: $checkedConvert(
            'purge_generation',
            (v) => (v as num).toInt(),
          ),
          requestId: $checkedConvert('request_id', (v) => v as String),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$RequestAccountDeletion202ResponseDataStatusEnumEnumMap,
              v,
              unknownValue: RequestAccountDeletion202ResponseDataStatusEnum
                  .unknownDefaultOpenApi,
            ),
          ),
          tombstoneId: $checkedConvert('tombstone_id', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'effectiveAt': 'effective_at',
        'purgeBy': 'purge_by',
        'purgeGeneration': 'purge_generation',
        'requestId': 'request_id',
        'tombstoneId': 'tombstone_id',
      },
    );

Map<String, dynamic> _$RequestAccountDeletion202ResponseDataToJson(
  RequestAccountDeletion202ResponseData instance,
) => <String, dynamic>{
  'effective_at': instance.effectiveAt.toIso8601String(),
  'purge_by': instance.purgeBy.toIso8601String(),
  'purge_generation': instance.purgeGeneration,
  'request_id': instance.requestId,
  'status':
      _$RequestAccountDeletion202ResponseDataStatusEnumEnumMap[instance
          .status]!,
  'tombstone_id': instance.tombstoneId,
};

const _$RequestAccountDeletion202ResponseDataStatusEnumEnumMap = {
  RequestAccountDeletion202ResponseDataStatusEnum.queued: 'queued',
  RequestAccountDeletion202ResponseDataStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
