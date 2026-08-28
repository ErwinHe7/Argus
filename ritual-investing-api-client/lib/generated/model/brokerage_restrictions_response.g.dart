// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_restrictions_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokerageRestrictionsResponseCWProxy {
  BrokerageRestrictionsResponse data(BrokerageRestrictionsProjection data);

  BrokerageRestrictionsResponse meta(GetAccount200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageRestrictionsResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageRestrictionsResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageRestrictionsResponse call({
    BrokerageRestrictionsProjection data,
    GetAccount200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokerageRestrictionsResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokerageRestrictionsResponse.copyWith.fieldName(...)`
class _$BrokerageRestrictionsResponseCWProxyImpl
    implements _$BrokerageRestrictionsResponseCWProxy {
  const _$BrokerageRestrictionsResponseCWProxyImpl(this._value);

  final BrokerageRestrictionsResponse _value;

  @override
  BrokerageRestrictionsResponse data(BrokerageRestrictionsProjection data) =>
      this(data: data);

  @override
  BrokerageRestrictionsResponse meta(GetAccount200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageRestrictionsResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageRestrictionsResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageRestrictionsResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return BrokerageRestrictionsResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as BrokerageRestrictionsProjection,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as GetAccount200ResponseMeta,
    );
  }
}

extension $BrokerageRestrictionsResponseCopyWith
    on BrokerageRestrictionsResponse {
  /// Returns a callable class that can be used as follows: `instanceOfBrokerageRestrictionsResponse.copyWith(...)` or like so:`instanceOfBrokerageRestrictionsResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokerageRestrictionsResponseCWProxy get copyWith =>
      _$BrokerageRestrictionsResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokerageRestrictionsResponse _$BrokerageRestrictionsResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('BrokerageRestrictionsResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = BrokerageRestrictionsResponse(
    data: $checkedConvert(
      'data',
      (v) =>
          BrokerageRestrictionsProjection.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => GetAccount200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$BrokerageRestrictionsResponseToJson(
  BrokerageRestrictionsResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
