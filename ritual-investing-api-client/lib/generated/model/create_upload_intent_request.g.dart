// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_upload_intent_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateUploadIntentRequestCWProxy {
  CreateUploadIntentRequest bucketId(
    CreateUploadIntentRequestBucketIdEnum bucketId,
  );

  CreateUploadIntentRequest expiresAt(DateTime? expiresAt);

  CreateUploadIntentRequest maxBytes(int maxBytes);

  CreateUploadIntentRequest mimeType(
    CreateUploadIntentRequestMimeTypeEnum mimeType,
  );

  CreateUploadIntentRequest objectPath(String objectPath);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateUploadIntentRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateUploadIntentRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateUploadIntentRequest call({
    CreateUploadIntentRequestBucketIdEnum bucketId,
    DateTime? expiresAt,
    int maxBytes,
    CreateUploadIntentRequestMimeTypeEnum mimeType,
    String objectPath,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateUploadIntentRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateUploadIntentRequest.copyWith.fieldName(...)`
class _$CreateUploadIntentRequestCWProxyImpl
    implements _$CreateUploadIntentRequestCWProxy {
  const _$CreateUploadIntentRequestCWProxyImpl(this._value);

  final CreateUploadIntentRequest _value;

  @override
  CreateUploadIntentRequest bucketId(
    CreateUploadIntentRequestBucketIdEnum bucketId,
  ) => this(bucketId: bucketId);

  @override
  CreateUploadIntentRequest expiresAt(DateTime? expiresAt) =>
      this(expiresAt: expiresAt);

  @override
  CreateUploadIntentRequest maxBytes(int maxBytes) => this(maxBytes: maxBytes);

  @override
  CreateUploadIntentRequest mimeType(
    CreateUploadIntentRequestMimeTypeEnum mimeType,
  ) => this(mimeType: mimeType);

  @override
  CreateUploadIntentRequest objectPath(String objectPath) =>
      this(objectPath: objectPath);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateUploadIntentRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateUploadIntentRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateUploadIntentRequest call({
    Object? bucketId = const $CopyWithPlaceholder(),
    Object? expiresAt = const $CopyWithPlaceholder(),
    Object? maxBytes = const $CopyWithPlaceholder(),
    Object? mimeType = const $CopyWithPlaceholder(),
    Object? objectPath = const $CopyWithPlaceholder(),
  }) {
    return CreateUploadIntentRequest(
      bucketId: bucketId == const $CopyWithPlaceholder()
          ? _value.bucketId
          // ignore: cast_nullable_to_non_nullable
          : bucketId as CreateUploadIntentRequestBucketIdEnum,
      expiresAt: expiresAt == const $CopyWithPlaceholder()
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime?,
      maxBytes: maxBytes == const $CopyWithPlaceholder()
          ? _value.maxBytes
          // ignore: cast_nullable_to_non_nullable
          : maxBytes as int,
      mimeType: mimeType == const $CopyWithPlaceholder()
          ? _value.mimeType
          // ignore: cast_nullable_to_non_nullable
          : mimeType as CreateUploadIntentRequestMimeTypeEnum,
      objectPath: objectPath == const $CopyWithPlaceholder()
          ? _value.objectPath
          // ignore: cast_nullable_to_non_nullable
          : objectPath as String,
    );
  }
}

extension $CreateUploadIntentRequestCopyWith on CreateUploadIntentRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateUploadIntentRequest.copyWith(...)` or like so:`instanceOfCreateUploadIntentRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateUploadIntentRequestCWProxy get copyWith =>
      _$CreateUploadIntentRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateUploadIntentRequest _$CreateUploadIntentRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateUploadIntentRequest', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'bucketId',
      'expiresAt',
      'maxBytes',
      'mimeType',
      'objectPath',
    ],
  );
  final val = CreateUploadIntentRequest(
    bucketId: $checkedConvert(
      'bucketId',
      (v) => $enumDecode(
        _$CreateUploadIntentRequestBucketIdEnumEnumMap,
        v,
        unknownValue:
            CreateUploadIntentRequestBucketIdEnum.unknownDefaultOpenApi,
      ),
    ),
    expiresAt: $checkedConvert(
      'expiresAt',
      (v) => v == null ? null : DateTime.parse(v as String),
    ),
    maxBytes: $checkedConvert('maxBytes', (v) => (v as num).toInt()),
    mimeType: $checkedConvert(
      'mimeType',
      (v) => $enumDecode(
        _$CreateUploadIntentRequestMimeTypeEnumEnumMap,
        v,
        unknownValue:
            CreateUploadIntentRequestMimeTypeEnum.unknownDefaultOpenApi,
      ),
    ),
    objectPath: $checkedConvert('objectPath', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$CreateUploadIntentRequestToJson(
  CreateUploadIntentRequest instance,
) => <String, dynamic>{
  'bucketId':
      _$CreateUploadIntentRequestBucketIdEnumEnumMap[instance.bucketId]!,
  'expiresAt': instance.expiresAt?.toIso8601String(),
  'maxBytes': instance.maxBytes,
  'mimeType':
      _$CreateUploadIntentRequestMimeTypeEnumEnumMap[instance.mimeType]!,
  'objectPath': instance.objectPath,
};

const _$CreateUploadIntentRequestBucketIdEnumEnumMap = {
  CreateUploadIntentRequestBucketIdEnum.memberMedia: 'member-media',
  CreateUploadIntentRequestBucketIdEnum.mediaQuarantine: 'media-quarantine',
  CreateUploadIntentRequestBucketIdEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$CreateUploadIntentRequestMimeTypeEnumEnumMap = {
  CreateUploadIntentRequestMimeTypeEnum.imageSlashJpeg: 'image/jpeg',
  CreateUploadIntentRequestMimeTypeEnum.imageSlashPng: 'image/png',
  CreateUploadIntentRequestMimeTypeEnum.imageSlashWebp: 'image/webp',
  CreateUploadIntentRequestMimeTypeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
