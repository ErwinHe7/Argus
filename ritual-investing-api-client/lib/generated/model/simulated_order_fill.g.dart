// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'simulated_order_fill.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SimulatedOrderFillCWProxy {
  SimulatedOrderFill filledAt(DateTime filledAt);

  SimulatedOrderFill price(Money price);

  SimulatedOrderFill quantity(Quantity quantity);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SimulatedOrderFill(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SimulatedOrderFill(...).copyWith(id: 12, name: "My name")
  /// ````
  SimulatedOrderFill call({DateTime filledAt, Money price, Quantity quantity});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSimulatedOrderFill.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSimulatedOrderFill.copyWith.fieldName(...)`
class _$SimulatedOrderFillCWProxyImpl implements _$SimulatedOrderFillCWProxy {
  const _$SimulatedOrderFillCWProxyImpl(this._value);

  final SimulatedOrderFill _value;

  @override
  SimulatedOrderFill filledAt(DateTime filledAt) => this(filledAt: filledAt);

  @override
  SimulatedOrderFill price(Money price) => this(price: price);

  @override
  SimulatedOrderFill quantity(Quantity quantity) => this(quantity: quantity);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SimulatedOrderFill(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SimulatedOrderFill(...).copyWith(id: 12, name: "My name")
  /// ````
  SimulatedOrderFill call({
    Object? filledAt = const $CopyWithPlaceholder(),
    Object? price = const $CopyWithPlaceholder(),
    Object? quantity = const $CopyWithPlaceholder(),
  }) {
    return SimulatedOrderFill(
      filledAt: filledAt == const $CopyWithPlaceholder()
          ? _value.filledAt
          // ignore: cast_nullable_to_non_nullable
          : filledAt as DateTime,
      price: price == const $CopyWithPlaceholder()
          ? _value.price
          // ignore: cast_nullable_to_non_nullable
          : price as Money,
      quantity: quantity == const $CopyWithPlaceholder()
          ? _value.quantity
          // ignore: cast_nullable_to_non_nullable
          : quantity as Quantity,
    );
  }
}

extension $SimulatedOrderFillCopyWith on SimulatedOrderFill {
  /// Returns a callable class that can be used as follows: `instanceOfSimulatedOrderFill.copyWith(...)` or like so:`instanceOfSimulatedOrderFill.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SimulatedOrderFillCWProxy get copyWith =>
      _$SimulatedOrderFillCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SimulatedOrderFill _$SimulatedOrderFillFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SimulatedOrderFill', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['filled_at', 'price', 'quantity']);
      final val = SimulatedOrderFill(
        filledAt: $checkedConvert(
          'filled_at',
          (v) => DateTime.parse(v as String),
        ),
        price: $checkedConvert(
          'price',
          (v) => Money.fromJson(v as Map<String, dynamic>),
        ),
        quantity: $checkedConvert(
          'quantity',
          (v) => Quantity.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    }, fieldKeyMap: const {'filledAt': 'filled_at'});

Map<String, dynamic> _$SimulatedOrderFillToJson(SimulatedOrderFill instance) =>
    <String, dynamic>{
      'filled_at': instance.filledAt.toIso8601String(),
      'price': instance.price.toJson(),
      'quantity': instance.quantity.toJson(),
    };
