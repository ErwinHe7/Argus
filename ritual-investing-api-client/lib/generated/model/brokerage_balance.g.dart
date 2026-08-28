// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_balance.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokerageBalanceCWProxy {
  BrokerageBalance buyingPower(String? buyingPower);

  BrokerageBalance cash(String cash);

  BrokerageBalance currency(String currency);

  BrokerageBalance marketValue(String? marketValue);

  BrokerageBalance totalEquity(String totalEquity);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageBalance(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageBalance(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageBalance call({
    String? buyingPower,
    String cash,
    String currency,
    String? marketValue,
    String totalEquity,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokerageBalance.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokerageBalance.copyWith.fieldName(...)`
class _$BrokerageBalanceCWProxyImpl implements _$BrokerageBalanceCWProxy {
  const _$BrokerageBalanceCWProxyImpl(this._value);

  final BrokerageBalance _value;

  @override
  BrokerageBalance buyingPower(String? buyingPower) =>
      this(buyingPower: buyingPower);

  @override
  BrokerageBalance cash(String cash) => this(cash: cash);

  @override
  BrokerageBalance currency(String currency) => this(currency: currency);

  @override
  BrokerageBalance marketValue(String? marketValue) =>
      this(marketValue: marketValue);

  @override
  BrokerageBalance totalEquity(String totalEquity) =>
      this(totalEquity: totalEquity);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageBalance(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageBalance(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageBalance call({
    Object? buyingPower = const $CopyWithPlaceholder(),
    Object? cash = const $CopyWithPlaceholder(),
    Object? currency = const $CopyWithPlaceholder(),
    Object? marketValue = const $CopyWithPlaceholder(),
    Object? totalEquity = const $CopyWithPlaceholder(),
  }) {
    return BrokerageBalance(
      buyingPower: buyingPower == const $CopyWithPlaceholder()
          ? _value.buyingPower
          // ignore: cast_nullable_to_non_nullable
          : buyingPower as String?,
      cash: cash == const $CopyWithPlaceholder()
          ? _value.cash
          // ignore: cast_nullable_to_non_nullable
          : cash as String,
      currency: currency == const $CopyWithPlaceholder()
          ? _value.currency
          // ignore: cast_nullable_to_non_nullable
          : currency as String,
      marketValue: marketValue == const $CopyWithPlaceholder()
          ? _value.marketValue
          // ignore: cast_nullable_to_non_nullable
          : marketValue as String?,
      totalEquity: totalEquity == const $CopyWithPlaceholder()
          ? _value.totalEquity
          // ignore: cast_nullable_to_non_nullable
          : totalEquity as String,
    );
  }
}

extension $BrokerageBalanceCopyWith on BrokerageBalance {
  /// Returns a callable class that can be used as follows: `instanceOfBrokerageBalance.copyWith(...)` or like so:`instanceOfBrokerageBalance.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokerageBalanceCWProxy get copyWith => _$BrokerageBalanceCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokerageBalance _$BrokerageBalanceFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'BrokerageBalance',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'buying_power',
            'cash',
            'currency',
            'market_value',
            'total_equity',
          ],
        );
        final val = BrokerageBalance(
          buyingPower: $checkedConvert('buying_power', (v) => v as String?),
          cash: $checkedConvert('cash', (v) => v as String),
          currency: $checkedConvert('currency', (v) => v as String),
          marketValue: $checkedConvert('market_value', (v) => v as String?),
          totalEquity: $checkedConvert('total_equity', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'buyingPower': 'buying_power',
        'marketValue': 'market_value',
        'totalEquity': 'total_equity',
      },
    );

Map<String, dynamic> _$BrokerageBalanceToJson(BrokerageBalance instance) =>
    <String, dynamic>{
      'buying_power': instance.buyingPower,
      'cash': instance.cash,
      'currency': instance.currency,
      'market_value': instance.marketValue,
      'total_equity': instance.totalEquity,
    };
