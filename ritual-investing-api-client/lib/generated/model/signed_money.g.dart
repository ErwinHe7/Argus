// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'signed_money.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SignedMoneyCWProxy {
  SignedMoney currency(SignedMoneyCurrencyEnum currency);

  SignedMoney minorUnits(int minorUnits);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SignedMoney(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SignedMoney(...).copyWith(id: 12, name: "My name")
  /// ````
  SignedMoney call({SignedMoneyCurrencyEnum currency, int minorUnits});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSignedMoney.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSignedMoney.copyWith.fieldName(...)`
class _$SignedMoneyCWProxyImpl implements _$SignedMoneyCWProxy {
  const _$SignedMoneyCWProxyImpl(this._value);

  final SignedMoney _value;

  @override
  SignedMoney currency(SignedMoneyCurrencyEnum currency) =>
      this(currency: currency);

  @override
  SignedMoney minorUnits(int minorUnits) => this(minorUnits: minorUnits);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SignedMoney(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SignedMoney(...).copyWith(id: 12, name: "My name")
  /// ````
  SignedMoney call({
    Object? currency = const $CopyWithPlaceholder(),
    Object? minorUnits = const $CopyWithPlaceholder(),
  }) {
    return SignedMoney(
      currency: currency == const $CopyWithPlaceholder()
          ? _value.currency
          // ignore: cast_nullable_to_non_nullable
          : currency as SignedMoneyCurrencyEnum,
      minorUnits: minorUnits == const $CopyWithPlaceholder()
          ? _value.minorUnits
          // ignore: cast_nullable_to_non_nullable
          : minorUnits as int,
    );
  }
}

extension $SignedMoneyCopyWith on SignedMoney {
  /// Returns a callable class that can be used as follows: `instanceOfSignedMoney.copyWith(...)` or like so:`instanceOfSignedMoney.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SignedMoneyCWProxy get copyWith => _$SignedMoneyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SignedMoney _$SignedMoneyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SignedMoney', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['currency', 'minor_units']);
      final val = SignedMoney(
        currency: $checkedConvert(
          'currency',
          (v) => $enumDecode(
            _$SignedMoneyCurrencyEnumEnumMap,
            v,
            unknownValue: SignedMoneyCurrencyEnum.unknownDefaultOpenApi,
          ),
        ),
        minorUnits: $checkedConvert('minor_units', (v) => (v as num).toInt()),
      );
      return val;
    }, fieldKeyMap: const {'minorUnits': 'minor_units'});

Map<String, dynamic> _$SignedMoneyToJson(SignedMoney instance) =>
    <String, dynamic>{
      'currency': _$SignedMoneyCurrencyEnumEnumMap[instance.currency]!,
      'minor_units': instance.minorUnits,
    };

const _$SignedMoneyCurrencyEnumEnumMap = {
  SignedMoneyCurrencyEnum.USD: 'USD',
  SignedMoneyCurrencyEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
