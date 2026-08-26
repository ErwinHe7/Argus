// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'money.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MoneyCWProxy {
  Money currency(MoneyCurrencyEnum currency);

  Money minorUnits(int minorUnits);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Money(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Money(...).copyWith(id: 12, name: "My name")
  /// ````
  Money call({MoneyCurrencyEnum currency, int minorUnits});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMoney.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMoney.copyWith.fieldName(...)`
class _$MoneyCWProxyImpl implements _$MoneyCWProxy {
  const _$MoneyCWProxyImpl(this._value);

  final Money _value;

  @override
  Money currency(MoneyCurrencyEnum currency) => this(currency: currency);

  @override
  Money minorUnits(int minorUnits) => this(minorUnits: minorUnits);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Money(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Money(...).copyWith(id: 12, name: "My name")
  /// ````
  Money call({
    Object? currency = const $CopyWithPlaceholder(),
    Object? minorUnits = const $CopyWithPlaceholder(),
  }) {
    return Money(
      currency: currency == const $CopyWithPlaceholder()
          ? _value.currency
          // ignore: cast_nullable_to_non_nullable
          : currency as MoneyCurrencyEnum,
      minorUnits: minorUnits == const $CopyWithPlaceholder()
          ? _value.minorUnits
          // ignore: cast_nullable_to_non_nullable
          : minorUnits as int,
    );
  }
}

extension $MoneyCopyWith on Money {
  /// Returns a callable class that can be used as follows: `instanceOfMoney.copyWith(...)` or like so:`instanceOfMoney.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MoneyCWProxy get copyWith => _$MoneyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Money _$MoneyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Money', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['currency', 'minor_units']);
      final val = Money(
        currency: $checkedConvert(
          'currency',
          (v) => $enumDecode(
            _$MoneyCurrencyEnumEnumMap,
            v,
            unknownValue: MoneyCurrencyEnum.unknownDefaultOpenApi,
          ),
        ),
        minorUnits: $checkedConvert('minor_units', (v) => (v as num).toInt()),
      );
      return val;
    }, fieldKeyMap: const {'minorUnits': 'minor_units'});

Map<String, dynamic> _$MoneyToJson(Money instance) => <String, dynamic>{
  'currency': _$MoneyCurrencyEnumEnumMap[instance.currency]!,
  'minor_units': instance.minorUnits,
};

const _$MoneyCurrencyEnumEnumMap = {
  MoneyCurrencyEnum.USD: 'USD',
  MoneyCurrencyEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
