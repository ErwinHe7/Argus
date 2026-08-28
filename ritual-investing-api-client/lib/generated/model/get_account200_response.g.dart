// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_account200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GetAccount200ResponseCWProxy {
  GetAccount200Response data(Object? data);

  GetAccount200Response meta(GetAccount200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetAccount200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetAccount200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetAccount200Response call({Object? data, GetAccount200ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGetAccount200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGetAccount200Response.copyWith.fieldName(...)`
class _$GetAccount200ResponseCWProxyImpl
    implements _$GetAccount200ResponseCWProxy {
  const _$GetAccount200ResponseCWProxyImpl(this._value);

  final GetAccount200Response _value;

  @override
  GetAccount200Response data(Object? data) => this(data: data);

  @override
  GetAccount200Response meta(GetAccount200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetAccount200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetAccount200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetAccount200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return GetAccount200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as Object?,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as GetAccount200ResponseMeta,
    );
  }
}

extension $GetAccount200ResponseCopyWith on GetAccount200Response {
  /// Returns a callable class that can be used as follows: `instanceOfGetAccount200Response.copyWith(...)` or like so:`instanceOfGetAccount200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GetAccount200ResponseCWProxy get copyWith =>
      _$GetAccount200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetAccount200Response _$GetAccount200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GetAccount200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['meta']);
  final val = GetAccount200Response(
    data: $checkedConvert('data', (v) => v),
    meta: $checkedConvert(
      'meta',
      (v) => GetAccount200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$GetAccount200ResponseToJson(
  GetAccount200Response instance,
) => <String, dynamic>{'data': ?instance.data, 'meta': instance.meta.toJson()};
