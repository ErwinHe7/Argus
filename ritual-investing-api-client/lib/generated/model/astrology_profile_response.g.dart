// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'astrology_profile_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AstrologyProfileResponseCWProxy {
  AstrologyProfileResponse data(AstrologyProfile data);

  AstrologyProfileResponse meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AstrologyProfileResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AstrologyProfileResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  AstrologyProfileResponse call({AstrologyProfile data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAstrologyProfileResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAstrologyProfileResponse.copyWith.fieldName(...)`
class _$AstrologyProfileResponseCWProxyImpl
    implements _$AstrologyProfileResponseCWProxy {
  const _$AstrologyProfileResponseCWProxyImpl(this._value);

  final AstrologyProfileResponse _value;

  @override
  AstrologyProfileResponse data(AstrologyProfile data) => this(data: data);

  @override
  AstrologyProfileResponse meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AstrologyProfileResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AstrologyProfileResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  AstrologyProfileResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return AstrologyProfileResponse(
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

extension $AstrologyProfileResponseCopyWith on AstrologyProfileResponse {
  /// Returns a callable class that can be used as follows: `instanceOfAstrologyProfileResponse.copyWith(...)` or like so:`instanceOfAstrologyProfileResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AstrologyProfileResponseCWProxy get copyWith =>
      _$AstrologyProfileResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AstrologyProfileResponse _$AstrologyProfileResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AstrologyProfileResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = AstrologyProfileResponse(
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

Map<String, dynamic> _$AstrologyProfileResponseToJson(
  AstrologyProfileResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
