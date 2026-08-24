// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'investor_profile.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$InvestorProfileCWProxy {
  InvestorProfile goalType(InvestorProfileGoalTypeEnum goalType);

  InvestorProfile isDemo(bool isDemo);

  InvestorProfile riskComfort(InvestorProfileRiskComfortEnum riskComfort);

  InvestorProfile timeHorizon(InvestorProfileTimeHorizonEnum timeHorizon);

  InvestorProfile version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `InvestorProfile(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// InvestorProfile(...).copyWith(id: 12, name: "My name")
  /// ````
  InvestorProfile call({
    InvestorProfileGoalTypeEnum goalType,
    bool isDemo,
    InvestorProfileRiskComfortEnum riskComfort,
    InvestorProfileTimeHorizonEnum timeHorizon,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfInvestorProfile.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfInvestorProfile.copyWith.fieldName(...)`
class _$InvestorProfileCWProxyImpl implements _$InvestorProfileCWProxy {
  const _$InvestorProfileCWProxyImpl(this._value);

  final InvestorProfile _value;

  @override
  InvestorProfile goalType(InvestorProfileGoalTypeEnum goalType) =>
      this(goalType: goalType);

  @override
  InvestorProfile isDemo(bool isDemo) => this(isDemo: isDemo);

  @override
  InvestorProfile riskComfort(InvestorProfileRiskComfortEnum riskComfort) =>
      this(riskComfort: riskComfort);

  @override
  InvestorProfile timeHorizon(InvestorProfileTimeHorizonEnum timeHorizon) =>
      this(timeHorizon: timeHorizon);

  @override
  InvestorProfile version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `InvestorProfile(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// InvestorProfile(...).copyWith(id: 12, name: "My name")
  /// ````
  InvestorProfile call({
    Object? goalType = const $CopyWithPlaceholder(),
    Object? isDemo = const $CopyWithPlaceholder(),
    Object? riskComfort = const $CopyWithPlaceholder(),
    Object? timeHorizon = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return InvestorProfile(
      goalType: goalType == const $CopyWithPlaceholder()
          ? _value.goalType
          // ignore: cast_nullable_to_non_nullable
          : goalType as InvestorProfileGoalTypeEnum,
      isDemo: isDemo == const $CopyWithPlaceholder()
          ? _value.isDemo
          // ignore: cast_nullable_to_non_nullable
          : isDemo as bool,
      riskComfort: riskComfort == const $CopyWithPlaceholder()
          ? _value.riskComfort
          // ignore: cast_nullable_to_non_nullable
          : riskComfort as InvestorProfileRiskComfortEnum,
      timeHorizon: timeHorizon == const $CopyWithPlaceholder()
          ? _value.timeHorizon
          // ignore: cast_nullable_to_non_nullable
          : timeHorizon as InvestorProfileTimeHorizonEnum,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $InvestorProfileCopyWith on InvestorProfile {
  /// Returns a callable class that can be used as follows: `instanceOfInvestorProfile.copyWith(...)` or like so:`instanceOfInvestorProfile.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$InvestorProfileCWProxy get copyWith => _$InvestorProfileCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InvestorProfile _$InvestorProfileFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'InvestorProfile',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'goal_type',
        'is_demo',
        'risk_comfort',
        'time_horizon',
        'version',
      ],
    );
    final val = InvestorProfile(
      goalType: $checkedConvert(
        'goal_type',
        (v) => $enumDecode(
          _$InvestorProfileGoalTypeEnumEnumMap,
          v,
          unknownValue: InvestorProfileGoalTypeEnum.unknownDefaultOpenApi,
        ),
      ),
      isDemo: $checkedConvert('is_demo', (v) => v as bool),
      riskComfort: $checkedConvert(
        'risk_comfort',
        (v) => $enumDecode(
          _$InvestorProfileRiskComfortEnumEnumMap,
          v,
          unknownValue: InvestorProfileRiskComfortEnum.unknownDefaultOpenApi,
        ),
      ),
      timeHorizon: $checkedConvert(
        'time_horizon',
        (v) => $enumDecode(
          _$InvestorProfileTimeHorizonEnumEnumMap,
          v,
          unknownValue: InvestorProfileTimeHorizonEnum.unknownDefaultOpenApi,
        ),
      ),
      version: $checkedConvert('version', (v) => (v as num).toInt()),
    );
    return val;
  },
  fieldKeyMap: const {
    'goalType': 'goal_type',
    'isDemo': 'is_demo',
    'riskComfort': 'risk_comfort',
    'timeHorizon': 'time_horizon',
  },
);

Map<String, dynamic> _$InvestorProfileToJson(InvestorProfile instance) =>
    <String, dynamic>{
      'goal_type': _$InvestorProfileGoalTypeEnumEnumMap[instance.goalType]!,
      'is_demo': instance.isDemo,
      'risk_comfort':
          _$InvestorProfileRiskComfortEnumEnumMap[instance.riskComfort]!,
      'time_horizon':
          _$InvestorProfileTimeHorizonEnumEnumMap[instance.timeHorizon]!,
      'version': instance.version,
    };

const _$InvestorProfileGoalTypeEnumEnumMap = {
  InvestorProfileGoalTypeEnum.calmFund: 'calm_fund',
  InvestorProfileGoalTypeEnum.longTermGrowth: 'long_term_growth',
  InvestorProfileGoalTypeEnum.income: 'income',
  InvestorProfileGoalTypeEnum.exploration: 'exploration',
  InvestorProfileGoalTypeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$InvestorProfileRiskComfortEnumEnumMap = {
  InvestorProfileRiskComfortEnum.low: 'low',
  InvestorProfileRiskComfortEnum.moderate: 'moderate',
  InvestorProfileRiskComfortEnum.high: 'high',
  InvestorProfileRiskComfortEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$InvestorProfileTimeHorizonEnumEnumMap = {
  InvestorProfileTimeHorizonEnum.short: 'short',
  InvestorProfileTimeHorizonEnum.medium: 'medium',
  InvestorProfileTimeHorizonEnum.long: 'long',
  InvestorProfileTimeHorizonEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
