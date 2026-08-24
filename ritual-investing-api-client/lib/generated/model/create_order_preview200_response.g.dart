// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_order_preview200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateOrderPreview200ResponseCWProxy {
  CreateOrderPreview200Response data(OrderPreview data);

  CreateOrderPreview200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateOrderPreview200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateOrderPreview200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateOrderPreview200Response call({OrderPreview data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateOrderPreview200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateOrderPreview200Response.copyWith.fieldName(...)`
class _$CreateOrderPreview200ResponseCWProxyImpl
    implements _$CreateOrderPreview200ResponseCWProxy {
  const _$CreateOrderPreview200ResponseCWProxyImpl(this._value);

  final CreateOrderPreview200Response _value;

  @override
  CreateOrderPreview200Response data(OrderPreview data) => this(data: data);

  @override
  CreateOrderPreview200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateOrderPreview200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateOrderPreview200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateOrderPreview200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CreateOrderPreview200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as OrderPreview,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $CreateOrderPreview200ResponseCopyWith
    on CreateOrderPreview200Response {
  /// Returns a callable class that can be used as follows: `instanceOfCreateOrderPreview200Response.copyWith(...)` or like so:`instanceOfCreateOrderPreview200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateOrderPreview200ResponseCWProxy get copyWith =>
      _$CreateOrderPreview200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateOrderPreview200Response _$CreateOrderPreview200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateOrderPreview200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = CreateOrderPreview200Response(
    data: $checkedConvert(
      'data',
      (v) => OrderPreview.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$CreateOrderPreview200ResponseToJson(
  CreateOrderPreview200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
