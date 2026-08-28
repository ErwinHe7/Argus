// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_order_detail_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokerageOrderDetailResponseCWProxy {
  BrokerageOrderDetailResponse data(BrokerageOrderDetail data);

  BrokerageOrderDetailResponse meta(GetAccount200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageOrderDetailResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageOrderDetailResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageOrderDetailResponse call({
    BrokerageOrderDetail data,
    GetAccount200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokerageOrderDetailResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokerageOrderDetailResponse.copyWith.fieldName(...)`
class _$BrokerageOrderDetailResponseCWProxyImpl
    implements _$BrokerageOrderDetailResponseCWProxy {
  const _$BrokerageOrderDetailResponseCWProxyImpl(this._value);

  final BrokerageOrderDetailResponse _value;

  @override
  BrokerageOrderDetailResponse data(BrokerageOrderDetail data) =>
      this(data: data);

  @override
  BrokerageOrderDetailResponse meta(GetAccount200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageOrderDetailResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageOrderDetailResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageOrderDetailResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return BrokerageOrderDetailResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as BrokerageOrderDetail,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as GetAccount200ResponseMeta,
    );
  }
}

extension $BrokerageOrderDetailResponseCopyWith
    on BrokerageOrderDetailResponse {
  /// Returns a callable class that can be used as follows: `instanceOfBrokerageOrderDetailResponse.copyWith(...)` or like so:`instanceOfBrokerageOrderDetailResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokerageOrderDetailResponseCWProxy get copyWith =>
      _$BrokerageOrderDetailResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokerageOrderDetailResponse _$BrokerageOrderDetailResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('BrokerageOrderDetailResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = BrokerageOrderDetailResponse(
    data: $checkedConvert(
      'data',
      (v) => BrokerageOrderDetail.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => GetAccount200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$BrokerageOrderDetailResponseToJson(
  BrokerageOrderDetailResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
