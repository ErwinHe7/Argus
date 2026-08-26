// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_intention_request_target.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateIntentionRequestTargetCWProxy {
  CreateIntentionRequestTarget currency(
    CreateIntentionRequestTargetCurrencyEnum currency,
  );

  CreateIntentionRequestTarget minorUnits(int minorUnits);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateIntentionRequestTarget(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateIntentionRequestTarget(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateIntentionRequestTarget call({
    CreateIntentionRequestTargetCurrencyEnum currency,
    int minorUnits,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateIntentionRequestTarget.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateIntentionRequestTarget.copyWith.fieldName(...)`
class _$CreateIntentionRequestTargetCWProxyImpl
    implements _$CreateIntentionRequestTargetCWProxy {
  const _$CreateIntentionRequestTargetCWProxyImpl(this._value);

  final CreateIntentionRequestTarget _value;

  @override
  CreateIntentionRequestTarget currency(
    CreateIntentionRequestTargetCurrencyEnum currency,
  ) => this(currency: currency);

  @override
  CreateIntentionRequestTarget minorUnits(int minorUnits) =>
      this(minorUnits: minorUnits);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateIntentionRequestTarget(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateIntentionRequestTarget(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateIntentionRequestTarget call({
    Object? currency = const $CopyWithPlaceholder(),
    Object? minorUnits = const $CopyWithPlaceholder(),
  }) {
    return CreateIntentionRequestTarget(
      currency: currency == const $CopyWithPlaceholder()
          ? _value.currency
          // ignore: cast_nullable_to_non_nullable
          : currency as CreateIntentionRequestTargetCurrencyEnum,
      minorUnits: minorUnits == const $CopyWithPlaceholder()
          ? _value.minorUnits
          // ignore: cast_nullable_to_non_nullable
          : minorUnits as int,
    );
  }
}

extension $CreateIntentionRequestTargetCopyWith
    on CreateIntentionRequestTarget {
  /// Returns a callable class that can be used as follows: `instanceOfCreateIntentionRequestTarget.copyWith(...)` or like so:`instanceOfCreateIntentionRequestTarget.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateIntentionRequestTargetCWProxy get copyWith =>
      _$CreateIntentionRequestTargetCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateIntentionRequestTarget _$CreateIntentionRequestTargetFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateIntentionRequestTarget', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['currency', 'minor_units']);
  final val = CreateIntentionRequestTarget(
    currency: $checkedConvert(
      'currency',
      (v) => $enumDecode(
        _$CreateIntentionRequestTargetCurrencyEnumEnumMap,
        v,
        unknownValue:
            CreateIntentionRequestTargetCurrencyEnum.unknownDefaultOpenApi,
      ),
    ),
    minorUnits: $checkedConvert('minor_units', (v) => (v as num).toInt()),
  );
  return val;
}, fieldKeyMap: const {'minorUnits': 'minor_units'});

Map<String, dynamic> _$CreateIntentionRequestTargetToJson(
  CreateIntentionRequestTarget instance,
) => <String, dynamic>{
  'currency':
      _$CreateIntentionRequestTargetCurrencyEnumEnumMap[instance.currency]!,
  'minor_units': instance.minorUnits,
};

const _$CreateIntentionRequestTargetCurrencyEnumEnumMap = {
  CreateIntentionRequestTargetCurrencyEnum.USD: 'USD',
  CreateIntentionRequestTargetCurrencyEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
