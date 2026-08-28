// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_accounts_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokerageAccountsResponseCWProxy {
  BrokerageAccountsResponse data(List<BrokerageAccount> data);

  BrokerageAccountsResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageAccountsResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageAccountsResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageAccountsResponse call({
    List<BrokerageAccount> data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokerageAccountsResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokerageAccountsResponse.copyWith.fieldName(...)`
class _$BrokerageAccountsResponseCWProxyImpl
    implements _$BrokerageAccountsResponseCWProxy {
  const _$BrokerageAccountsResponseCWProxyImpl(this._value);

  final BrokerageAccountsResponse _value;

  @override
  BrokerageAccountsResponse data(List<BrokerageAccount> data) =>
      this(data: data);

  @override
  BrokerageAccountsResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageAccountsResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageAccountsResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageAccountsResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return BrokerageAccountsResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<BrokerageAccount>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $BrokerageAccountsResponseCopyWith on BrokerageAccountsResponse {
  /// Returns a callable class that can be used as follows: `instanceOfBrokerageAccountsResponse.copyWith(...)` or like so:`instanceOfBrokerageAccountsResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokerageAccountsResponseCWProxy get copyWith =>
      _$BrokerageAccountsResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokerageAccountsResponse _$BrokerageAccountsResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('BrokerageAccountsResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = BrokerageAccountsResponse(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => BrokerageAccount.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$BrokerageAccountsResponseToJson(
  BrokerageAccountsResponse instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
