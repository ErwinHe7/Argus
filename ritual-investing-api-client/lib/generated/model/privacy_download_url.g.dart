// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'privacy_download_url.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PrivacyDownloadUrlCWProxy {
  PrivacyDownloadUrl expiresAt(DateTime expiresAt);

  PrivacyDownloadUrl url(String url);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PrivacyDownloadUrl(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PrivacyDownloadUrl(...).copyWith(id: 12, name: "My name")
  /// ````
  PrivacyDownloadUrl call({DateTime expiresAt, String url});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPrivacyDownloadUrl.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPrivacyDownloadUrl.copyWith.fieldName(...)`
class _$PrivacyDownloadUrlCWProxyImpl implements _$PrivacyDownloadUrlCWProxy {
  const _$PrivacyDownloadUrlCWProxyImpl(this._value);

  final PrivacyDownloadUrl _value;

  @override
  PrivacyDownloadUrl expiresAt(DateTime expiresAt) =>
      this(expiresAt: expiresAt);

  @override
  PrivacyDownloadUrl url(String url) => this(url: url);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PrivacyDownloadUrl(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PrivacyDownloadUrl(...).copyWith(id: 12, name: "My name")
  /// ````
  PrivacyDownloadUrl call({
    Object? expiresAt = const $CopyWithPlaceholder(),
    Object? url = const $CopyWithPlaceholder(),
  }) {
    return PrivacyDownloadUrl(
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

extension $PrivacyDownloadUrlCopyWith on PrivacyDownloadUrl {
  /// Returns a callable class that can be used as follows: `instanceOfPrivacyDownloadUrl.copyWith(...)` or like so:`instanceOfPrivacyDownloadUrl.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PrivacyDownloadUrlCWProxy get copyWith =>
      _$PrivacyDownloadUrlCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrivacyDownloadUrl _$PrivacyDownloadUrlFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PrivacyDownloadUrl', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['expires_at', 'url']);
      final val = PrivacyDownloadUrl(
        expiresAt: $checkedConvert(
          'expires_at',
          (v) => DateTime.parse(v as String),
        ),
        url: $checkedConvert('url', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'expiresAt': 'expires_at'});

Map<String, dynamic> _$PrivacyDownloadUrlToJson(PrivacyDownloadUrl instance) =>
    <String, dynamic>{
      'expires_at': instance.expiresAt.toIso8601String(),
      'url': instance.url,
    };
