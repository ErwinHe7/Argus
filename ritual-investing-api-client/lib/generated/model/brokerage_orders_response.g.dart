// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_orders_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokerageOrdersResponseCWProxy {
  BrokerageOrdersResponse data(BrokerageOrderList data);

  BrokerageOrdersResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageOrdersResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageOrdersResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageOrdersResponse call({
    BrokerageOrderList data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokerageOrdersResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokerageOrdersResponse.copyWith.fieldName(...)`
class _$BrokerageOrdersResponseCWProxyImpl
    implements _$BrokerageOrdersResponseCWProxy {
  const _$BrokerageOrdersResponseCWProxyImpl(this._value);

  final BrokerageOrdersResponse _value;

  @override
  BrokerageOrdersResponse data(BrokerageOrderList data) => this(data: data);

  @override
  BrokerageOrdersResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageOrdersResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageOrdersResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageOrdersResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return BrokerageOrdersResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as BrokerageOrderList,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $BrokerageOrdersResponseCopyWith on BrokerageOrdersResponse {
  /// Returns a callable class that can be used as follows: `instanceOfBrokerageOrdersResponse.copyWith(...)` or like so:`instanceOfBrokerageOrdersResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokerageOrdersResponseCWProxy get copyWith =>
      _$BrokerageOrdersResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokerageOrdersResponse _$BrokerageOrdersResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('BrokerageOrdersResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = BrokerageOrdersResponse(
    data: $checkedConvert(
      'data',
      (v) => BrokerageOrderList.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$BrokerageOrdersResponseToJson(
  BrokerageOrdersResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
