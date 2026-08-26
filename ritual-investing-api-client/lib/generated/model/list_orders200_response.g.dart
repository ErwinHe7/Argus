// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_orders200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListOrders200ResponseCWProxy {
  ListOrders200Response data(List<SimulatedOrder> data);

  ListOrders200Response meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListOrders200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListOrders200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListOrders200Response call({List<SimulatedOrder> data, CollectionMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListOrders200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListOrders200Response.copyWith.fieldName(...)`
class _$ListOrders200ResponseCWProxyImpl
    implements _$ListOrders200ResponseCWProxy {
  const _$ListOrders200ResponseCWProxyImpl(this._value);

  final ListOrders200Response _value;

  @override
  ListOrders200Response data(List<SimulatedOrder> data) => this(data: data);

  @override
  ListOrders200Response meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListOrders200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListOrders200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListOrders200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ListOrders200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<SimulatedOrder>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $ListOrders200ResponseCopyWith on ListOrders200Response {
  /// Returns a callable class that can be used as follows: `instanceOfListOrders200Response.copyWith(...)` or like so:`instanceOfListOrders200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListOrders200ResponseCWProxy get copyWith =>
      _$ListOrders200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListOrders200Response _$ListOrders200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ListOrders200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = ListOrders200Response(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => SimulatedOrder.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$ListOrders200ResponseToJson(
  ListOrders200Response instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
