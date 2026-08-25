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
    required this.cohort,

    required this.completedAt,

    required this.completedSteps,

    required this.currentStep,

    required this.schemaVersion,

    required this.version,
  });

  @JsonKey(
    name: r'cohort',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        SessionBootstrapOnboardingCohortEnum.unknownDefaultOpenApi,
  )
  final SessionBootstrapOnboardingCohortEnum cohort;

  @JsonKey(name: r'completed_at', required: true, includeIfNull: true)
  final DateTime? completedAt;

  @JsonKey(name: r'completed_steps', required: true, includeIfNull: false)
  final List<String> completedSteps;

  @JsonKey(name: r'current_step', required: true, includeIfNull: false)
  final String currentStep;

  // minimum: 1
  // maximum: 2
  @JsonKey(name: r'schema_version', required: true, includeIfNull: false)
  final int schemaVersion;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionBootstrapOnboarding &&
          other.cohort == cohort &&
          other.completedAt == completedAt &&
          other.completedSteps == completedSteps &&
          other.currentStep == currentStep &&
          other.schemaVersion == schemaVersion &&
          other.version == version;

  @override
  int get hashCode =>
      cohort.hashCode +
      (completedAt == null ? 0 : completedAt.hashCode) +
      completedSteps.hashCode +
      currentStep.hashCode +
      schemaVersion.hashCode +
      version.hashCode;

  factory SessionBootstrapOnboarding.fromJson(Map<String, dynamic> json) =>
      _$SessionBootstrapOnboardingFromJson(json);

  Map<String, dynamic> toJson() => _$SessionBootstrapOnboardingToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum SessionBootstrapOnboardingCohortEnum {
  @JsonValue(r'legacy_complete_v1')
  legacyCompleteV1(r'legacy_complete_v1'),
  @JsonValue(r'legacy_incomplete_v1')
  legacyIncompleteV1(r'legacy_incomplete_v1'),
  @JsonValue(r'member_v2')
  memberV2(r'member_v2'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const SessionBootstrapOnboardingCohortEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
