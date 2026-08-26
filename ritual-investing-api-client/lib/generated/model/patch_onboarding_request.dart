//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patch_onboarding_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchOnboardingRequest {
  /// Returns a new [PatchOnboardingRequest] instance.
  PatchOnboardingRequest({
    required this.completedSteps,

    required this.currentStep,
  });

  @JsonKey(name: r'completed_steps', required: true, includeIfNull: false)
  final List<String> completedSteps;

  @JsonKey(
    name: r'current_step',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        PatchOnboardingRequestCurrentStepEnum.unknownDefaultOpenApi,
  )
  final PatchOnboardingRequestCurrentStepEnum currentStep;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchOnboardingRequest &&
          other.completedSteps == completedSteps &&
          other.currentStep == currentStep;

  @override
  int get hashCode => completedSteps.hashCode + currentStep.hashCode;

  factory PatchOnboardingRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchOnboardingRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PatchOnboardingRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum PatchOnboardingRequestCurrentStepEnum {
  @JsonValue(r'ritual')
  ritual(r'ritual'),
  @JsonValue(r'profile')
  profile(r'profile'),
  @JsonValue(r'complete')
  complete(r'complete'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PatchOnboardingRequestCurrentStepEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
