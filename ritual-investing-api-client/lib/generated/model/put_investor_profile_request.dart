//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'put_investor_profile_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PutInvestorProfileRequest {
  /// Returns a new [PutInvestorProfileRequest] instance.
  PutInvestorProfileRequest({
    required this.goalType,

    required this.riskComfort,

    required this.timeHorizon,
  });

  @JsonKey(
    name: r'goal_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        PutInvestorProfileRequestGoalTypeEnum.unknownDefaultOpenApi,
  )
  final PutInvestorProfileRequestGoalTypeEnum goalType;

  @JsonKey(
    name: r'risk_comfort',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        PutInvestorProfileRequestRiskComfortEnum.unknownDefaultOpenApi,
  )
  final PutInvestorProfileRequestRiskComfortEnum riskComfort;

  @JsonKey(
    name: r'time_horizon',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        PutInvestorProfileRequestTimeHorizonEnum.unknownDefaultOpenApi,
  )
  final PutInvestorProfileRequestTimeHorizonEnum timeHorizon;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PutInvestorProfileRequest &&
          other.goalType == goalType &&
          other.riskComfort == riskComfort &&
          other.timeHorizon == timeHorizon;

  @override
  int get hashCode =>
      goalType.hashCode + riskComfort.hashCode + timeHorizon.hashCode;

  factory PutInvestorProfileRequest.fromJson(Map<String, dynamic> json) =>
      _$PutInvestorProfileRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PutInvestorProfileRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum PutInvestorProfileRequestGoalTypeEnum {
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

  const PutInvestorProfileRequestGoalTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum PutInvestorProfileRequestRiskComfortEnum {
  @JsonValue(r'low')
  low(r'low'),
  @JsonValue(r'moderate')
  moderate(r'moderate'),
  @JsonValue(r'high')
  high(r'high'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PutInvestorProfileRequestRiskComfortEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum PutInvestorProfileRequestTimeHorizonEnum {
  @JsonValue(r'short')
  short(r'short'),
  @JsonValue(r'medium')
  medium(r'medium'),
  @JsonValue(r'long')
  long(r'long'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PutInvestorProfileRequestTimeHorizonEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
