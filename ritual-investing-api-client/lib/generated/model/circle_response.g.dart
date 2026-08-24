// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'circle_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CircleResponseCWProxy {
  CircleResponse data(CircleView data);

  CircleResponse meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CircleResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CircleResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  CircleResponse call({CircleView data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCircleResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCircleResponse.copyWith.fieldName(...)`
class _$CircleResponseCWProxyImpl implements _$CircleResponseCWProxy {
  const _$CircleResponseCWProxyImpl(this._value);

  final CircleResponse _value;

  @override
  CircleResponse data(CircleView data) => this(data: data);

  @override
  CircleResponse meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CircleResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CircleResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  CircleResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CircleResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as CircleView,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $CircleResponseCopyWith on CircleResponse {
  /// Returns a callable class that can be used as follows: `instanceOfCircleResponse.copyWith(...)` or like so:`instanceOfCircleResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CircleResponseCWProxy get copyWith => _$CircleResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CircleResponse _$CircleResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CircleResponse', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = CircleResponse(
        data: $checkedConvert(
          'data',
          (v) => CircleView.fromJson(v as Map<String, dynamic>),
        ),
        meta: $checkedConvert(
          'meta',
          (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CircleResponseToJson(CircleResponse instance) =>
    <String, dynamic>{
      'data': instance.data.toJson(),
      'meta': instance.meta.toJson(),
    };
