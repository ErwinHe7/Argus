// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_admin_me200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GetAdminMe200ResponseCWProxy {
  GetAdminMe200Response data(AdminMe data);

  GetAdminMe200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetAdminMe200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetAdminMe200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetAdminMe200Response call({AdminMe data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGetAdminMe200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGetAdminMe200Response.copyWith.fieldName(...)`
class _$GetAdminMe200ResponseCWProxyImpl
    implements _$GetAdminMe200ResponseCWProxy {
  const _$GetAdminMe200ResponseCWProxyImpl(this._value);

  final GetAdminMe200Response _value;

  @override
  GetAdminMe200Response data(AdminMe data) => this(data: data);

  @override
  GetAdminMe200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetAdminMe200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetAdminMe200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetAdminMe200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return GetAdminMe200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as AdminMe,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $GetAdminMe200ResponseCopyWith on GetAdminMe200Response {
  /// Returns a callable class that can be used as follows: `instanceOfGetAdminMe200Response.copyWith(...)` or like so:`instanceOfGetAdminMe200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GetAdminMe200ResponseCWProxy get copyWith =>
      _$GetAdminMe200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetAdminMe200Response _$GetAdminMe200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GetAdminMe200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = GetAdminMe200Response(
    data: $checkedConvert(
      'data',
      (v) => AdminMe.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$GetAdminMe200ResponseToJson(
  GetAdminMe200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
