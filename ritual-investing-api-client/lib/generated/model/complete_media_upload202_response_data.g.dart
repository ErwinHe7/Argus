// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'complete_media_upload202_response_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CompleteMediaUpload202ResponseDataCWProxy {
  CompleteMediaUpload202ResponseData mediaId(String mediaId);

  CompleteMediaUpload202ResponseData outboxId(String outboxId);

  CompleteMediaUpload202ResponseData status(
    CompleteMediaUpload202ResponseDataStatusEnum status,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CompleteMediaUpload202ResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CompleteMediaUpload202ResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  CompleteMediaUpload202ResponseData call({
    String mediaId,
    String outboxId,
    CompleteMediaUpload202ResponseDataStatusEnum status,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCompleteMediaUpload202ResponseData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCompleteMediaUpload202ResponseData.copyWith.fieldName(...)`
class _$CompleteMediaUpload202ResponseDataCWProxyImpl
    implements _$CompleteMediaUpload202ResponseDataCWProxy {
  const _$CompleteMediaUpload202ResponseDataCWProxyImpl(this._value);

  final CompleteMediaUpload202ResponseData _value;

  @override
  CompleteMediaUpload202ResponseData mediaId(String mediaId) =>
      this(mediaId: mediaId);

  @override
  CompleteMediaUpload202ResponseData outboxId(String outboxId) =>
      this(outboxId: outboxId);

  @override
  CompleteMediaUpload202ResponseData status(
    CompleteMediaUpload202ResponseDataStatusEnum status,
  ) => this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CompleteMediaUpload202ResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CompleteMediaUpload202ResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  CompleteMediaUpload202ResponseData call({
    Object? mediaId = const $CopyWithPlaceholder(),
    Object? outboxId = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return CompleteMediaUpload202ResponseData(
      mediaId: mediaId == const $CopyWithPlaceholder()
          ? _value.mediaId
          // ignore: cast_nullable_to_non_nullable
          : mediaId as String,
      outboxId: outboxId == const $CopyWithPlaceholder()
          ? _value.outboxId
          // ignore: cast_nullable_to_non_nullable
          : outboxId as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as CompleteMediaUpload202ResponseDataStatusEnum,
    );
  }
}

extension $CompleteMediaUpload202ResponseDataCopyWith
    on CompleteMediaUpload202ResponseData {
  /// Returns a callable class that can be used as follows: `instanceOfCompleteMediaUpload202ResponseData.copyWith(...)` or like so:`instanceOfCompleteMediaUpload202ResponseData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CompleteMediaUpload202ResponseDataCWProxy get copyWith =>
      _$CompleteMediaUpload202ResponseDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CompleteMediaUpload202ResponseData _$CompleteMediaUpload202ResponseDataFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CompleteMediaUpload202ResponseData', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['media_id', 'outbox_id', 'status']);
  final val = CompleteMediaUpload202ResponseData(
    mediaId: $checkedConvert('media_id', (v) => v as String),
    outboxId: $checkedConvert('outbox_id', (v) => v as String),
    status: $checkedConvert(
      'status',
      (v) => $enumDecode(
        _$CompleteMediaUpload202ResponseDataStatusEnumEnumMap,
        v,
        unknownValue:
            CompleteMediaUpload202ResponseDataStatusEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
}, fieldKeyMap: const {'mediaId': 'media_id', 'outboxId': 'outbox_id'});

Map<String, dynamic> _$CompleteMediaUpload202ResponseDataToJson(
  CompleteMediaUpload202ResponseData instance,
) => <String, dynamic>{
  'media_id': instance.mediaId,
  'outbox_id': instance.outboxId,
  'status':
      _$CompleteMediaUpload202ResponseDataStatusEnumEnumMap[instance.status]!,
};

const _$CompleteMediaUpload202ResponseDataStatusEnumEnumMap = {
  CompleteMediaUpload202ResponseDataStatusEnum.scanning: 'scanning',
  CompleteMediaUpload202ResponseDataStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
