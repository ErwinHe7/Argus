// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_privacy_download_url200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreatePrivacyDownloadUrl200ResponseCWProxy {
  CreatePrivacyDownloadUrl200Response expiresAt(DateTime expiresAt);

  CreatePrivacyDownloadUrl200Response url(String url);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreatePrivacyDownloadUrl200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreatePrivacyDownloadUrl200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreatePrivacyDownloadUrl200Response call({DateTime expiresAt, String url});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreatePrivacyDownloadUrl200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreatePrivacyDownloadUrl200Response.copyWith.fieldName(...)`
class _$CreatePrivacyDownloadUrl200ResponseCWProxyImpl
    implements _$CreatePrivacyDownloadUrl200ResponseCWProxy {
  const _$CreatePrivacyDownloadUrl200ResponseCWProxyImpl(this._value);

  final CreatePrivacyDownloadUrl200Response _value;

  @override
  CreatePrivacyDownloadUrl200Response expiresAt(DateTime expiresAt) =>
      this(expiresAt: expiresAt);

  @override
  CreatePrivacyDownloadUrl200Response url(String url) => this(url: url);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreatePrivacyDownloadUrl200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreatePrivacyDownloadUrl200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreatePrivacyDownloadUrl200Response call({
    Object? expiresAt = const $CopyWithPlaceholder(),
    Object? url = const $CopyWithPlaceholder(),
  }) {
    return CreatePrivacyDownloadUrl200Response(
      expiresAt: expiresAt == const $CopyWithPlaceholder()
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime,
      url: url == const $CopyWithPlaceholder()
          ? _value.url
          // ignore: cast_nullable_to_non_nullable
          : url as String,
    );
  }
}

extension $CreatePrivacyDownloadUrl200ResponseCopyWith
    on CreatePrivacyDownloadUrl200Response {
  /// Returns a callable class that can be used as follows: `instanceOfCreatePrivacyDownloadUrl200Response.copyWith(...)` or like so:`instanceOfCreatePrivacyDownloadUrl200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreatePrivacyDownloadUrl200ResponseCWProxy get copyWith =>
      _$CreatePrivacyDownloadUrl200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreatePrivacyDownloadUrl200Response
_$CreatePrivacyDownloadUrl200ResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CreatePrivacyDownloadUrl200Response', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['expires_at', 'url']);
      final val = CreatePrivacyDownloadUrl200Response(
        expiresAt: $checkedConvert(
          'expires_at',
          (v) => DateTime.parse(v as String),
        ),
        url: $checkedConvert('url', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'expiresAt': 'expires_at'});

Map<String, dynamic> _$CreatePrivacyDownloadUrl200ResponseToJson(
  CreatePrivacyDownloadUrl200Response instance,
) => <String, dynamic>{
  'expires_at': instance.expiresAt.toIso8601String(),
  'url': instance.url,
};
