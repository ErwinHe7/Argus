// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'demo_funding_source.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DemoFundingSourceCWProxy {
  DemoFundingSource demo(SimulationDemoDisclosure demo);

  DemoFundingSource displayLabel(String displayLabel);

  DemoFundingSource fictionalLast4(String fictionalLast4);

  DemoFundingSource fixtureKey(DemoFundingSourceFixtureKeyEnum fixtureKey);

  DemoFundingSource id(String id);

  DemoFundingSource status(DemoFundingSourceStatusEnum status);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DemoFundingSource(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DemoFundingSource(...).copyWith(id: 12, name: "My name")
  /// ````
  DemoFundingSource call({
    SimulationDemoDisclosure demo,
    String displayLabel,
    String fictionalLast4,
    DemoFundingSourceFixtureKeyEnum fixtureKey,
    String id,
    DemoFundingSourceStatusEnum status,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDemoFundingSource.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDemoFundingSource.copyWith.fieldName(...)`
class _$DemoFundingSourceCWProxyImpl implements _$DemoFundingSourceCWProxy {
  const _$DemoFundingSourceCWProxyImpl(this._value);

  final DemoFundingSource _value;

  @override
  DemoFundingSource demo(SimulationDemoDisclosure demo) => this(demo: demo);

  @override
  DemoFundingSource displayLabel(String displayLabel) =>
      this(displayLabel: displayLabel);

  @override
  DemoFundingSource fictionalLast4(String fictionalLast4) =>
      this(fictionalLast4: fictionalLast4);

  @override
  DemoFundingSource fixtureKey(DemoFundingSourceFixtureKeyEnum fixtureKey) =>
      this(fixtureKey: fixtureKey);

  @override
  DemoFundingSource id(String id) => this(id: id);

  @override
  DemoFundingSource status(DemoFundingSourceStatusEnum status) =>
      this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DemoFundingSource(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DemoFundingSource(...).copyWith(id: 12, name: "My name")
  /// ````
  DemoFundingSource call({
    Object? demo = const $CopyWithPlaceholder(),
    Object? displayLabel = const $CopyWithPlaceholder(),
    Object? fictionalLast4 = const $CopyWithPlaceholder(),
    Object? fixtureKey = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return DemoFundingSource(
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as SimulationDemoDisclosure,
      displayLabel: displayLabel == const $CopyWithPlaceholder()
          ? _value.displayLabel
          // ignore: cast_nullable_to_non_nullable
          : displayLabel as String,
      fictionalLast4: fictionalLast4 == const $CopyWithPlaceholder()
          ? _value.fictionalLast4
          // ignore: cast_nullable_to_non_nullable
          : fictionalLast4 as String,
      fixtureKey: fixtureKey == const $CopyWithPlaceholder()
          ? _value.fixtureKey
          // ignore: cast_nullable_to_non_nullable
          : fixtureKey as DemoFundingSourceFixtureKeyEnum,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as DemoFundingSourceStatusEnum,
    );
  }
}

extension $DemoFundingSourceCopyWith on DemoFundingSource {
  /// Returns a callable class that can be used as follows: `instanceOfDemoFundingSource.copyWith(...)` or like so:`instanceOfDemoFundingSource.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DemoFundingSourceCWProxy get copyWith =>
      _$DemoFundingSourceCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DemoFundingSource _$DemoFundingSourceFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'DemoFundingSource',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'demo',
        'display_label',
        'fictional_last4',
        'fixture_key',
        'id',
        'status',
      ],
    );
    final val = DemoFundingSource(
      demo: $checkedConvert(
        'demo',
        (v) => SimulationDemoDisclosure.fromJson(v as Map<String, dynamic>),
      ),
      displayLabel: $checkedConvert('display_label', (v) => v as String),
      fictionalLast4: $checkedConvert('fictional_last4', (v) => v as String),
      fixtureKey: $checkedConvert(
        'fixture_key',
        (v) => $enumDecode(
          _$DemoFundingSourceFixtureKeyEnumEnumMap,
          v,
          unknownValue: DemoFundingSourceFixtureKeyEnum.unknownDefaultOpenApi,
        ),
      ),
      id: $checkedConvert('id', (v) => v as String),
      status: $checkedConvert(
        'status',
        (v) => $enumDecode(
          _$DemoFundingSourceStatusEnumEnumMap,
          v,
          unknownValue: DemoFundingSourceStatusEnum.unknownDefaultOpenApi,
        ),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'displayLabel': 'display_label',
    'fictionalLast4': 'fictional_last4',
    'fixtureKey': 'fixture_key',
  },
);

Map<String, dynamic> _$DemoFundingSourceToJson(
  DemoFundingSource instance,
) => <String, dynamic>{
  'demo': instance.demo.toJson(),
  'display_label': instance.displayLabel,
  'fictional_last4': instance.fictionalLast4,
  'fixture_key': _$DemoFundingSourceFixtureKeyEnumEnumMap[instance.fixtureKey]!,
  'id': instance.id,
  'status': _$DemoFundingSourceStatusEnumEnumMap[instance.status]!,
};

const _$DemoFundingSourceFixtureKeyEnumEnumMap = {
  DemoFundingSourceFixtureKeyEnum.moonReserve: 'moon_reserve',
  DemoFundingSourceFixtureKeyEnum.constellationSavings: 'constellation_savings',
  DemoFundingSourceFixtureKeyEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$DemoFundingSourceStatusEnumEnumMap = {
  DemoFundingSourceStatusEnum.active: 'active',
  DemoFundingSourceStatusEnum.inactive: 'inactive',
  DemoFundingSourceStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
