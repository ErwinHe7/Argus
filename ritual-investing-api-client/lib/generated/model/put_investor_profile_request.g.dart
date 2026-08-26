// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'put_investor_profile_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PutInvestorProfileRequestCWProxy {
  PutInvestorProfileRequest contributionRhythm(
    PutInvestorProfileRequestContributionRhythmEnum? contributionRhythm,
  );

  PutInvestorProfileRequest goalType(
    PutInvestorProfileRequestGoalTypeEnum goalType,
  );

  PutInvestorProfileRequest investingExperience(
    PutInvestorProfileRequestInvestingExperienceEnum? investingExperience,
  );

  PutInvestorProfileRequest riskComfort(
    PutInvestorProfileRequestRiskComfortEnum riskComfort,
  );

  PutInvestorProfileRequest timeHorizon(
    PutInvestorProfileRequestTimeHorizonEnum timeHorizon,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PutInvestorProfileRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PutInvestorProfileRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PutInvestorProfileRequest call({
    PutInvestorProfileRequestContributionRhythmEnum? contributionRhythm,
    PutInvestorProfileRequestGoalTypeEnum goalType,
    PutInvestorProfileRequestInvestingExperienceEnum? investingExperience,
    PutInvestorProfileRequestRiskComfortEnum riskComfort,
    PutInvestorProfileRequestTimeHorizonEnum timeHorizon,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPutInvestorProfileRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPutInvestorProfileRequest.copyWith.fieldName(...)`
class _$PutInvestorProfileRequestCWProxyImpl
    implements _$PutInvestorProfileRequestCWProxy {
  const _$PutInvestorProfileRequestCWProxyImpl(this._value);

  final PutInvestorProfileRequest _value;

  @override
  PutInvestorProfileRequest contributionRhythm(
    PutInvestorProfileRequestContributionRhythmEnum? contributionRhythm,
  ) => this(contributionRhythm: contributionRhythm);

  @override
  PutInvestorProfileRequest goalType(
    PutInvestorProfileRequestGoalTypeEnum goalType,
  ) => this(goalType: goalType);

  @override
  PutInvestorProfileRequest investingExperience(
    PutInvestorProfileRequestInvestingExperienceEnum? investingExperience,
  ) => this(investingExperience: investingExperience);

  @override
  PutInvestorProfileRequest riskComfort(
    PutInvestorProfileRequestRiskComfortEnum riskComfort,
  ) => this(riskComfort: riskComfort);

  @override
  PutInvestorProfileRequest timeHorizon(
    PutInvestorProfileRequestTimeHorizonEnum timeHorizon,
  ) => this(timeHorizon: timeHorizon);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PutInvestorProfileRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PutInvestorProfileRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PutInvestorProfileRequest call({
    Object? contributionRhythm = const $CopyWithPlaceholder(),
    Object? goalType = const $CopyWithPlaceholder(),
    Object? investingExperience = const $CopyWithPlaceholder(),
    Object? riskComfort = const $CopyWithPlaceholder(),
    Object? timeHorizon = const $CopyWithPlaceholder(),
  }) {
    return PutInvestorProfileRequest(
      contributionRhythm: contributionRhythm == const $CopyWithPlaceholder()
          ? _value.contributionRhythm
          // ignore: cast_nullable_to_non_nullable
          : contributionRhythm
                as PutInvestorProfileRequestContributionRhythmEnum?,
      goalType: goalType == const $CopyWithPlaceholder()
          ? _value.goalType
          // ignore: cast_nullable_to_non_nullable
          : goalType as PutInvestorProfileRequestGoalTypeEnum,
      investingExperience: investingExperience == const $CopyWithPlaceholder()
          ? _value.investingExperience
          // ignore: cast_nullable_to_non_nullable
          : investingExperience
                as PutInvestorProfileRequestInvestingExperienceEnum?,
      riskComfort: riskComfort == const $CopyWithPlaceholder()
          ? _value.riskComfort
          // ignore: cast_nullable_to_non_nullable
          : riskComfort as PutInvestorProfileRequestRiskComfortEnum,
      timeHorizon: timeHorizon == const $CopyWithPlaceholder()
          ? _value.timeHorizon
          // ignore: cast_nullable_to_non_nullable
          : timeHorizon as PutInvestorProfileRequestTimeHorizonEnum,
    );
  }
}

extension $PutInvestorProfileRequestCopyWith on PutInvestorProfileRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPutInvestorProfileRequest.copyWith(...)` or like so:`instanceOfPutInvestorProfileRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PutInvestorProfileRequestCWProxy get copyWith =>
      _$PutInvestorProfileRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PutInvestorProfileRequest _$PutInvestorProfileRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'PutInvestorProfileRequest',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const ['goal_type', 'risk_comfort', 'time_horizon'],
    );
    final val = PutInvestorProfileRequest(
      contributionRhythm: $checkedConvert(
        'contribution_rhythm',
        (v) => $enumDecodeNullable(
          _$PutInvestorProfileRequestContributionRhythmEnumEnumMap,
          v,
          unknownValue: PutInvestorProfileRequestContributionRhythmEnum
              .unknownDefaultOpenApi,
        ),
      ),
      goalType: $checkedConvert(
        'goal_type',
        (v) => $enumDecode(
          _$PutInvestorProfileRequestGoalTypeEnumEnumMap,
          v,
          unknownValue:
              PutInvestorProfileRequestGoalTypeEnum.unknownDefaultOpenApi,
        ),
      ),
      investingExperience: $checkedConvert(
        'investing_experience',
        (v) => $enumDecodeNullable(
          _$PutInvestorProfileRequestInvestingExperienceEnumEnumMap,
          v,
          unknownValue: PutInvestorProfileRequestInvestingExperienceEnum
              .unknownDefaultOpenApi,
        ),
      ),
      riskComfort: $checkedConvert(
        'risk_comfort',
        (v) => $enumDecode(
          _$PutInvestorProfileRequestRiskComfortEnumEnumMap,
          v,
          unknownValue:
              PutInvestorProfileRequestRiskComfortEnum.unknownDefaultOpenApi,
        ),
      ),
      timeHorizon: $checkedConvert(
        'time_horizon',
        (v) => $enumDecode(
          _$PutInvestorProfileRequestTimeHorizonEnumEnumMap,
          v,
          unknownValue:
              PutInvestorProfileRequestTimeHorizonEnum.unknownDefaultOpenApi,
        ),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'contributionRhythm': 'contribution_rhythm',
    'goalType': 'goal_type',
    'investingExperience': 'investing_experience',
    'riskComfort': 'risk_comfort',
    'timeHorizon': 'time_horizon',
  },
);

Map<String, dynamic> _$PutInvestorProfileRequestToJson(
  PutInvestorProfileRequest instance,
) => <String, dynamic>{
  'contribution_rhythm':
      ?_$PutInvestorProfileRequestContributionRhythmEnumEnumMap[instance
          .contributionRhythm],
  'goal_type':
      _$PutInvestorProfileRequestGoalTypeEnumEnumMap[instance.goalType]!,
  'investing_experience':
      ?_$PutInvestorProfileRequestInvestingExperienceEnumEnumMap[instance
          .investingExperience],
  'risk_comfort':
      _$PutInvestorProfileRequestRiskComfortEnumEnumMap[instance.riskComfort]!,
  'time_horizon':
      _$PutInvestorProfileRequestTimeHorizonEnumEnumMap[instance.timeHorizon]!,
};

const _$PutInvestorProfileRequestContributionRhythmEnumEnumMap = {
  PutInvestorProfileRequestContributionRhythmEnum.weekly: 'weekly',
  PutInvestorProfileRequestContributionRhythmEnum.biweekly: 'biweekly',
  PutInvestorProfileRequestContributionRhythmEnum.monthly: 'monthly',
  PutInvestorProfileRequestContributionRhythmEnum.irregular: 'irregular',
  PutInvestorProfileRequestContributionRhythmEnum.notSure: 'not_sure',
  PutInvestorProfileRequestContributionRhythmEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$PutInvestorProfileRequestGoalTypeEnumEnumMap = {
  PutInvestorProfileRequestGoalTypeEnum.calmFund: 'calm_fund',
  PutInvestorProfileRequestGoalTypeEnum.longTermGrowth: 'long_term_growth',
  PutInvestorProfileRequestGoalTypeEnum.income: 'income',
  PutInvestorProfileRequestGoalTypeEnum.exploration: 'exploration',
  PutInvestorProfileRequestGoalTypeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$PutInvestorProfileRequestInvestingExperienceEnumEnumMap = {
  PutInvestorProfileRequestInvestingExperienceEnum.new_: 'new',
  PutInvestorProfileRequestInvestingExperienceEnum.someExperience:
      'some_experience',
  PutInvestorProfileRequestInvestingExperienceEnum.experienced: 'experienced',
  PutInvestorProfileRequestInvestingExperienceEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$PutInvestorProfileRequestRiskComfortEnumEnumMap = {
  PutInvestorProfileRequestRiskComfortEnum.low: 'low',
  PutInvestorProfileRequestRiskComfortEnum.moderate: 'moderate',
  PutInvestorProfileRequestRiskComfortEnum.high: 'high',
  PutInvestorProfileRequestRiskComfortEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$PutInvestorProfileRequestTimeHorizonEnumEnumMap = {
  PutInvestorProfileRequestTimeHorizonEnum.short: 'short',
  PutInvestorProfileRequestTimeHorizonEnum.medium: 'medium',
  PutInvestorProfileRequestTimeHorizonEnum.long: 'long',
  PutInvestorProfileRequestTimeHorizonEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
