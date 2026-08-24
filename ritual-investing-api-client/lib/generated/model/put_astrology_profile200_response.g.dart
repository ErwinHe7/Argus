// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'put_astrology_profile200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PutAstrologyProfile200ResponseCWProxy {
  PutAstrologyProfile200Response data(AstrologyProfile data);

  PutAstrologyProfile200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PutAstrologyProfile200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PutAstrologyProfile200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  PutAstrologyProfile200Response call({
    AstrologyProfile data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPutAstrologyProfile200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPutAstrologyProfile200Response.copyWith.fieldName(...)`
class _$PutAstrologyProfile200ResponseCWProxyImpl
    implements _$PutAstrologyProfile200ResponseCWProxy {
  const _$PutAstrologyProfile200ResponseCWProxyImpl(this._value);

  final PutAstrologyProfile200Response _value;

  @override
  PutAstrologyProfile200Response data(AstrologyProfile data) =>
      this(data: data);

  @override
  PutAstrologyProfile200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PutAstrologyProfile200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PutAstrologyProfile200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  PutAstrologyProfile200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return PutAstrologyProfile200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as AstrologyProfile,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $PutAstrologyProfile200ResponseCopyWith
    on PutAstrologyProfile200Response {
  /// Returns a callable class that can be used as follows: `instanceOfPutAstrologyProfile200Response.copyWith(...)` or like so:`instanceOfPutAstrologyProfile200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PutAstrologyProfile200ResponseCWProxy get copyWith =>
      _$PutAstrologyProfile200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PutAstrologyProfile200Response _$PutAstrologyProfile200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PutAstrologyProfile200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = PutAstrologyProfile200Response(
    data: $checkedConvert(
      'data',
      (v) => AstrologyProfile.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$PutAstrologyProfile200ResponseToJson(
  PutAstrologyProfile200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
