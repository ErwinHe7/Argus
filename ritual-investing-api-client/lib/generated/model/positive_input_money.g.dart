// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'positive_input_money.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PositiveInputMoneyCWProxy {
  PositiveInputMoney currency(PositiveInputMoneyCurrencyEnum currency);

  PositiveInputMoney minorUnits(int minorUnits);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PositiveInputMoney(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PositiveInputMoney(...).copyWith(id: 12, name: "My name")
  /// ````
  PositiveInputMoney call({
    PositiveInputMoneyCurrencyEnum currency,
    int minorUnits,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPositiveInputMoney.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPositiveInputMoney.copyWith.fieldName(...)`
class _$PositiveInputMoneyCWProxyImpl implements _$PositiveInputMoneyCWProxy {
  const _$PositiveInputMoneyCWProxyImpl(this._value);

  final PositiveInputMoney _value;

  @override
  PositiveInputMoney currency(PositiveInputMoneyCurrencyEnum currency) =>
      this(currency: currency);

  @override
  PositiveInputMoney minorUnits(int minorUnits) => this(minorUnits: minorUnits);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PositiveInputMoney(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PositiveInputMoney(...).copyWith(id: 12, name: "My name")
  /// ````
  PositiveInputMoney call({
    Object? currency = const $CopyWithPlaceholder(),
    Object? minorUnits = const $CopyWithPlaceholder(),
  }) {
    return PositiveInputMoney(
      currency: currency == const $CopyWithPlaceholder()
          ? _value.currency
          // ignore: cast_nullable_to_non_nullable
          : currency as PositiveInputMoneyCurrencyEnum,
      minorUnits: minorUnits == const $CopyWithPlaceholder()
          ? _value.minorUnits
          // ignore: cast_nullable_to_non_nullable
          : minorUnits as int,
    );
  }
}

extension $PositiveInputMoneyCopyWith on PositiveInputMoney {
  /// Returns a callable class that can be used as follows: `instanceOfPositiveInputMoney.copyWith(...)` or like so:`instanceOfPositiveInputMoney.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PositiveInputMoneyCWProxy get copyWith =>
      _$PositiveInputMoneyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PositiveInputMoney _$PositiveInputMoneyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PositiveInputMoney', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['currency', 'minor_units']);
      final val = PositiveInputMoney(
        currency: $checkedConvert(
          'currency',
          (v) => $enumDecode(
            _$PositiveInputMoneyCurrencyEnumEnumMap,
            v,
            unknownValue: PositiveInputMoneyCurrencyEnum.unknownDefaultOpenApi,
          ),
        ),
        minorUnits: $checkedConvert('minor_units', (v) => (v as num).toInt()),
      );
      return val;
    }, fieldKeyMap: const {'minorUnits': 'minor_units'});

Map<String, dynamic> _$PositiveInputMoneyToJson(PositiveInputMoney instance) =>
    <String, dynamic>{
      'currency': _$PositiveInputMoneyCurrencyEnumEnumMap[instance.currency]!,
      'minor_units': instance.minorUnits,
    };

const _$PositiveInputMoneyCurrencyEnumEnumMap = {
  PositiveInputMoneyCurrencyEnum.USD: 'USD',
  PositiveInputMoneyCurrencyEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
