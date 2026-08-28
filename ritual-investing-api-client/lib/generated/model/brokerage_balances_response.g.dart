// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_balances_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokerageBalancesResponseCWProxy {
  BrokerageBalancesResponse data(BrokerageBalancesProjection data);

  BrokerageBalancesResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageBalancesResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageBalancesResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageBalancesResponse call({
    BrokerageBalancesProjection data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokerageBalancesResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokerageBalancesResponse.copyWith.fieldName(...)`
class _$BrokerageBalancesResponseCWProxyImpl
    implements _$BrokerageBalancesResponseCWProxy {
  const _$BrokerageBalancesResponseCWProxyImpl(this._value);

  final BrokerageBalancesResponse _value;

  @override
  BrokerageBalancesResponse data(BrokerageBalancesProjection data) =>
      this(data: data);

  @override
  BrokerageBalancesResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageBalancesResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageBalancesResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageBalancesResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return BrokerageBalancesResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as BrokerageBalancesProjection,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $BrokerageBalancesResponseCopyWith on BrokerageBalancesResponse {
  /// Returns a callable class that can be used as follows: `instanceOfBrokerageBalancesResponse.copyWith(...)` or like so:`instanceOfBrokerageBalancesResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokerageBalancesResponseCWProxy get copyWith =>
      _$BrokerageBalancesResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokerageBalancesResponse _$BrokerageBalancesResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('BrokerageBalancesResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = BrokerageBalancesResponse(
    data: $checkedConvert(
      'data',
      (v) => BrokerageBalancesProjection.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$BrokerageBalancesResponseToJson(
  BrokerageBalancesResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
