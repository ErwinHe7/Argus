// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reset_demo_state200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ResetDemoState200ResponseCWProxy {
  ResetDemoState200Response data(DemoResetResult data);

  ResetDemoState200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ResetDemoState200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ResetDemoState200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ResetDemoState200Response call({DemoResetResult data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfResetDemoState200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfResetDemoState200Response.copyWith.fieldName(...)`
class _$ResetDemoState200ResponseCWProxyImpl
    implements _$ResetDemoState200ResponseCWProxy {
  const _$ResetDemoState200ResponseCWProxyImpl(this._value);

  final ResetDemoState200Response _value;

  @override
  ResetDemoState200Response data(DemoResetResult data) => this(data: data);

  @override
  ResetDemoState200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ResetDemoState200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ResetDemoState200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ResetDemoState200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ResetDemoState200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as DemoResetResult,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $ResetDemoState200ResponseCopyWith on ResetDemoState200Response {
  /// Returns a callable class that can be used as follows: `instanceOfResetDemoState200Response.copyWith(...)` or like so:`instanceOfResetDemoState200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ResetDemoState200ResponseCWProxy get copyWith =>
      _$ResetDemoState200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ResetDemoState200Response _$ResetDemoState200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ResetDemoState200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = ResetDemoState200Response(
    data: $checkedConvert(
      'data',
      (v) => DemoResetResult.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$ResetDemoState200ResponseToJson(
  ResetDemoState200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
