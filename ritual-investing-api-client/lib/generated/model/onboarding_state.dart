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

    required this.deletionEpoch,

    required this.userId,

    required this.version,
  });

  @JsonKey(name: r'completed_at', required: true, includeIfNull: true)
  final DateTime? completedAt;

  @JsonKey(name: r'completed_steps', required: true, includeIfNull: false)
  final List<String> completedSteps;

  @JsonKey(name: r'current_step', required: true, includeIfNull: false)
  final String currentStep;

  // minimum: 0
  @JsonKey(name: r'deletion_epoch', required: true, includeIfNull: true)
  final int? deletionEpoch;

  @JsonKey(name: r'user_id', required: true, includeIfNull: false)
  final String userId;

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
          other.deletionEpoch == deletionEpoch &&
          other.userId == userId &&
          other.version == version;

  @override
  int get hashCode =>
      (completedAt == null ? 0 : completedAt.hashCode) +
      completedSteps.hashCode +
      currentStep.hashCode +
      (deletionEpoch == null ? 0 : deletionEpoch.hashCode) +
      userId.hashCode +
      version.hashCode;

  factory OnboardingState.fromJson(Map<String, dynamic> json) =>
      _$OnboardingStateFromJson(json);

  Map<String, dynamic> toJson() => _$OnboardingStateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
