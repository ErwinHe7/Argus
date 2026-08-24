// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_admin_moderation_case200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GetAdminModerationCase200ResponseCWProxy {
  GetAdminModerationCase200Response data(AdminModerationCase data);

  GetAdminModerationCase200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetAdminModerationCase200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetAdminModerationCase200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetAdminModerationCase200Response call({
    AdminModerationCase data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGetAdminModerationCase200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGetAdminModerationCase200Response.copyWith.fieldName(...)`
class _$GetAdminModerationCase200ResponseCWProxyImpl
    implements _$GetAdminModerationCase200ResponseCWProxy {
  const _$GetAdminModerationCase200ResponseCWProxyImpl(this._value);

  final GetAdminModerationCase200Response _value;

  @override
  GetAdminModerationCase200Response data(AdminModerationCase data) =>
      this(data: data);

  @override
  GetAdminModerationCase200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetAdminModerationCase200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetAdminModerationCase200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetAdminModerationCase200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return GetAdminModerationCase200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as AdminModerationCase,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $GetAdminModerationCase200ResponseCopyWith
    on GetAdminModerationCase200Response {
  /// Returns a callable class that can be used as follows: `instanceOfGetAdminModerationCase200Response.copyWith(...)` or like so:`instanceOfGetAdminModerationCase200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GetAdminModerationCase200ResponseCWProxy get copyWith =>
      _$GetAdminModerationCase200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetAdminModerationCase200Response _$GetAdminModerationCase200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GetAdminModerationCase200Response', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = GetAdminModerationCase200Response(
    data: $checkedConvert(
      'data',
      (v) => AdminModerationCase.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$GetAdminModerationCase200ResponseToJson(
  GetAdminModerationCase200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
