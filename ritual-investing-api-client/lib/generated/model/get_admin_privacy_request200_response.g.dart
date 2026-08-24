// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_admin_privacy_request200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GetAdminPrivacyRequest200ResponseCWProxy {
  GetAdminPrivacyRequest200Response data(
    ListAdminPrivacyRequests200ResponseDataInner data,
  );

  GetAdminPrivacyRequest200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetAdminPrivacyRequest200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetAdminPrivacyRequest200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetAdminPrivacyRequest200Response call({
    ListAdminPrivacyRequests200ResponseDataInner data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGetAdminPrivacyRequest200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGetAdminPrivacyRequest200Response.copyWith.fieldName(...)`
class _$GetAdminPrivacyRequest200ResponseCWProxyImpl
    implements _$GetAdminPrivacyRequest200ResponseCWProxy {
  const _$GetAdminPrivacyRequest200ResponseCWProxyImpl(this._value);

  final GetAdminPrivacyRequest200Response _value;

  @override
  GetAdminPrivacyRequest200Response data(
    ListAdminPrivacyRequests200ResponseDataInner data,
  ) => this(data: data);

  @override
  GetAdminPrivacyRequest200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetAdminPrivacyRequest200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetAdminPrivacyRequest200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetAdminPrivacyRequest200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return GetAdminPrivacyRequest200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as ListAdminPrivacyRequests200ResponseDataInner,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $GetAdminPrivacyRequest200ResponseCopyWith
    on GetAdminPrivacyRequest200Response {
  /// Returns a callable class that can be used as follows: `instanceOfGetAdminPrivacyRequest200Response.copyWith(...)` or like so:`instanceOfGetAdminPrivacyRequest200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GetAdminPrivacyRequest200ResponseCWProxy get copyWith =>
      _$GetAdminPrivacyRequest200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetAdminPrivacyRequest200Response _$GetAdminPrivacyRequest200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GetAdminPrivacyRequest200Response', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = GetAdminPrivacyRequest200Response(
    data: $checkedConvert(
      'data',
      (v) => ListAdminPrivacyRequests200ResponseDataInner.fromJson(
        v as Map<String, dynamic>,
      ),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$GetAdminPrivacyRequest200ResponseToJson(
  GetAdminPrivacyRequest200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
