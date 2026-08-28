//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'update_investor_profile_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class UpdateInvestorProfileRequest {
  /// Returns a new [UpdateInvestorProfileRequest] instance.
  UpdateInvestorProfileRequest({
    required this.goalType,

    required this.riskComfort,

    required this.timeHorizon,
  });

  @JsonKey(
    name: r'goalType',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        UpdateInvestorProfileRequestGoalTypeEnum.unknownDefaultOpenApi,
  )
  final UpdateInvestorProfileRequestGoalTypeEnum goalType;

  @JsonKey(
    name: r'riskComfort',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        UpdateInvestorProfileRequestRiskComfortEnum.unknownDefaultOpenApi,
  )
  final UpdateInvestorProfileRequestRiskComfortEnum riskComfort;

  @JsonKey(
    name: r'timeHorizon',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        UpdateInvestorProfileRequestTimeHorizonEnum.unknownDefaultOpenApi,
  )
  final UpdateInvestorProfileRequestTimeHorizonEnum timeHorizon;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateInvestorProfileRequest &&
          other.goalType == goalType &&
          other.riskComfort == riskComfort &&
          other.timeHorizon == timeHorizon;

  @override
  int get hashCode =>
      goalType.hashCode + riskComfort.hashCode + timeHorizon.hashCode;

  factory UpdateInvestorProfileRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateInvestorProfileRequestFromJson(json);

  Map<String, dynamic> toJson() => _$UpdateInvestorProfileRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum UpdateInvestorProfileRequestGoalTypeEnum {
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

  const UpdateInvestorProfileRequestGoalTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum UpdateInvestorProfileRequestRiskComfortEnum {
  @JsonValue(r'low')
  low(r'low'),
  @JsonValue(r'moderate')
  moderate(r'moderate'),
  @JsonValue(r'high')
  high(r'high'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const UpdateInvestorProfileRequestRiskComfortEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum UpdateInvestorProfileRequestTimeHorizonEnum {
  @JsonValue(r'short')
  short(r'short'),
  @JsonValue(r'medium')
  medium(r'medium'),
  @JsonValue(r'long')
  long(r'long'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const UpdateInvestorProfileRequestTimeHorizonEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
