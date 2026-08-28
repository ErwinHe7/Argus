//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'investor_profile.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class InvestorProfile {
  /// Returns a new [InvestorProfile] instance.
  InvestorProfile({
    required this.deletionEpoch,

    required this.goalType,

    required this.riskComfort,

    required this.timeHorizon,

    required this.userId,

    required this.version,
  });

  // minimum: 0
  @JsonKey(name: r'deletion_epoch', required: true, includeIfNull: true)
  final int? deletionEpoch;

  @JsonKey(
    name: r'goal_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: InvestorProfileGoalTypeEnum.unknownDefaultOpenApi,
  )
  final InvestorProfileGoalTypeEnum goalType;

  @JsonKey(
    name: r'risk_comfort',
    required: true,
    includeIfNull: false,
    unknownEnumValue: InvestorProfileRiskComfortEnum.unknownDefaultOpenApi,
  )
  final InvestorProfileRiskComfortEnum riskComfort;

  @JsonKey(
    name: r'time_horizon',
    required: true,
    includeIfNull: false,
    unknownEnumValue: InvestorProfileTimeHorizonEnum.unknownDefaultOpenApi,
  )
  final InvestorProfileTimeHorizonEnum timeHorizon;

  @JsonKey(name: r'user_id', required: true, includeIfNull: false)
  final String userId;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvestorProfile &&
          other.deletionEpoch == deletionEpoch &&
          other.goalType == goalType &&
          other.riskComfort == riskComfort &&
          other.timeHorizon == timeHorizon &&
          other.userId == userId &&
          other.version == version;

  @override
  int get hashCode =>
      (deletionEpoch == null ? 0 : deletionEpoch.hashCode) +
      goalType.hashCode +
      riskComfort.hashCode +
      timeHorizon.hashCode +
      userId.hashCode +
      version.hashCode;

  factory InvestorProfile.fromJson(Map<String, dynamic> json) =>
      _$InvestorProfileFromJson(json);

  Map<String, dynamic> toJson() => _$InvestorProfileToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum InvestorProfileGoalTypeEnum {
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

  const InvestorProfileGoalTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum InvestorProfileRiskComfortEnum {
  @JsonValue(r'low')
  low(r'low'),
  @JsonValue(r'moderate')
  moderate(r'moderate'),
  @JsonValue(r'high')
  high(r'high'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const InvestorProfileRiskComfortEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum InvestorProfileTimeHorizonEnum {
  @JsonValue(r'short')
  short(r'short'),
  @JsonValue(r'medium')
  medium(r'medium'),
  @JsonValue(r'long')
  long(r'long'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const InvestorProfileTimeHorizonEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
