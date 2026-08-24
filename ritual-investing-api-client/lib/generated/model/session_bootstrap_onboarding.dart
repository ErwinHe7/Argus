//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'session_bootstrap_onboarding.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SessionBootstrapOnboarding {
  /// Returns a new [SessionBootstrapOnboarding] instance.
  SessionBootstrapOnboarding({
    required this.completedSteps,

    required this.currentStep,

    required this.version,
  });

  @JsonKey(name: r'completed_steps', required: true, includeIfNull: false)
  final List<String> completedSteps;

  @JsonKey(name: r'current_step', required: true, includeIfNull: false)
  final String currentStep;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionBootstrapOnboarding &&
          other.completedSteps == completedSteps &&
          other.currentStep == currentStep &&
          other.version == version;

  @override
  int get hashCode =>
      completedSteps.hashCode + currentStep.hashCode + version.hashCode;

  factory SessionBootstrapOnboarding.fromJson(Map<String, dynamic> json) =>
      _$SessionBootstrapOnboardingFromJson(json);

  Map<String, dynamic> toJson() => _$SessionBootstrapOnboardingToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
