// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_order_command_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokerageOrderCommandResponseCWProxy {
  BrokerageOrderCommandResponse data(BrokerageOrderCommand data);

  BrokerageOrderCommandResponse meta(GetAccount200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageOrderCommandResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageOrderCommandResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageOrderCommandResponse call({
    BrokerageOrderCommand data,
    GetAccount200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokerageOrderCommandResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokerageOrderCommandResponse.copyWith.fieldName(...)`
class _$BrokerageOrderCommandResponseCWProxyImpl
    implements _$BrokerageOrderCommandResponseCWProxy {
  const _$BrokerageOrderCommandResponseCWProxyImpl(this._value);

  final BrokerageOrderCommandResponse _value;

  @override
  BrokerageOrderCommandResponse data(BrokerageOrderCommand data) =>
      this(data: data);

  @override
  BrokerageOrderCommandResponse meta(GetAccount200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageOrderCommandResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageOrderCommandResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageOrderCommandResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return BrokerageOrderCommandResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as BrokerageOrderCommand,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as GetAccount200ResponseMeta,
    );
  }
}

extension $BrokerageOrderCommandResponseCopyWith
    on BrokerageOrderCommandResponse {
  /// Returns a callable class that can be used as follows: `instanceOfBrokerageOrderCommandResponse.copyWith(...)` or like so:`instanceOfBrokerageOrderCommandResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokerageOrderCommandResponseCWProxy get copyWith =>
      _$BrokerageOrderCommandResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokerageOrderCommandResponse _$BrokerageOrderCommandResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('BrokerageOrderCommandResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = BrokerageOrderCommandResponse(
    data: $checkedConvert(
      'data',
      (v) => BrokerageOrderCommand.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => GetAccount200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$BrokerageOrderCommandResponseToJson(
  BrokerageOrderCommandResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
