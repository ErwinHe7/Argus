// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_bootstrap_investor_profile.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SessionBootstrapInvestorProfileCWProxy {
  SessionBootstrapInvestorProfile contributionRhythm(
    SessionBootstrapInvestorProfileContributionRhythmEnum contributionRhythm,
  );

  SessionBootstrapInvestorProfile experience(
    SessionBootstrapInvestorProfileExperienceEnum experience,
  );

  SessionBootstrapInvestorProfile goalType(
    SessionBootstrapInvestorProfileGoalTypeEnum goalType,
  );

  SessionBootstrapInvestorProfile isDemo(bool isDemo);

  SessionBootstrapInvestorProfile riskComfort(
    SessionBootstrapInvestorProfileRiskComfortEnum riskComfort,
  );

  SessionBootstrapInvestorProfile timeHorizon(
    SessionBootstrapInvestorProfileTimeHorizonEnum timeHorizon,
  );

  SessionBootstrapInvestorProfile version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionBootstrapInvestorProfile(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionBootstrapInvestorProfile(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionBootstrapInvestorProfile call({
    SessionBootstrapInvestorProfileContributionRhythmEnum contributionRhythm,
    SessionBootstrapInvestorProfileExperienceEnum experience,
    SessionBootstrapInvestorProfileGoalTypeEnum goalType,
    bool isDemo,
    SessionBootstrapInvestorProfileRiskComfortEnum riskComfort,
    SessionBootstrapInvestorProfileTimeHorizonEnum timeHorizon,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSessionBootstrapInvestorProfile.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSessionBootstrapInvestorProfile.copyWith.fieldName(...)`
class _$SessionBootstrapInvestorProfileCWProxyImpl
    implements _$SessionBootstrapInvestorProfileCWProxy {
  const _$SessionBootstrapInvestorProfileCWProxyImpl(this._value);

  final SessionBootstrapInvestorProfile _value;

  @override
  SessionBootstrapInvestorProfile contributionRhythm(
    SessionBootstrapInvestorProfileContributionRhythmEnum contributionRhythm,
  ) => this(contributionRhythm: contributionRhythm);

  @override
  SessionBootstrapInvestorProfile experience(
    SessionBootstrapInvestorProfileExperienceEnum experience,
  ) => this(experience: experience);

  @override
  SessionBootstrapInvestorProfile goalType(
    SessionBootstrapInvestorProfileGoalTypeEnum goalType,
  ) => this(goalType: goalType);

  @override
  SessionBootstrapInvestorProfile isDemo(bool isDemo) => this(isDemo: isDemo);

  @override
  SessionBootstrapInvestorProfile riskComfort(
    SessionBootstrapInvestorProfileRiskComfortEnum riskComfort,
  ) => this(riskComfort: riskComfort);

  @override
  SessionBootstrapInvestorProfile timeHorizon(
    SessionBootstrapInvestorProfileTimeHorizonEnum timeHorizon,
  ) => this(timeHorizon: timeHorizon);

  @override
  SessionBootstrapInvestorProfile version(int version) =>
      this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionBootstrapInvestorProfile(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionBootstrapInvestorProfile(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionBootstrapInvestorProfile call({
    Object? contributionRhythm = const $CopyWithPlaceholder(),
    Object? experience = const $CopyWithPlaceholder(),
    Object? goalType = const $CopyWithPlaceholder(),
    Object? isDemo = const $CopyWithPlaceholder(),
    Object? riskComfort = const $CopyWithPlaceholder(),
    Object? timeHorizon = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return SessionBootstrapInvestorProfile(
      contributionRhythm: contributionRhythm == const $CopyWithPlaceholder()
          ? _value.contributionRhythm
          // ignore: cast_nullable_to_non_nullable
          : contributionRhythm
                as SessionBootstrapInvestorProfileContributionRhythmEnum,
      experience: experience == const $CopyWithPlaceholder()
          ? _value.experience
          // ignore: cast_nullable_to_non_nullable
          : experience as SessionBootstrapInvestorProfileExperienceEnum,
      goalType: goalType == const $CopyWithPlaceholder()
          ? _value.goalType
          // ignore: cast_nullable_to_non_nullable
          : goalType as SessionBootstrapInvestorProfileGoalTypeEnum,
      isDemo: isDemo == const $CopyWithPlaceholder()
          ? _value.isDemo
          // ignore: cast_nullable_to_non_nullable
          : isDemo as bool,
      riskComfort: riskComfort == const $CopyWithPlaceholder()
          ? _value.riskComfort
          // ignore: cast_nullable_to_non_nullable
          : riskComfort as SessionBootstrapInvestorProfileRiskComfortEnum,
      timeHorizon: timeHorizon == const $CopyWithPlaceholder()
          ? _value.timeHorizon
          // ignore: cast_nullable_to_non_nullable
          : timeHorizon as SessionBootstrapInvestorProfileTimeHorizonEnum,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $SessionBootstrapInvestorProfileCopyWith
    on SessionBootstrapInvestorProfile {
  /// Returns a callable class that can be used as follows: `instanceOfSessionBootstrapInvestorProfile.copyWith(...)` or like so:`instanceOfSessionBootstrapInvestorProfile.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SessionBootstrapInvestorProfileCWProxy get copyWith =>
      _$SessionBootstrapInvestorProfileCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionBootstrapInvestorProfile _$SessionBootstrapInvestorProfileFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'SessionBootstrapInvestorProfile',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'contribution_rhythm',
        'experience',
        'goal_type',
        'is_demo',
        'risk_comfort',
        'time_horizon',
        'version',
      ],
    );
    final val = SessionBootstrapInvestorProfile(
      contributionRhythm: $checkedConvert(
        'contribution_rhythm',
        (v) => $enumDecode(
          _$SessionBootstrapInvestorProfileContributionRhythmEnumEnumMap,
          v,
          unknownValue: SessionBootstrapInvestorProfileContributionRhythmEnum
              .unknownDefaultOpenApi,
        ),
      ),
      experience: $checkedConvert(
        'experience',
        (v) => $enumDecode(
          _$SessionBootstrapInvestorProfileExperienceEnumEnumMap,
          v,
          unknownValue: SessionBootstrapInvestorProfileExperienceEnum
              .unknownDefaultOpenApi,
        ),
      ),
      goalType: $checkedConvert(
        'goal_type',
        (v) => $enumDecode(
          _$SessionBootstrapInvestorProfileGoalTypeEnumEnumMap,
          v,
          unknownValue:
              SessionBootstrapInvestorProfileGoalTypeEnum.unknownDefaultOpenApi,
        ),
      ),
      isDemo: $checkedConvert('is_demo', (v) => v as bool),
      riskComfort: $checkedConvert(
        'risk_comfort',
        (v) => $enumDecode(
          _$SessionBootstrapInvestorProfileRiskComfortEnumEnumMap,
          v,
          unknownValue: SessionBootstrapInvestorProfileRiskComfortEnum
              .unknownDefaultOpenApi,
        ),
      ),
      timeHorizon: $checkedConvert(
        'time_horizon',
        (v) => $enumDecode(
          _$SessionBootstrapInvestorProfileTimeHorizonEnumEnumMap,
          v,
          unknownValue: SessionBootstrapInvestorProfileTimeHorizonEnum
              .unknownDefaultOpenApi,
        ),
      ),
      version: $checkedConvert('version', (v) => (v as num).toInt()),
    );
    return val;
  },
  fieldKeyMap: const {
    'contributionRhythm': 'contribution_rhythm',
    'goalType': 'goal_type',
    'isDemo': 'is_demo',
    'riskComfort': 'risk_comfort',
    'timeHorizon': 'time_horizon',
  },
);

Map<String, dynamic> _$SessionBootstrapInvestorProfileToJson(
  SessionBootstrapInvestorProfile instance,
) => <String, dynamic>{
  'contribution_rhythm':
      _$SessionBootstrapInvestorProfileContributionRhythmEnumEnumMap[instance
          .contributionRhythm]!,
  'experience':
      _$SessionBootstrapInvestorProfileExperienceEnumEnumMap[instance
          .experience]!,
  'goal_type':
      _$SessionBootstrapInvestorProfileGoalTypeEnumEnumMap[instance.goalType]!,
  'is_demo': instance.isDemo,
  'risk_comfort':
      _$SessionBootstrapInvestorProfileRiskComfortEnumEnumMap[instance
          .riskComfort]!,
  'time_horizon':
      _$SessionBootstrapInvestorProfileTimeHorizonEnumEnumMap[instance
          .timeHorizon]!,
  'version': instance.version,
};

const _$SessionBootstrapInvestorProfileContributionRhythmEnumEnumMap = {
  SessionBootstrapInvestorProfileContributionRhythmEnum.weekly: 'weekly',
  SessionBootstrapInvestorProfileContributionRhythmEnum.biweekly: 'biweekly',
  SessionBootstrapInvestorProfileContributionRhythmEnum.monthly: 'monthly',
  SessionBootstrapInvestorProfileContributionRhythmEnum.irregular: 'irregular',
  SessionBootstrapInvestorProfileContributionRhythmEnum.notSure: 'not_sure',
  SessionBootstrapInvestorProfileContributionRhythmEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$SessionBootstrapInvestorProfileExperienceEnumEnumMap = {
  SessionBootstrapInvestorProfileExperienceEnum.new_: 'new',
  SessionBootstrapInvestorProfileExperienceEnum.someExperience:
      'some_experience',
  SessionBootstrapInvestorProfileExperienceEnum.experienced: 'experienced',
  SessionBootstrapInvestorProfileExperienceEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$SessionBootstrapInvestorProfileGoalTypeEnumEnumMap = {
  SessionBootstrapInvestorProfileGoalTypeEnum.calmFund: 'calm_fund',
  SessionBootstrapInvestorProfileGoalTypeEnum.longTermGrowth:
      'long_term_growth',
  SessionBootstrapInvestorProfileGoalTypeEnum.income: 'income',
  SessionBootstrapInvestorProfileGoalTypeEnum.exploration: 'exploration',
  SessionBootstrapInvestorProfileGoalTypeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$SessionBootstrapInvestorProfileRiskComfortEnumEnumMap = {
  SessionBootstrapInvestorProfileRiskComfortEnum.low: 'low',
  SessionBootstrapInvestorProfileRiskComfortEnum.moderate: 'moderate',
  SessionBootstrapInvestorProfileRiskComfortEnum.high: 'high',
  SessionBootstrapInvestorProfileRiskComfortEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$SessionBootstrapInvestorProfileTimeHorizonEnumEnumMap = {
  SessionBootstrapInvestorProfileTimeHorizonEnum.short: 'short',
  SessionBootstrapInvestorProfileTimeHorizonEnum.medium: 'medium',
  SessionBootstrapInvestorProfileTimeHorizonEnum.long: 'long',
  SessionBootstrapInvestorProfileTimeHorizonEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
