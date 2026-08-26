// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_media_upload201_response_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RequestMediaUpload201ResponseDataCWProxy {
  RequestMediaUpload201ResponseData expiresAt(DateTime expiresAt);

  RequestMediaUpload201ResponseData mediaId(String mediaId);

  RequestMediaUpload201ResponseData quarantineKey(String quarantineKey);

  RequestMediaUpload201ResponseData uploadUrl(String uploadUrl);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestMediaUpload201ResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestMediaUpload201ResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestMediaUpload201ResponseData call({
    DateTime expiresAt,
    String mediaId,
    String quarantineKey,
    String uploadUrl,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRequestMediaUpload201ResponseData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRequestMediaUpload201ResponseData.copyWith.fieldName(...)`
class _$RequestMediaUpload201ResponseDataCWProxyImpl
    implements _$RequestMediaUpload201ResponseDataCWProxy {
  const _$RequestMediaUpload201ResponseDataCWProxyImpl(this._value);

  final RequestMediaUpload201ResponseData _value;

  @override
  RequestMediaUpload201ResponseData expiresAt(DateTime expiresAt) =>
      this(expiresAt: expiresAt);

  @override
  RequestMediaUpload201ResponseData mediaId(String mediaId) =>
      this(mediaId: mediaId);

  @override
  RequestMediaUpload201ResponseData quarantineKey(String quarantineKey) =>
      this(quarantineKey: quarantineKey);

  @override
  RequestMediaUpload201ResponseData uploadUrl(String uploadUrl) =>
      this(uploadUrl: uploadUrl);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestMediaUpload201ResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestMediaUpload201ResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestMediaUpload201ResponseData call({
    Object? expiresAt = const $CopyWithPlaceholder(),
    Object? mediaId = const $CopyWithPlaceholder(),
    Object? quarantineKey = const $CopyWithPlaceholder(),
    Object? uploadUrl = const $CopyWithPlaceholder(),
  }) {
    return RequestMediaUpload201ResponseData(
      expiresAt: expiresAt == const $CopyWithPlaceholder()
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime,
      mediaId: mediaId == const $CopyWithPlaceholder()
          ? _value.mediaId
          // ignore: cast_nullable_to_non_nullable
          : mediaId as String,
      quarantineKey: quarantineKey == const $CopyWithPlaceholder()
          ? _value.quarantineKey
          // ignore: cast_nullable_to_non_nullable
          : quarantineKey as String,
      uploadUrl: uploadUrl == const $CopyWithPlaceholder()
          ? _value.uploadUrl
          // ignore: cast_nullable_to_non_nullable
          : uploadUrl as String,
    );
  }
}

extension $RequestMediaUpload201ResponseDataCopyWith
    on RequestMediaUpload201ResponseData {
  /// Returns a callable class that can be used as follows: `instanceOfRequestMediaUpload201ResponseData.copyWith(...)` or like so:`instanceOfRequestMediaUpload201ResponseData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RequestMediaUpload201ResponseDataCWProxy get copyWith =>
      _$RequestMediaUpload201ResponseDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestMediaUpload201ResponseData _$RequestMediaUpload201ResponseDataFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'RequestMediaUpload201ResponseData',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'expires_at',
        'media_id',
        'quarantine_key',
        'upload_url',
      ],
    );
    final val = RequestMediaUpload201ResponseData(
      expiresAt: $checkedConvert(
        'expires_at',
        (v) => DateTime.parse(v as String),
      ),
      mediaId: $checkedConvert('media_id', (v) => v as String),
      quarantineKey: $checkedConvert('quarantine_key', (v) => v as String),
      uploadUrl: $checkedConvert('upload_url', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'expiresAt': 'expires_at',
    'mediaId': 'media_id',
    'quarantineKey': 'quarantine_key',
    'uploadUrl': 'upload_url',
  },
);

Map<String, dynamic> _$RequestMediaUpload201ResponseDataToJson(
  RequestMediaUpload201ResponseData instance,
) => <String, dynamic>{
  'expires_at': instance.expiresAt.toIso8601String(),
  'media_id': instance.mediaId,
  'quarantine_key': instance.quarantineKey,
  'upload_url': instance.uploadUrl,
};
