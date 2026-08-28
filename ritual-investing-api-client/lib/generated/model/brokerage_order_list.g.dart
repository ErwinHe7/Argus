// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_order_list.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokerageOrderListCWProxy {
  BrokerageOrderList accountId(String accountId);

  BrokerageOrderList expiresAt(DateTime? expiresAt);

  BrokerageOrderList fetchedAt(DateTime? fetchedAt);

  BrokerageOrderList orders(List<BrokerageOrder> orders);

  BrokerageOrderList providerObservedAt(DateTime? providerObservedAt);

  BrokerageOrderList state(BrokerageOrderListStateEnum state);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageOrderList(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageOrderList(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageOrderList call({
    String accountId,
    DateTime? expiresAt,
    DateTime? fetchedAt,
    List<BrokerageOrder> orders,
    DateTime? providerObservedAt,
    BrokerageOrderListStateEnum state,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokerageOrderList.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokerageOrderList.copyWith.fieldName(...)`
class _$BrokerageOrderListCWProxyImpl implements _$BrokerageOrderListCWProxy {
  const _$BrokerageOrderListCWProxyImpl(this._value);

  final BrokerageOrderList _value;

  @override
  BrokerageOrderList accountId(String accountId) => this(accountId: accountId);

  @override
  BrokerageOrderList expiresAt(DateTime? expiresAt) =>
      this(expiresAt: expiresAt);

  @override
  BrokerageOrderList fetchedAt(DateTime? fetchedAt) =>
      this(fetchedAt: fetchedAt);

  @override
  BrokerageOrderList orders(List<BrokerageOrder> orders) =>
      this(orders: orders);

  @override
  BrokerageOrderList providerObservedAt(DateTime? providerObservedAt) =>
      this(providerObservedAt: providerObservedAt);

  @override
  BrokerageOrderList state(BrokerageOrderListStateEnum state) =>
      this(state: state);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageOrderList(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageOrderList(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageOrderList call({
    Object? accountId = const $CopyWithPlaceholder(),
    Object? expiresAt = const $CopyWithPlaceholder(),
    Object? fetchedAt = const $CopyWithPlaceholder(),
    Object? orders = const $CopyWithPlaceholder(),
    Object? providerObservedAt = const $CopyWithPlaceholder(),
    Object? state = const $CopyWithPlaceholder(),
  }) {
    return BrokerageOrderList(
      accountId: accountId == const $CopyWithPlaceholder()
          ? _value.accountId
          // ignore: cast_nullable_to_non_nullable
          : accountId as String,
      expiresAt: expiresAt == const $CopyWithPlaceholder()
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime?,
      fetchedAt: fetchedAt == const $CopyWithPlaceholder()
          ? _value.fetchedAt
          // ignore: cast_nullable_to_non_nullable
          : fetchedAt as DateTime?,
      orders: orders == const $CopyWithPlaceholder()
          ? _value.orders
          // ignore: cast_nullable_to_non_nullable
          : orders as List<BrokerageOrder>,
      providerObservedAt: providerObservedAt == const $CopyWithPlaceholder()
          ? _value.providerObservedAt
          // ignore: cast_nullable_to_non_nullable
          : providerObservedAt as DateTime?,
      state: state == const $CopyWithPlaceholder()
          ? _value.state
          // ignore: cast_nullable_to_non_nullable
          : state as BrokerageOrderListStateEnum,
    );
  }
}

extension $BrokerageOrderListCopyWith on BrokerageOrderList {
  /// Returns a callable class that can be used as follows: `instanceOfBrokerageOrderList.copyWith(...)` or like so:`instanceOfBrokerageOrderList.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokerageOrderListCWProxy get copyWith =>
      _$BrokerageOrderListCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokerageOrderList _$BrokerageOrderListFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'BrokerageOrderList',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'account_id',
            'expires_at',
            'fetched_at',
            'orders',
            'provider_observed_at',
            'state',
          ],
        );
        final val = BrokerageOrderList(
          accountId: $checkedConvert('account_id', (v) => v as String),
          expiresAt: $checkedConvert(
            'expires_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          fetchedAt: $checkedConvert(
            'fetched_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          orders: $checkedConvert(
            'orders',
            (v) => (v as List<dynamic>)
                .map((e) => BrokerageOrder.fromJson(e as Map<String, dynamic>))
                .toList(),
          ),
          providerObservedAt: $checkedConvert(
            'provider_observed_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          state: $checkedConvert(
            'state',
            (v) => $enumDecode(
              _$BrokerageOrderListStateEnumEnumMap,
              v,
              unknownValue: BrokerageOrderListStateEnum.unknownDefaultOpenApi,
            ),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'accountId': 'account_id',
        'expiresAt': 'expires_at',
        'fetchedAt': 'fetched_at',
        'providerObservedAt': 'provider_observed_at',
      },
    );

Map<String, dynamic> _$BrokerageOrderListToJson(BrokerageOrderList instance) =>
    <String, dynamic>{
      'account_id': instance.accountId,
      'expires_at': instance.expiresAt?.toIso8601String(),
      'fetched_at': instance.fetchedAt?.toIso8601String(),
      'orders': instance.orders.map((e) => e.toJson()).toList(),
      'provider_observed_at': instance.providerObservedAt?.toIso8601String(),
      'state': _$BrokerageOrderListStateEnumEnumMap[instance.state]!,
    };

const _$BrokerageOrderListStateEnumEnumMap = {
  BrokerageOrderListStateEnum.fresh: 'fresh',
  BrokerageOrderListStateEnum.empty: 'empty',
  BrokerageOrderListStateEnum.stale: 'stale',
  BrokerageOrderListStateEnum.partial: 'partial',
  BrokerageOrderListStateEnum.unavailable: 'unavailable',
  BrokerageOrderListStateEnum.offline: 'offline',
  BrokerageOrderListStateEnum.rateLimited: 'rate_limited',
  BrokerageOrderListStateEnum.disconnected: 'disconnected',
  BrokerageOrderListStateEnum.reauthorizationRequired:
      'reauthorization_required',
  BrokerageOrderListStateEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
