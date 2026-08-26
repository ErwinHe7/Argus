// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_admin_health_ready200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GetAdminHealthReady200ResponseCWProxy {
  GetAdminHealthReady200Response data(AdminHealth data);

  GetAdminHealthReady200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetAdminHealthReady200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetAdminHealthReady200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetAdminHealthReady200Response call({AdminHealth data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGetAdminHealthReady200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGetAdminHealthReady200Response.copyWith.fieldName(...)`
class _$GetAdminHealthReady200ResponseCWProxyImpl
    implements _$GetAdminHealthReady200ResponseCWProxy {
  const _$GetAdminHealthReady200ResponseCWProxyImpl(this._value);

  final GetAdminHealthReady200Response _value;

  @override
  GetAdminHealthReady200Response data(AdminHealth data) => this(data: data);

  @override
  GetAdminHealthReady200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetAdminHealthReady200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetAdminHealthReady200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetAdminHealthReady200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return GetAdminHealthReady200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as AdminHealth,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $GetAdminHealthReady200ResponseCopyWith
    on GetAdminHealthReady200Response {
  /// Returns a callable class that can be used as follows: `instanceOfGetAdminHealthReady200Response.copyWith(...)` or like so:`instanceOfGetAdminHealthReady200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GetAdminHealthReady200ResponseCWProxy get copyWith =>
      _$GetAdminHealthReady200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetAdminHealthReady200Response _$GetAdminHealthReady200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GetAdminHealthReady200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = GetAdminHealthReady200Response(
    data: $checkedConvert(
      'data',
      (v) => AdminHealth.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$GetAdminHealthReady200ResponseToJson(
  GetAdminHealthReady200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
