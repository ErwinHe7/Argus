//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'onboarding_state.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OnboardingState {
  /// Returns a new [OnboardingState] instance.
  OnboardingState({
    required this.completedAt,

    required this.completedSteps,

    required this.currentStep,

    required this.version,
  });

  @JsonKey(name: r'completed_at', required: true, includeIfNull: true)
  final DateTime? completedAt;

  @JsonKey(name: r'completed_steps', required: true, includeIfNull: false)
  final List<String> completedSteps;

  @JsonKey(
    name: r'current_step',
    required: true,
    includeIfNull: false,
    unknownEnumValue: OnboardingStateCurrentStepEnum.unknownDefaultOpenApi,
  )
  final OnboardingStateCurrentStepEnum currentStep;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingState &&
          other.completedAt == completedAt &&
          other.completedSteps == completedSteps &&
          other.currentStep == currentStep &&
          other.version == version;

  @override
  int get hashCode =>
      (completedAt == null ? 0 : completedAt.hashCode) +
      completedSteps.hashCode +
      currentStep.hashCode +
      version.hashCode;

  factory OnboardingState.fromJson(Map<String, dynamic> json) =>
      _$OnboardingStateFromJson(json);

  Map<String, dynamic> toJson() => _$OnboardingStateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum OnboardingStateCurrentStepEnum {
  @JsonValue(r'welcome')
  welcome(r'welcome'),
  @JsonValue(r'ritual')
  ritual(r'ritual'),
  @JsonValue(r'profile')
  profile(r'profile'),
  @JsonValue(r'complete')
  complete(r'complete'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const OnboardingStateCurrentStepEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
