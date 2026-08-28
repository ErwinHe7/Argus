// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_capabilities_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokerageCapabilitiesResponseCWProxy {
  BrokerageCapabilitiesResponse data(BrokerageCapabilitiesProjection data);

  BrokerageCapabilitiesResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageCapabilitiesResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageCapabilitiesResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageCapabilitiesResponse call({
    BrokerageCapabilitiesProjection data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokerageCapabilitiesResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokerageCapabilitiesResponse.copyWith.fieldName(...)`
class _$BrokerageCapabilitiesResponseCWProxyImpl
    implements _$BrokerageCapabilitiesResponseCWProxy {
  const _$BrokerageCapabilitiesResponseCWProxyImpl(this._value);

  final BrokerageCapabilitiesResponse _value;

  @override
  BrokerageCapabilitiesResponse data(BrokerageCapabilitiesProjection data) =>
      this(data: data);

  @override
  BrokerageCapabilitiesResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageCapabilitiesResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageCapabilitiesResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageCapabilitiesResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return BrokerageCapabilitiesResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as BrokerageCapabilitiesProjection,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $BrokerageCapabilitiesResponseCopyWith
    on BrokerageCapabilitiesResponse {
  /// Returns a callable class that can be used as follows: `instanceOfBrokerageCapabilitiesResponse.copyWith(...)` or like so:`instanceOfBrokerageCapabilitiesResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokerageCapabilitiesResponseCWProxy get copyWith =>
      _$BrokerageCapabilitiesResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokerageCapabilitiesResponse _$BrokerageCapabilitiesResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('BrokerageCapabilitiesResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = BrokerageCapabilitiesResponse(
    data: $checkedConvert(
      'data',
      (v) =>
          BrokerageCapabilitiesProjection.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$BrokerageCapabilitiesResponseToJson(
  BrokerageCapabilitiesResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
