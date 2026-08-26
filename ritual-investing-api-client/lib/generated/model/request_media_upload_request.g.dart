// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_media_upload_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RequestMediaUploadRequestCWProxy {
  RequestMediaUploadRequest byteSize(int byteSize);

  RequestMediaUploadRequest checksum(String checksum);

  RequestMediaUploadRequest mimeType(
    RequestMediaUploadRequestMimeTypeEnum mimeType,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestMediaUploadRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestMediaUploadRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestMediaUploadRequest call({
    int byteSize,
    String checksum,
    RequestMediaUploadRequestMimeTypeEnum mimeType,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRequestMediaUploadRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRequestMediaUploadRequest.copyWith.fieldName(...)`
class _$RequestMediaUploadRequestCWProxyImpl
    implements _$RequestMediaUploadRequestCWProxy {
  const _$RequestMediaUploadRequestCWProxyImpl(this._value);

  final RequestMediaUploadRequest _value;

  @override
  RequestMediaUploadRequest byteSize(int byteSize) => this(byteSize: byteSize);

  @override
  RequestMediaUploadRequest checksum(String checksum) =>
      this(checksum: checksum);

  @override
  RequestMediaUploadRequest mimeType(
    RequestMediaUploadRequestMimeTypeEnum mimeType,
  ) => this(mimeType: mimeType);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestMediaUploadRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestMediaUploadRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestMediaUploadRequest call({
    Object? byteSize = const $CopyWithPlaceholder(),
    Object? checksum = const $CopyWithPlaceholder(),
    Object? mimeType = const $CopyWithPlaceholder(),
  }) {
    return RequestMediaUploadRequest(
      byteSize: byteSize == const $CopyWithPlaceholder()
          ? _value.byteSize
          // ignore: cast_nullable_to_non_nullable
          : byteSize as int,
      checksum: checksum == const $CopyWithPlaceholder()
          ? _value.checksum
          // ignore: cast_nullable_to_non_nullable
          : checksum as String,
      mimeType: mimeType == const $CopyWithPlaceholder()
          ? _value.mimeType
          // ignore: cast_nullable_to_non_nullable
          : mimeType as RequestMediaUploadRequestMimeTypeEnum,
    );
  }
}

extension $RequestMediaUploadRequestCopyWith on RequestMediaUploadRequest {
  /// Returns a callable class that can be used as follows: `instanceOfRequestMediaUploadRequest.copyWith(...)` or like so:`instanceOfRequestMediaUploadRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RequestMediaUploadRequestCWProxy get copyWith =>
      _$RequestMediaUploadRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestMediaUploadRequest _$RequestMediaUploadRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('RequestMediaUploadRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['byte_size', 'checksum', 'mime_type']);
  final val = RequestMediaUploadRequest(
    byteSize: $checkedConvert('byte_size', (v) => (v as num).toInt()),
    checksum: $checkedConvert('checksum', (v) => v as String),
    mimeType: $checkedConvert(
      'mime_type',
      (v) => $enumDecode(
        _$RequestMediaUploadRequestMimeTypeEnumEnumMap,
        v,
        unknownValue:
            RequestMediaUploadRequestMimeTypeEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
}, fieldKeyMap: const {'byteSize': 'byte_size', 'mimeType': 'mime_type'});

Map<String, dynamic> _$RequestMediaUploadRequestToJson(
  RequestMediaUploadRequest instance,
) => <String, dynamic>{
  'byte_size': instance.byteSize,
  'checksum': instance.checksum,
  'mime_type':
      _$RequestMediaUploadRequestMimeTypeEnumEnumMap[instance.mimeType]!,
};

const _$RequestMediaUploadRequestMimeTypeEnumEnumMap = {
  RequestMediaUploadRequestMimeTypeEnum.imageSlashJpeg: 'image/jpeg',
  RequestMediaUploadRequestMimeTypeEnum.imageSlashPng: 'image/png',
  RequestMediaUploadRequestMimeTypeEnum.imageSlashWebp: 'image/webp',
  RequestMediaUploadRequestMimeTypeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
