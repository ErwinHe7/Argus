// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'modify_brokerage_order_intent.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ModifyBrokerageOrderIntentCWProxy {
  ModifyBrokerageOrderIntent limitPrice(String? limitPrice);

  ModifyBrokerageOrderIntent quantity(String quantity);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ModifyBrokerageOrderIntent(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ModifyBrokerageOrderIntent(...).copyWith(id: 12, name: "My name")
  /// ````
  ModifyBrokerageOrderIntent call({String? limitPrice, String quantity});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfModifyBrokerageOrderIntent.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfModifyBrokerageOrderIntent.copyWith.fieldName(...)`
class _$ModifyBrokerageOrderIntentCWProxyImpl
    implements _$ModifyBrokerageOrderIntentCWProxy {
  const _$ModifyBrokerageOrderIntentCWProxyImpl(this._value);

  final ModifyBrokerageOrderIntent _value;

  @override
  ModifyBrokerageOrderIntent limitPrice(String? limitPrice) =>
      this(limitPrice: limitPrice);

  @override
  ModifyBrokerageOrderIntent quantity(String quantity) =>
      this(quantity: quantity);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ModifyBrokerageOrderIntent(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ModifyBrokerageOrderIntent(...).copyWith(id: 12, name: "My name")
  /// ````
  ModifyBrokerageOrderIntent call({
    Object? limitPrice = const $CopyWithPlaceholder(),
    Object? quantity = const $CopyWithPlaceholder(),
  }) {
    return ModifyBrokerageOrderIntent(
      limitPrice: limitPrice == const $CopyWithPlaceholder()
          ? _value.limitPrice
          // ignore: cast_nullable_to_non_nullable
          : limitPrice as String?,
      quantity: quantity == const $CopyWithPlaceholder()
          ? _value.quantity
          // ignore: cast_nullable_to_non_nullable
          : quantity as String,
    );
  }
}

extension $ModifyBrokerageOrderIntentCopyWith on ModifyBrokerageOrderIntent {
  /// Returns a callable class that can be used as follows: `instanceOfModifyBrokerageOrderIntent.copyWith(...)` or like so:`instanceOfModifyBrokerageOrderIntent.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ModifyBrokerageOrderIntentCWProxy get copyWith =>
      _$ModifyBrokerageOrderIntentCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ModifyBrokerageOrderIntent _$ModifyBrokerageOrderIntentFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ModifyBrokerageOrderIntent', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['limit_price', 'quantity']);
  final val = ModifyBrokerageOrderIntent(
    limitPrice: $checkedConvert('limit_price', (v) => v as String?),
    quantity: $checkedConvert('quantity', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'limitPrice': 'limit_price'});

Map<String, dynamic> _$ModifyBrokerageOrderIntentToJson(
  ModifyBrokerageOrderIntent instance,
) => <String, dynamic>{
  'limit_price': instance.limitPrice,
  'quantity': instance.quantity,
};
