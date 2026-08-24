// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_admin_media200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GetAdminMedia200ResponseCWProxy {
  GetAdminMedia200Response data(ListAdminMedia200ResponseDataInner data);

  GetAdminMedia200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetAdminMedia200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetAdminMedia200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetAdminMedia200Response call({
    ListAdminMedia200ResponseDataInner data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGetAdminMedia200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGetAdminMedia200Response.copyWith.fieldName(...)`
class _$GetAdminMedia200ResponseCWProxyImpl
    implements _$GetAdminMedia200ResponseCWProxy {
  const _$GetAdminMedia200ResponseCWProxyImpl(this._value);

  final GetAdminMedia200Response _value;

  @override
  GetAdminMedia200Response data(ListAdminMedia200ResponseDataInner data) =>
      this(data: data);

  @override
  GetAdminMedia200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetAdminMedia200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetAdminMedia200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetAdminMedia200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return GetAdminMedia200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as ListAdminMedia200ResponseDataInner,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $GetAdminMedia200ResponseCopyWith on GetAdminMedia200Response {
  /// Returns a callable class that can be used as follows: `instanceOfGetAdminMedia200Response.copyWith(...)` or like so:`instanceOfGetAdminMedia200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GetAdminMedia200ResponseCWProxy get copyWith =>
      _$GetAdminMedia200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetAdminMedia200Response _$GetAdminMedia200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GetAdminMedia200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = GetAdminMedia200Response(
    data: $checkedConvert(
      'data',
      (v) => ListAdminMedia200ResponseDataInner.fromJson(
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

Map<String, dynamic> _$GetAdminMedia200ResponseToJson(
  GetAdminMedia200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
