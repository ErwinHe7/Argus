// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'input_money.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$InputMoneyCWProxy {
  InputMoney currency(InputMoneyCurrencyEnum currency);

  InputMoney minorUnits(int minorUnits);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `InputMoney(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// InputMoney(...).copyWith(id: 12, name: "My name")
  /// ````
  InputMoney call({InputMoneyCurrencyEnum currency, int minorUnits});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfInputMoney.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfInputMoney.copyWith.fieldName(...)`
class _$InputMoneyCWProxyImpl implements _$InputMoneyCWProxy {
  const _$InputMoneyCWProxyImpl(this._value);

  final InputMoney _value;

  @override
  InputMoney currency(InputMoneyCurrencyEnum currency) =>
      this(currency: currency);

  @override
  InputMoney minorUnits(int minorUnits) => this(minorUnits: minorUnits);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `InputMoney(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// InputMoney(...).copyWith(id: 12, name: "My name")
  /// ````
  InputMoney call({
    Object? currency = const $CopyWithPlaceholder(),
    Object? minorUnits = const $CopyWithPlaceholder(),
  }) {
    return InputMoney(
      currency: currency == const $CopyWithPlaceholder()
          ? _value.currency
          // ignore: cast_nullable_to_non_nullable
          : currency as InputMoneyCurrencyEnum,
      minorUnits: minorUnits == const $CopyWithPlaceholder()
          ? _value.minorUnits
          // ignore: cast_nullable_to_non_nullable
          : minorUnits as int,
    );
  }
}

extension $InputMoneyCopyWith on InputMoney {
  /// Returns a callable class that can be used as follows: `instanceOfInputMoney.copyWith(...)` or like so:`instanceOfInputMoney.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$InputMoneyCWProxy get copyWith => _$InputMoneyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InputMoney _$InputMoneyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('InputMoney', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['currency', 'minor_units']);
      final val = InputMoney(
        currency: $checkedConvert(
          'currency',
          (v) => $enumDecode(
            _$InputMoneyCurrencyEnumEnumMap,
            v,
            unknownValue: InputMoneyCurrencyEnum.unknownDefaultOpenApi,
          ),
        ),
        minorUnits: $checkedConvert('minor_units', (v) => (v as num).toInt()),
      );
      return val;
    }, fieldKeyMap: const {'minorUnits': 'minor_units'});

Map<String, dynamic> _$InputMoneyToJson(InputMoney instance) =>
    <String, dynamic>{
      'currency': _$InputMoneyCurrencyEnumEnumMap[instance.currency]!,
      'minor_units': instance.minorUnits,
    };

const _$InputMoneyCurrencyEnumEnumMap = {
  InputMoneyCurrencyEnum.USD: 'USD',
  InputMoneyCurrencyEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
