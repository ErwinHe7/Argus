// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'privacy_request_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PrivacyRequestResponseCWProxy {
  PrivacyRequestResponse data(PrivacyRequest data);

  PrivacyRequestResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PrivacyRequestResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PrivacyRequestResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  PrivacyRequestResponse call({
    PrivacyRequest data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPrivacyRequestResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPrivacyRequestResponse.copyWith.fieldName(...)`
class _$PrivacyRequestResponseCWProxyImpl
    implements _$PrivacyRequestResponseCWProxy {
  const _$PrivacyRequestResponseCWProxyImpl(this._value);

  final PrivacyRequestResponse _value;

  @override
  PrivacyRequestResponse data(PrivacyRequest data) => this(data: data);

  @override
  PrivacyRequestResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PrivacyRequestResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PrivacyRequestResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  PrivacyRequestResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return PrivacyRequestResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as PrivacyRequest,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $PrivacyRequestResponseCopyWith on PrivacyRequestResponse {
  /// Returns a callable class that can be used as follows: `instanceOfPrivacyRequestResponse.copyWith(...)` or like so:`instanceOfPrivacyRequestResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PrivacyRequestResponseCWProxy get copyWith =>
      _$PrivacyRequestResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrivacyRequestResponse _$PrivacyRequestResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PrivacyRequestResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = PrivacyRequestResponse(
    data: $checkedConvert(
      'data',
      (v) => PrivacyRequest.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$PrivacyRequestResponseToJson(
  PrivacyRequestResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
