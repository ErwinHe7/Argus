// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_positions_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokeragePositionsResponseCWProxy {
  BrokeragePositionsResponse data(BrokeragePositionsProjection data);

  BrokeragePositionsResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokeragePositionsResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokeragePositionsResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokeragePositionsResponse call({
    BrokeragePositionsProjection data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokeragePositionsResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokeragePositionsResponse.copyWith.fieldName(...)`
class _$BrokeragePositionsResponseCWProxyImpl
    implements _$BrokeragePositionsResponseCWProxy {
  const _$BrokeragePositionsResponseCWProxyImpl(this._value);

  final BrokeragePositionsResponse _value;

  @override
  BrokeragePositionsResponse data(BrokeragePositionsProjection data) =>
      this(data: data);

  @override
  BrokeragePositionsResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokeragePositionsResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokeragePositionsResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokeragePositionsResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return BrokeragePositionsResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as BrokeragePositionsProjection,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $BrokeragePositionsResponseCopyWith on BrokeragePositionsResponse {
  /// Returns a callable class that can be used as follows: `instanceOfBrokeragePositionsResponse.copyWith(...)` or like so:`instanceOfBrokeragePositionsResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokeragePositionsResponseCWProxy get copyWith =>
      _$BrokeragePositionsResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokeragePositionsResponse _$BrokeragePositionsResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('BrokeragePositionsResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = BrokeragePositionsResponse(
    data: $checkedConvert(
      'data',
      (v) => BrokeragePositionsProjection.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$BrokeragePositionsResponseToJson(
  BrokeragePositionsResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
