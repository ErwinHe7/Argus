// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_privacy_export202_response_data_download_link.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RequestPrivacyExport202ResponseDataDownloadLinkCWProxy {
  RequestPrivacyExport202ResponseDataDownloadLink expiresAt(DateTime expiresAt);

  RequestPrivacyExport202ResponseDataDownloadLink url(String url);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestPrivacyExport202ResponseDataDownloadLink(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestPrivacyExport202ResponseDataDownloadLink(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestPrivacyExport202ResponseDataDownloadLink call({
    DateTime expiresAt,
    String url,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRequestPrivacyExport202ResponseDataDownloadLink.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRequestPrivacyExport202ResponseDataDownloadLink.copyWith.fieldName(...)`
class _$RequestPrivacyExport202ResponseDataDownloadLinkCWProxyImpl
    implements _$RequestPrivacyExport202ResponseDataDownloadLinkCWProxy {
  const _$RequestPrivacyExport202ResponseDataDownloadLinkCWProxyImpl(
    this._value,
  );

  final RequestPrivacyExport202ResponseDataDownloadLink _value;

  @override
  RequestPrivacyExport202ResponseDataDownloadLink expiresAt(
    DateTime expiresAt,
  ) => this(expiresAt: expiresAt);

  @override
  RequestPrivacyExport202ResponseDataDownloadLink url(String url) =>
      this(url: url);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestPrivacyExport202ResponseDataDownloadLink(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestPrivacyExport202ResponseDataDownloadLink(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestPrivacyExport202ResponseDataDownloadLink call({
    Object? expiresAt = const $CopyWithPlaceholder(),
    Object? url = const $CopyWithPlaceholder(),
  }) {
    return RequestPrivacyExport202ResponseDataDownloadLink(
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

extension $RequestPrivacyExport202ResponseDataDownloadLinkCopyWith
    on RequestPrivacyExport202ResponseDataDownloadLink {
  /// Returns a callable class that can be used as follows: `instanceOfRequestPrivacyExport202ResponseDataDownloadLink.copyWith(...)` or like so:`instanceOfRequestPrivacyExport202ResponseDataDownloadLink.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RequestPrivacyExport202ResponseDataDownloadLinkCWProxy get copyWith =>
      _$RequestPrivacyExport202ResponseDataDownloadLinkCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestPrivacyExport202ResponseDataDownloadLink
_$RequestPrivacyExport202ResponseDataDownloadLinkFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('RequestPrivacyExport202ResponseDataDownloadLink', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['expires_at', 'url']);
  final val = RequestPrivacyExport202ResponseDataDownloadLink(
    expiresAt: $checkedConvert(
      'expires_at',
      (v) => DateTime.parse(v as String),
    ),
    url: $checkedConvert('url', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'expiresAt': 'expires_at'});

Map<String, dynamic> _$RequestPrivacyExport202ResponseDataDownloadLinkToJson(
  RequestPrivacyExport202ResponseDataDownloadLink instance,
) => <String, dynamic>{
  'expires_at': instance.expiresAt.toIso8601String(),
  'url': instance.url,
};
