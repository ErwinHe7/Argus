// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quantity.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$QuantityCWProxy {
  Quantity scale(int scale);

  Quantity value(String value);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Quantity(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Quantity(...).copyWith(id: 12, name: "My name")
  /// ````
  Quantity call({int scale, String value});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfQuantity.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfQuantity.copyWith.fieldName(...)`
class _$QuantityCWProxyImpl implements _$QuantityCWProxy {
  const _$QuantityCWProxyImpl(this._value);

  final Quantity _value;

  @override
  Quantity scale(int scale) => this(scale: scale);

  @override
  Quantity value(String value) => this(value: value);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Quantity(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Quantity(...).copyWith(id: 12, name: "My name")
  /// ````
  Quantity call({
    Object? scale = const $CopyWithPlaceholder(),
    Object? value = const $CopyWithPlaceholder(),
  }) {
    return Quantity(
      scale: scale == const $CopyWithPlaceholder()
          ? _value.scale
          // ignore: cast_nullable_to_non_nullable
          : scale as int,
      value: value == const $CopyWithPlaceholder()
          ? _value.value
          // ignore: cast_nullable_to_non_nullable
          : value as String,
    );
  }
}

extension $QuantityCopyWith on Quantity {
  /// Returns a callable class that can be used as follows: `instanceOfQuantity.copyWith(...)` or like so:`instanceOfQuantity.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$QuantityCWProxy get copyWith => _$QuantityCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Quantity _$QuantityFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Quantity', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['scale', 'value']);
      final val = Quantity(
        scale: $checkedConvert('scale', (v) => (v as num).toInt()),
        value: $checkedConvert('value', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$QuantityToJson(Quantity instance) => <String, dynamic>{
  'scale': instance.scale,
  'value': instance.value,
};
