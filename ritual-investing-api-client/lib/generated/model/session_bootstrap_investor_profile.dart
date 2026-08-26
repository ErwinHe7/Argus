//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'session_bootstrap_investor_profile.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SessionBootstrapInvestorProfile {
  /// Returns a new [SessionBootstrapInvestorProfile] instance.
  SessionBootstrapInvestorProfile({
    required this.contributionRhythm,

    required this.experience,

    required this.goalType,

    required this.isDemo,

    required this.riskComfort,

    required this.timeHorizon,

    required this.version,
  });

  @JsonKey(
    name: r'contribution_rhythm',
    required: true,
    includeIfNull: false,
    unknownEnumValue: SessionBootstrapInvestorProfileContributionRhythmEnum
        .unknownDefaultOpenApi,
  )
  final SessionBootstrapInvestorProfileContributionRhythmEnum
  contributionRhythm;

  @JsonKey(
    name: r'experience',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        SessionBootstrapInvestorProfileExperienceEnum.unknownDefaultOpenApi,
  )
  final SessionBootstrapInvestorProfileExperienceEnum experience;

  @JsonKey(
    name: r'goal_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        SessionBootstrapInvestorProfileGoalTypeEnum.unknownDefaultOpenApi,
  )
  final SessionBootstrapInvestorProfileGoalTypeEnum goalType;

  @JsonKey(name: r'is_demo', required: true, includeIfNull: false)
  final bool isDemo;

  @JsonKey(
    name: r'risk_comfort',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        SessionBootstrapInvestorProfileRiskComfortEnum.unknownDefaultOpenApi,
  )
  final SessionBootstrapInvestorProfileRiskComfortEnum riskComfort;

  @JsonKey(
    name: r'time_horizon',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        SessionBootstrapInvestorProfileTimeHorizonEnum.unknownDefaultOpenApi,
  )
  final SessionBootstrapInvestorProfileTimeHorizonEnum timeHorizon;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionBootstrapInvestorProfile &&
          other.contributionRhythm == contributionRhythm &&
          other.experience == experience &&
          other.goalType == goalType &&
          other.isDemo == isDemo &&
          other.riskComfort == riskComfort &&
          other.timeHorizon == timeHorizon &&
          other.version == version;

  @override
  int get hashCode =>
      contributionRhythm.hashCode +
      experience.hashCode +
      goalType.hashCode +
      isDemo.hashCode +
      riskComfort.hashCode +
      timeHorizon.hashCode +
      version.hashCode;

  factory SessionBootstrapInvestorProfile.fromJson(Map<String, dynamic> json) =>
      _$SessionBootstrapInvestorProfileFromJson(json);

  Map<String, dynamic> toJson() =>
      _$SessionBootstrapInvestorProfileToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum SessionBootstrapInvestorProfileContributionRhythmEnum {
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

  const SessionBootstrapInvestorProfileContributionRhythmEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum SessionBootstrapInvestorProfileExperienceEnum {
  @JsonValue(r'new')
  new_(r'new'),
  @JsonValue(r'some_experience')
  someExperience(r'some_experience'),
  @JsonValue(r'experienced')
  experienced(r'experienced'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const SessionBootstrapInvestorProfileExperienceEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum SessionBootstrapInvestorProfileGoalTypeEnum {
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

  const SessionBootstrapInvestorProfileGoalTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum SessionBootstrapInvestorProfileRiskComfortEnum {
  @JsonValue(r'low')
  low(r'low'),
  @JsonValue(r'moderate')
  moderate(r'moderate'),
  @JsonValue(r'high')
  high(r'high'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const SessionBootstrapInvestorProfileRiskComfortEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum SessionBootstrapInvestorProfileTimeHorizonEnum {
  @JsonValue(r'short')
  short(r'short'),
  @JsonValue(r'medium')
  medium(r'medium'),
  @JsonValue(r'long')
  long(r'long'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const SessionBootstrapInvestorProfileTimeHorizonEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
