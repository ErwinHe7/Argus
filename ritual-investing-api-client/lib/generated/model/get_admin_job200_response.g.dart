// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_admin_job200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GetAdminJob200ResponseCWProxy {
  GetAdminJob200Response data(ListAdminJobs200ResponseDataInner data);

  GetAdminJob200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetAdminJob200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetAdminJob200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetAdminJob200Response call({
    ListAdminJobs200ResponseDataInner data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGetAdminJob200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGetAdminJob200Response.copyWith.fieldName(...)`
class _$GetAdminJob200ResponseCWProxyImpl
    implements _$GetAdminJob200ResponseCWProxy {
  const _$GetAdminJob200ResponseCWProxyImpl(this._value);

  final GetAdminJob200Response _value;

  @override
  GetAdminJob200Response data(ListAdminJobs200ResponseDataInner data) =>
      this(data: data);

  @override
  GetAdminJob200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetAdminJob200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetAdminJob200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetAdminJob200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return GetAdminJob200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as ListAdminJobs200ResponseDataInner,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $GetAdminJob200ResponseCopyWith on GetAdminJob200Response {
  /// Returns a callable class that can be used as follows: `instanceOfGetAdminJob200Response.copyWith(...)` or like so:`instanceOfGetAdminJob200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GetAdminJob200ResponseCWProxy get copyWith =>
      _$GetAdminJob200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetAdminJob200Response _$GetAdminJob200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GetAdminJob200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = GetAdminJob200Response(
    data: $checkedConvert(
      'data',
      (v) =>
          ListAdminJobs200ResponseDataInner.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$GetAdminJob200ResponseToJson(
  GetAdminJob200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
