//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'finalize_onboarding_request_investing.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FinalizeOnboardingRequestInvesting {
  /// Returns a new [FinalizeOnboardingRequestInvesting] instance.
  FinalizeOnboardingRequestInvesting({
    required this.contributionRhythm,

    required this.experience,

    required this.goalType,

    required this.riskComfort,

    required this.timeHorizon,
  });

  @JsonKey(
    name: r'contribution_rhythm',
    required: true,
    includeIfNull: false,
    unknownEnumValue: FinalizeOnboardingRequestInvestingContributionRhythmEnum
        .unknownDefaultOpenApi,
  )
  final FinalizeOnboardingRequestInvestingContributionRhythmEnum
  contributionRhythm;

  @JsonKey(
    name: r'experience',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        FinalizeOnboardingRequestInvestingExperienceEnum.unknownDefaultOpenApi,
  )
  final FinalizeOnboardingRequestInvestingExperienceEnum experience;

  @JsonKey(
    name: r'goal_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        FinalizeOnboardingRequestInvestingGoalTypeEnum.unknownDefaultOpenApi,
  )
  final FinalizeOnboardingRequestInvestingGoalTypeEnum goalType;

  @JsonKey(
    name: r'risk_comfort',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        FinalizeOnboardingRequestInvestingRiskComfortEnum.unknownDefaultOpenApi,
  )
  final FinalizeOnboardingRequestInvestingRiskComfortEnum riskComfort;

  @JsonKey(
    name: r'time_horizon',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        FinalizeOnboardingRequestInvestingTimeHorizonEnum.unknownDefaultOpenApi,
  )
  final FinalizeOnboardingRequestInvestingTimeHorizonEnum timeHorizon;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinalizeOnboardingRequestInvesting &&
          other.contributionRhythm == contributionRhythm &&
          other.experience == experience &&
          other.goalType == goalType &&
          other.riskComfort == riskComfort &&
          other.timeHorizon == timeHorizon;

  @override
  int get hashCode =>
      contributionRhythm.hashCode +
      experience.hashCode +
      goalType.hashCode +
      riskComfort.hashCode +
      timeHorizon.hashCode;

  factory FinalizeOnboardingRequestInvesting.fromJson(
    Map<String, dynamic> json,
  ) => _$FinalizeOnboardingRequestInvestingFromJson(json);

  Map<String, dynamic> toJson() =>
      _$FinalizeOnboardingRequestInvestingToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum FinalizeOnboardingRequestInvestingContributionRhythmEnum {
  @JsonValue(r'weekly')
  weekly(r'weekly'),
  @JsonValue(r'biweekly')
  biweekly(r'biweekly'),
  @JsonValue(r'monthly')
  monthly(r'monthly'),
  @JsonValue(r'irregular')
  irregular(r'irregular'),
  @JsonValue(r'not_sure')
  notSure(r'not_sure'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const FinalizeOnboardingRequestInvestingContributionRhythmEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum FinalizeOnboardingRequestInvestingExperienceEnum {
  @JsonValue(r'new')
  new_(r'new'),
  @JsonValue(r'some_experience')
  someExperience(r'some_experience'),
  @JsonValue(r'experienced')
  experienced(r'experienced'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const FinalizeOnboardingRequestInvestingExperienceEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum FinalizeOnboardingRequestInvestingGoalTypeEnum {
  @JsonValue(r'calm_fund')
  calmFund(r'calm_fund'),
  @JsonValue(r'long_term_growth')
  longTermGrowth(r'long_term_growth'),
  @JsonValue(r'income')
  income(r'income'),
  @JsonValue(r'exploration')
  exploration(r'exploration'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const FinalizeOnboardingRequestInvestingGoalTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum FinalizeOnboardingRequestInvestingRiskComfortEnum {
  @JsonValue(r'low')
  low(r'low'),
  @JsonValue(r'moderate')
  moderate(r'moderate'),
  @JsonValue(r'high')
  high(r'high'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const FinalizeOnboardingRequestInvestingRiskComfortEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum FinalizeOnboardingRequestInvestingTimeHorizonEnum {
  @JsonValue(r'short')
  short(r'short'),
  @JsonValue(r'medium')
  medium(r'medium'),
  @JsonValue(r'long')
  long(r'long'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const FinalizeOnboardingRequestInvestingTimeHorizonEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
