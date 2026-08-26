// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finalize_onboarding_request_investing.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FinalizeOnboardingRequestInvestingCWProxy {
  FinalizeOnboardingRequestInvesting contributionRhythm(
    FinalizeOnboardingRequestInvestingContributionRhythmEnum contributionRhythm,
  );

  FinalizeOnboardingRequestInvesting experience(
    FinalizeOnboardingRequestInvestingExperienceEnum experience,
  );

  FinalizeOnboardingRequestInvesting goalType(
    FinalizeOnboardingRequestInvestingGoalTypeEnum goalType,
  );

  FinalizeOnboardingRequestInvesting riskComfort(
    FinalizeOnboardingRequestInvestingRiskComfortEnum riskComfort,
  );

  FinalizeOnboardingRequestInvesting timeHorizon(
    FinalizeOnboardingRequestInvestingTimeHorizonEnum timeHorizon,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FinalizeOnboardingRequestInvesting(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FinalizeOnboardingRequestInvesting(...).copyWith(id: 12, name: "My name")
  /// ````
  FinalizeOnboardingRequestInvesting call({
    FinalizeOnboardingRequestInvestingContributionRhythmEnum contributionRhythm,
    FinalizeOnboardingRequestInvestingExperienceEnum experience,
    FinalizeOnboardingRequestInvestingGoalTypeEnum goalType,
    FinalizeOnboardingRequestInvestingRiskComfortEnum riskComfort,
    FinalizeOnboardingRequestInvestingTimeHorizonEnum timeHorizon,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfFinalizeOnboardingRequestInvesting.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfFinalizeOnboardingRequestInvesting.copyWith.fieldName(...)`
class _$FinalizeOnboardingRequestInvestingCWProxyImpl
    implements _$FinalizeOnboardingRequestInvestingCWProxy {
  const _$FinalizeOnboardingRequestInvestingCWProxyImpl(this._value);

  final FinalizeOnboardingRequestInvesting _value;

  @override
  FinalizeOnboardingRequestInvesting contributionRhythm(
    FinalizeOnboardingRequestInvestingContributionRhythmEnum contributionRhythm,
  ) => this(contributionRhythm: contributionRhythm);

  @override
  FinalizeOnboardingRequestInvesting experience(
    FinalizeOnboardingRequestInvestingExperienceEnum experience,
  ) => this(experience: experience);

  @override
  FinalizeOnboardingRequestInvesting goalType(
    FinalizeOnboardingRequestInvestingGoalTypeEnum goalType,
  ) => this(goalType: goalType);

  @override
  FinalizeOnboardingRequestInvesting riskComfort(
    FinalizeOnboardingRequestInvestingRiskComfortEnum riskComfort,
  ) => this(riskComfort: riskComfort);

  @override
  FinalizeOnboardingRequestInvesting timeHorizon(
    FinalizeOnboardingRequestInvestingTimeHorizonEnum timeHorizon,
  ) => this(timeHorizon: timeHorizon);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FinalizeOnboardingRequestInvesting(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FinalizeOnboardingRequestInvesting(...).copyWith(id: 12, name: "My name")
  /// ````
  FinalizeOnboardingRequestInvesting call({
    Object? contributionRhythm = const $CopyWithPlaceholder(),
    Object? experience = const $CopyWithPlaceholder(),
    Object? goalType = const $CopyWithPlaceholder(),
    Object? riskComfort = const $CopyWithPlaceholder(),
    Object? timeHorizon = const $CopyWithPlaceholder(),
  }) {
    return FinalizeOnboardingRequestInvesting(
      contributionRhythm: contributionRhythm == const $CopyWithPlaceholder()
          ? _value.contributionRhythm
          // ignore: cast_nullable_to_non_nullable
          : contributionRhythm
                as FinalizeOnboardingRequestInvestingContributionRhythmEnum,
      experience: experience == const $CopyWithPlaceholder()
          ? _value.experience
          // ignore: cast_nullable_to_non_nullable
          : experience as FinalizeOnboardingRequestInvestingExperienceEnum,
      goalType: goalType == const $CopyWithPlaceholder()
          ? _value.goalType
          // ignore: cast_nullable_to_non_nullable
          : goalType as FinalizeOnboardingRequestInvestingGoalTypeEnum,
      riskComfort: riskComfort == const $CopyWithPlaceholder()
          ? _value.riskComfort
          // ignore: cast_nullable_to_non_nullable
          : riskComfort as FinalizeOnboardingRequestInvestingRiskComfortEnum,
      timeHorizon: timeHorizon == const $CopyWithPlaceholder()
          ? _value.timeHorizon
          // ignore: cast_nullable_to_non_nullable
          : timeHorizon as FinalizeOnboardingRequestInvestingTimeHorizonEnum,
    );
  }
}

extension $FinalizeOnboardingRequestInvestingCopyWith
    on FinalizeOnboardingRequestInvesting {
  /// Returns a callable class that can be used as follows: `instanceOfFinalizeOnboardingRequestInvesting.copyWith(...)` or like so:`instanceOfFinalizeOnboardingRequestInvesting.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FinalizeOnboardingRequestInvestingCWProxy get copyWith =>
      _$FinalizeOnboardingRequestInvestingCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FinalizeOnboardingRequestInvesting _$FinalizeOnboardingRequestInvestingFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'FinalizeOnboardingRequestInvesting',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'contribution_rhythm',
        'experience',
        'goal_type',
        'risk_comfort',
        'time_horizon',
      ],
    );
    final val = FinalizeOnboardingRequestInvesting(
      contributionRhythm: $checkedConvert(
        'contribution_rhythm',
        (v) => $enumDecode(
          _$FinalizeOnboardingRequestInvestingContributionRhythmEnumEnumMap,
          v,
          unknownValue: FinalizeOnboardingRequestInvestingContributionRhythmEnum
              .unknownDefaultOpenApi,
        ),
      ),
      experience: $checkedConvert(
        'experience',
        (v) => $enumDecode(
          _$FinalizeOnboardingRequestInvestingExperienceEnumEnumMap,
          v,
          unknownValue: FinalizeOnboardingRequestInvestingExperienceEnum
              .unknownDefaultOpenApi,
        ),
      ),
      goalType: $checkedConvert(
        'goal_type',
        (v) => $enumDecode(
          _$FinalizeOnboardingRequestInvestingGoalTypeEnumEnumMap,
          v,
          unknownValue: FinalizeOnboardingRequestInvestingGoalTypeEnum
              .unknownDefaultOpenApi,
        ),
      ),
      riskComfort: $checkedConvert(
        'risk_comfort',
        (v) => $enumDecode(
          _$FinalizeOnboardingRequestInvestingRiskComfortEnumEnumMap,
          v,
          unknownValue: FinalizeOnboardingRequestInvestingRiskComfortEnum
              .unknownDefaultOpenApi,
        ),
      ),
      timeHorizon: $checkedConvert(
        'time_horizon',
        (v) => $enumDecode(
          _$FinalizeOnboardingRequestInvestingTimeHorizonEnumEnumMap,
          v,
          unknownValue: FinalizeOnboardingRequestInvestingTimeHorizonEnum
              .unknownDefaultOpenApi,
        ),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'contributionRhythm': 'contribution_rhythm',
    'goalType': 'goal_type',
    'riskComfort': 'risk_comfort',
    'timeHorizon': 'time_horizon',
  },
);

Map<String, dynamic> _$FinalizeOnboardingRequestInvestingToJson(
  FinalizeOnboardingRequestInvesting instance,
) => <String, dynamic>{
  'contribution_rhythm':
      _$FinalizeOnboardingRequestInvestingContributionRhythmEnumEnumMap[instance
          .contributionRhythm]!,
  'experience':
      _$FinalizeOnboardingRequestInvestingExperienceEnumEnumMap[instance
          .experience]!,
  'goal_type':
      _$FinalizeOnboardingRequestInvestingGoalTypeEnumEnumMap[instance
          .goalType]!,
  'risk_comfort':
      _$FinalizeOnboardingRequestInvestingRiskComfortEnumEnumMap[instance
          .riskComfort]!,
  'time_horizon':
      _$FinalizeOnboardingRequestInvestingTimeHorizonEnumEnumMap[instance
          .timeHorizon]!,
};

const _$FinalizeOnboardingRequestInvestingContributionRhythmEnumEnumMap = {
  FinalizeOnboardingRequestInvestingContributionRhythmEnum.weekly: 'weekly',
  FinalizeOnboardingRequestInvestingContributionRhythmEnum.biweekly: 'biweekly',
  FinalizeOnboardingRequestInvestingContributionRhythmEnum.monthly: 'monthly',
  FinalizeOnboardingRequestInvestingContributionRhythmEnum.irregular:
      'irregular',
  FinalizeOnboardingRequestInvestingContributionRhythmEnum.notSure: 'not_sure',
  FinalizeOnboardingRequestInvestingContributionRhythmEnum
          .unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$FinalizeOnboardingRequestInvestingExperienceEnumEnumMap = {
  FinalizeOnboardingRequestInvestingExperienceEnum.new_: 'new',
  FinalizeOnboardingRequestInvestingExperienceEnum.someExperience:
      'some_experience',
  FinalizeOnboardingRequestInvestingExperienceEnum.experienced: 'experienced',
  FinalizeOnboardingRequestInvestingExperienceEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$FinalizeOnboardingRequestInvestingGoalTypeEnumEnumMap = {
  FinalizeOnboardingRequestInvestingGoalTypeEnum.calmFund: 'calm_fund',
  FinalizeOnboardingRequestInvestingGoalTypeEnum.longTermGrowth:
      'long_term_growth',
  FinalizeOnboardingRequestInvestingGoalTypeEnum.income: 'income',
  FinalizeOnboardingRequestInvestingGoalTypeEnum.exploration: 'exploration',
  FinalizeOnboardingRequestInvestingGoalTypeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$FinalizeOnboardingRequestInvestingRiskComfortEnumEnumMap = {
  FinalizeOnboardingRequestInvestingRiskComfortEnum.low: 'low',
  FinalizeOnboardingRequestInvestingRiskComfortEnum.moderate: 'moderate',
  FinalizeOnboardingRequestInvestingRiskComfortEnum.high: 'high',
  FinalizeOnboardingRequestInvestingRiskComfortEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$FinalizeOnboardingRequestInvestingTimeHorizonEnumEnumMap = {
  FinalizeOnboardingRequestInvestingTimeHorizonEnum.short: 'short',
  FinalizeOnboardingRequestInvestingTimeHorizonEnum.medium: 'medium',
  FinalizeOnboardingRequestInvestingTimeHorizonEnum.long: 'long',
  FinalizeOnboardingRequestInvestingTimeHorizonEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
