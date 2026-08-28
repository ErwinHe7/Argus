// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_order_reconciliation_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokerageOrderReconciliationResponseCWProxy {
  BrokerageOrderReconciliationResponse data(BrokerageOrderReconciliation data);

  BrokerageOrderReconciliationResponse meta(GetAccount200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageOrderReconciliationResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageOrderReconciliationResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageOrderReconciliationResponse call({
    BrokerageOrderReconciliation data,
    GetAccount200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokerageOrderReconciliationResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokerageOrderReconciliationResponse.copyWith.fieldName(...)`
class _$BrokerageOrderReconciliationResponseCWProxyImpl
    implements _$BrokerageOrderReconciliationResponseCWProxy {
  const _$BrokerageOrderReconciliationResponseCWProxyImpl(this._value);

  final BrokerageOrderReconciliationResponse _value;

  @override
  BrokerageOrderReconciliationResponse data(
    BrokerageOrderReconciliation data,
  ) => this(data: data);

  @override
  BrokerageOrderReconciliationResponse meta(GetAccount200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageOrderReconciliationResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageOrderReconciliationResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageOrderReconciliationResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return BrokerageOrderReconciliationResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as BrokerageOrderReconciliation,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as GetAccount200ResponseMeta,
    );
  }
}

extension $BrokerageOrderReconciliationResponseCopyWith
    on BrokerageOrderReconciliationResponse {
  /// Returns a callable class that can be used as follows: `instanceOfBrokerageOrderReconciliationResponse.copyWith(...)` or like so:`instanceOfBrokerageOrderReconciliationResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokerageOrderReconciliationResponseCWProxy get copyWith =>
      _$BrokerageOrderReconciliationResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokerageOrderReconciliationResponse
_$BrokerageOrderReconciliationResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('BrokerageOrderReconciliationResponse', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = BrokerageOrderReconciliationResponse(
        data: $checkedConvert(
          'data',
          (v) =>
              BrokerageOrderReconciliation.fromJson(v as Map<String, dynamic>),
        ),
        meta: $checkedConvert(
          'meta',
          (v) => GetAccount200ResponseMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$BrokerageOrderReconciliationResponseToJson(
  BrokerageOrderReconciliationResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
