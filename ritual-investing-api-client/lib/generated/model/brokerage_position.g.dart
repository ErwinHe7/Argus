// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_position.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokeragePositionCWProxy {
  BrokeragePosition asset(BrokerageAsset asset);

  BrokeragePosition availableQuantity(String availableQuantity);

  BrokeragePosition averageCost(String? averageCost);

  BrokeragePosition currency(String currency);

  BrokeragePosition marketValue(String? marketValue);

  BrokeragePosition quantity(String quantity);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokeragePosition(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokeragePosition(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokeragePosition call({
    BrokerageAsset asset,
    String availableQuantity,
    String? averageCost,
    String currency,
    String? marketValue,
    String quantity,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokeragePosition.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokeragePosition.copyWith.fieldName(...)`
class _$BrokeragePositionCWProxyImpl implements _$BrokeragePositionCWProxy {
  const _$BrokeragePositionCWProxyImpl(this._value);

  final BrokeragePosition _value;

  @override
  BrokeragePosition asset(BrokerageAsset asset) => this(asset: asset);

  @override
  BrokeragePosition availableQuantity(String availableQuantity) =>
      this(availableQuantity: availableQuantity);

  @override
  BrokeragePosition averageCost(String? averageCost) =>
      this(averageCost: averageCost);

  @override
  BrokeragePosition currency(String currency) => this(currency: currency);

  @override
  BrokeragePosition marketValue(String? marketValue) =>
      this(marketValue: marketValue);

  @override
  BrokeragePosition quantity(String quantity) => this(quantity: quantity);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokeragePosition(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokeragePosition(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokeragePosition call({
    Object? asset = const $CopyWithPlaceholder(),
    Object? availableQuantity = const $CopyWithPlaceholder(),
    Object? averageCost = const $CopyWithPlaceholder(),
    Object? currency = const $CopyWithPlaceholder(),
    Object? marketValue = const $CopyWithPlaceholder(),
    Object? quantity = const $CopyWithPlaceholder(),
  }) {
    return BrokeragePosition(
      asset: asset == const $CopyWithPlaceholder()
          ? _value.asset
          // ignore: cast_nullable_to_non_nullable
          : asset as BrokerageAsset,
      availableQuantity: availableQuantity == const $CopyWithPlaceholder()
          ? _value.availableQuantity
          // ignore: cast_nullable_to_non_nullable
          : availableQuantity as String,
      averageCost: averageCost == const $CopyWithPlaceholder()
          ? _value.averageCost
          // ignore: cast_nullable_to_non_nullable
          : averageCost as String?,
      currency: currency == const $CopyWithPlaceholder()
          ? _value.currency
          // ignore: cast_nullable_to_non_nullable
          : currency as String,
      marketValue: marketValue == const $CopyWithPlaceholder()
          ? _value.marketValue
          // ignore: cast_nullable_to_non_nullable
          : marketValue as String?,
      quantity: quantity == const $CopyWithPlaceholder()
          ? _value.quantity
          // ignore: cast_nullable_to_non_nullable
          : quantity as String,
    );
  }
}

extension $BrokeragePositionCopyWith on BrokeragePosition {
  /// Returns a callable class that can be used as follows: `instanceOfBrokeragePosition.copyWith(...)` or like so:`instanceOfBrokeragePosition.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokeragePositionCWProxy get copyWith =>
      _$BrokeragePositionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokeragePosition _$BrokeragePositionFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'BrokeragePosition',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'asset',
            'available_quantity',
            'average_cost',
            'currency',
            'market_value',
            'quantity',
          ],
        );
        final val = BrokeragePosition(
          asset: $checkedConvert(
            'asset',
            (v) => BrokerageAsset.fromJson(v as Map<String, dynamic>),
          ),
          availableQuantity: $checkedConvert(
            'available_quantity',
            (v) => v as String,
          ),
          averageCost: $checkedConvert('average_cost', (v) => v as String?),
          currency: $checkedConvert('currency', (v) => v as String),
          marketValue: $checkedConvert('market_value', (v) => v as String?),
          quantity: $checkedConvert('quantity', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'availableQuantity': 'available_quantity',
        'averageCost': 'average_cost',
        'marketValue': 'market_value',
      },
    );

Map<String, dynamic> _$BrokeragePositionToJson(BrokeragePosition instance) =>
    <String, dynamic>{
      'asset': instance.asset.toJson(),
      'available_quantity': instance.availableQuantity,
      'average_cost': instance.averageCost,
      'currency': instance.currency,
      'market_value': instance.marketValue,
      'quantity': instance.quantity,
    };
