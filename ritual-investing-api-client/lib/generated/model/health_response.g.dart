// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$HealthResponseCWProxy {
  HealthResponse data(HealthResponseData data);

  HealthResponse meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HealthResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HealthResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  HealthResponse call({HealthResponseData data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfHealthResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfHealthResponse.copyWith.fieldName(...)`
class _$HealthResponseCWProxyImpl implements _$HealthResponseCWProxy {
  const _$HealthResponseCWProxyImpl(this._value);

  final HealthResponse _value;

  @override
  HealthResponse data(HealthResponseData data) => this(data: data);

  @override
  HealthResponse meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HealthResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HealthResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  HealthResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return HealthResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as HealthResponseData,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $HealthResponseCopyWith on HealthResponse {
  /// Returns a callable class that can be used as follows: `instanceOfHealthResponse.copyWith(...)` or like so:`instanceOfHealthResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$HealthResponseCWProxy get copyWith => _$HealthResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HealthResponse _$HealthResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('HealthResponse', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = HealthResponse(
        data: $checkedConvert(
          'data',
          (v) => HealthResponseData.fromJson(v as Map<String, dynamic>),
        ),
        meta: $checkedConvert(
          'meta',
          (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$HealthResponseToJson(HealthResponse instance) =>
    <String, dynamic>{
      'data': instance.data.toJson(),
      'meta': instance.meta.toJson(),
    };
