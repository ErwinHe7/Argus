// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'investor_profile.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$InvestorProfileCWProxy {
  InvestorProfile contributionRhythm(
    InvestorProfileContributionRhythmEnum? contributionRhythm,
  );

  InvestorProfile goalType(InvestorProfileGoalTypeEnum goalType);

  InvestorProfile investingExperience(
    InvestorProfileInvestingExperienceEnum? investingExperience,
  );

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
    InvestorProfileContributionRhythmEnum? contributionRhythm,
    InvestorProfileGoalTypeEnum goalType,
    InvestorProfileInvestingExperienceEnum? investingExperience,
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
  InvestorProfile contributionRhythm(
    InvestorProfileContributionRhythmEnum? contributionRhythm,
  ) => this(contributionRhythm: contributionRhythm);

  @override
  InvestorProfile goalType(InvestorProfileGoalTypeEnum goalType) =>
      this(goalType: goalType);

  @override
  InvestorProfile investingExperience(
    InvestorProfileInvestingExperienceEnum? investingExperience,
  ) => this(investingExperience: investingExperience);

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
    Object? contributionRhythm = const $CopyWithPlaceholder(),
    Object? goalType = const $CopyWithPlaceholder(),
    Object? investingExperience = const $CopyWithPlaceholder(),
    Object? isDemo = const $CopyWithPlaceholder(),
    Object? riskComfort = const $CopyWithPlaceholder(),
    Object? timeHorizon = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return InvestorProfile(
      contributionRhythm: contributionRhythm == const $CopyWithPlaceholder()
          ? _value.contributionRhythm
          // ignore: cast_nullable_to_non_nullable
          : contributionRhythm as InvestorProfileContributionRhythmEnum?,
      goalType: goalType == const $CopyWithPlaceholder()
          ? _value.goalType
          // ignore: cast_nullable_to_non_nullable
          : goalType as InvestorProfileGoalTypeEnum,
      investingExperience: investingExperience == const $CopyWithPlaceholder()
          ? _value.investingExperience
          // ignore: cast_nullable_to_non_nullable
          : investingExperience as InvestorProfileInvestingExperienceEnum?,
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
        'contribution_rhythm',
        'goal_type',
        'investing_experience',
        'is_demo',
        'risk_comfort',
        'time_horizon',
        'version',
      ],
    );
    final val = InvestorProfile(
      contributionRhythm: $checkedConvert(
        'contribution_rhythm',
        (v) => $enumDecodeNullable(
          _$InvestorProfileContributionRhythmEnumEnumMap,
          v,
          unknownValue:
              InvestorProfileContributionRhythmEnum.unknownDefaultOpenApi,
        ),
      ),
      goalType: $checkedConvert(
        'goal_type',
        (v) => $enumDecode(
          _$InvestorProfileGoalTypeEnumEnumMap,
          v,
          unknownValue: InvestorProfileGoalTypeEnum.unknownDefaultOpenApi,
        ),
      ),
      investingExperience: $checkedConvert(
        'investing_experience',
        (v) => $enumDecodeNullable(
          _$InvestorProfileInvestingExperienceEnumEnumMap,
          v,
          unknownValue:
              InvestorProfileInvestingExperienceEnum.unknownDefaultOpenApi,
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
    'contributionRhythm': 'contribution_rhythm',
    'goalType': 'goal_type',
    'investingExperience': 'investing_experience',
    'isDemo': 'is_demo',
    'riskComfort': 'risk_comfort',
    'timeHorizon': 'time_horizon',
  },
);

Map<String, dynamic> _$InvestorProfileToJson(InvestorProfile instance) =>
    <String, dynamic>{
      'contribution_rhythm':
          _$InvestorProfileContributionRhythmEnumEnumMap[instance
              .contributionRhythm],
      'goal_type': _$InvestorProfileGoalTypeEnumEnumMap[instance.goalType]!,
      'investing_experience':
          _$InvestorProfileInvestingExperienceEnumEnumMap[instance
              .investingExperience],
      'is_demo': instance.isDemo,
      'risk_comfort':
          _$InvestorProfileRiskComfortEnumEnumMap[instance.riskComfort]!,
      'time_horizon':
          _$InvestorProfileTimeHorizonEnumEnumMap[instance.timeHorizon]!,
      'version': instance.version,
    };

const _$InvestorProfileContributionRhythmEnumEnumMap = {
  InvestorProfileContributionRhythmEnum.weekly: 'weekly',
  InvestorProfileContributionRhythmEnum.biweekly: 'biweekly',
  InvestorProfileContributionRhythmEnum.monthly: 'monthly',
  InvestorProfileContributionRhythmEnum.irregular: 'irregular',
  InvestorProfileContributionRhythmEnum.notSure: 'not_sure',
  InvestorProfileContributionRhythmEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$InvestorProfileGoalTypeEnumEnumMap = {
  InvestorProfileGoalTypeEnum.calmFund: 'calm_fund',
  InvestorProfileGoalTypeEnum.longTermGrowth: 'long_term_growth',
  InvestorProfileGoalTypeEnum.income: 'income',
  InvestorProfileGoalTypeEnum.exploration: 'exploration',
  InvestorProfileGoalTypeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$InvestorProfileInvestingExperienceEnumEnumMap = {
  InvestorProfileInvestingExperienceEnum.new_: 'new',
  InvestorProfileInvestingExperienceEnum.someExperience: 'some_experience',
  InvestorProfileInvestingExperienceEnum.experienced: 'experienced',
  InvestorProfileInvestingExperienceEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
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
