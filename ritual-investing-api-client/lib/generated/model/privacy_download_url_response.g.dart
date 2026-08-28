// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'privacy_download_url_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PrivacyDownloadUrlResponseCWProxy {
  PrivacyDownloadUrlResponse data(PrivacyDownloadUrl data);

  PrivacyDownloadUrlResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PrivacyDownloadUrlResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PrivacyDownloadUrlResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  PrivacyDownloadUrlResponse call({
    PrivacyDownloadUrl data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPrivacyDownloadUrlResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPrivacyDownloadUrlResponse.copyWith.fieldName(...)`
class _$PrivacyDownloadUrlResponseCWProxyImpl
    implements _$PrivacyDownloadUrlResponseCWProxy {
  const _$PrivacyDownloadUrlResponseCWProxyImpl(this._value);

  final PrivacyDownloadUrlResponse _value;

  @override
  PrivacyDownloadUrlResponse data(PrivacyDownloadUrl data) => this(data: data);

  @override
  PrivacyDownloadUrlResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PrivacyDownloadUrlResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PrivacyDownloadUrlResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  PrivacyDownloadUrlResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return PrivacyDownloadUrlResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as PrivacyDownloadUrl,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $PrivacyDownloadUrlResponseCopyWith on PrivacyDownloadUrlResponse {
  /// Returns a callable class that can be used as follows: `instanceOfPrivacyDownloadUrlResponse.copyWith(...)` or like so:`instanceOfPrivacyDownloadUrlResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PrivacyDownloadUrlResponseCWProxy get copyWith =>
      _$PrivacyDownloadUrlResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrivacyDownloadUrlResponse _$PrivacyDownloadUrlResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PrivacyDownloadUrlResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = PrivacyDownloadUrlResponse(
    data: $checkedConvert(
      'data',
      (v) => PrivacyDownloadUrl.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$PrivacyDownloadUrlResponseToJson(
  PrivacyDownloadUrlResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
