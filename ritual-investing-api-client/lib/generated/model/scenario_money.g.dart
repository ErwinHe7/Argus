// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scenario_money.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ScenarioMoneyCWProxy {
  ScenarioMoney currency(String currency);

  ScenarioMoney minorUnits(String minorUnits);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ScenarioMoney(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ScenarioMoney(...).copyWith(id: 12, name: "My name")
  /// ````
  ScenarioMoney call({String currency, String minorUnits});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfScenarioMoney.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfScenarioMoney.copyWith.fieldName(...)`
class _$ScenarioMoneyCWProxyImpl implements _$ScenarioMoneyCWProxy {
  const _$ScenarioMoneyCWProxyImpl(this._value);

  final ScenarioMoney _value;

  @override
  ScenarioMoney currency(String currency) => this(currency: currency);

  @override
  ScenarioMoney minorUnits(String minorUnits) => this(minorUnits: minorUnits);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ScenarioMoney(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ScenarioMoney(...).copyWith(id: 12, name: "My name")
  /// ````
  ScenarioMoney call({
    Object? currency = const $CopyWithPlaceholder(),
    Object? minorUnits = const $CopyWithPlaceholder(),
  }) {
    return ScenarioMoney(
      currency: currency == const $CopyWithPlaceholder()
          ? _value.currency
          // ignore: cast_nullable_to_non_nullable
          : currency as String,
      minorUnits: minorUnits == const $CopyWithPlaceholder()
          ? _value.minorUnits
          // ignore: cast_nullable_to_non_nullable
          : minorUnits as String,
    );
  }
}

extension $ScenarioMoneyCopyWith on ScenarioMoney {
  /// Returns a callable class that can be used as follows: `instanceOfScenarioMoney.copyWith(...)` or like so:`instanceOfScenarioMoney.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ScenarioMoneyCWProxy get copyWith => _$ScenarioMoneyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScenarioMoney _$ScenarioMoneyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ScenarioMoney', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['currency', 'minor_units']);
      final val = ScenarioMoney(
        currency: $checkedConvert('currency', (v) => v as String),
        minorUnits: $checkedConvert('minor_units', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'minorUnits': 'minor_units'});

Map<String, dynamic> _$ScenarioMoneyToJson(ScenarioMoney instance) =>
    <String, dynamic>{
      'currency': instance.currency,
      'minor_units': instance.minorUnits,
    };
