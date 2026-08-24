// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_order200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GetOrder200ResponseCWProxy {
  GetOrder200Response data(SimulatedOrder data);

  GetOrder200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetOrder200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetOrder200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetOrder200Response call({SimulatedOrder data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGetOrder200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGetOrder200Response.copyWith.fieldName(...)`
class _$GetOrder200ResponseCWProxyImpl implements _$GetOrder200ResponseCWProxy {
  const _$GetOrder200ResponseCWProxyImpl(this._value);

  final GetOrder200Response _value;

  @override
  GetOrder200Response data(SimulatedOrder data) => this(data: data);

  @override
  GetOrder200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetOrder200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetOrder200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetOrder200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return GetOrder200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as SimulatedOrder,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $GetOrder200ResponseCopyWith on GetOrder200Response {
  /// Returns a callable class that can be used as follows: `instanceOfGetOrder200Response.copyWith(...)` or like so:`instanceOfGetOrder200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GetOrder200ResponseCWProxy get copyWith =>
      _$GetOrder200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetOrder200Response _$GetOrder200ResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GetOrder200Response', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = GetOrder200Response(
        data: $checkedConvert(
          'data',
          (v) => SimulatedOrder.fromJson(v as Map<String, dynamic>),
        ),
        meta: $checkedConvert(
          'meta',
          (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$GetOrder200ResponseToJson(
  GetOrder200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
