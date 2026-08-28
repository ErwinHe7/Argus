//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'finalize_onboarding_request_consents_astrology.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FinalizeOnboardingRequestConsentsAstrology {
  /// Returns a new [FinalizeOnboardingRequestConsentsAstrology] instance.
  FinalizeOnboardingRequestConsentsAstrology({
    required this.decision,

    required this.policyVersion,
  });

  @JsonKey(
    name: r'decision',
    required: true,
    includeIfNull: false,
    unknownEnumValue: FinalizeOnboardingRequestConsentsAstrologyDecisionEnum
        .unknownDefaultOpenApi,
  )
  final FinalizeOnboardingRequestConsentsAstrologyDecisionEnum decision;

  @JsonKey(name: r'policy_version', required: true, includeIfNull: false)
  final String policyVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinalizeOnboardingRequestConsentsAstrology &&
          other.decision == decision &&
          other.policyVersion == policyVersion;

  @override
  int get hashCode => decision.hashCode + policyVersion.hashCode;

  factory FinalizeOnboardingRequestConsentsAstrology.fromJson(
    Map<String, dynamic> json,
  ) => _$FinalizeOnboardingRequestConsentsAstrologyFromJson(json);

  Map<String, dynamic> toJson() =>
      _$FinalizeOnboardingRequestConsentsAstrologyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum FinalizeOnboardingRequestConsentsAstrologyDecisionEnum {
  @JsonValue(r'accepted')
  accepted(r'accepted'),
  @JsonValue(r'declined')
  declined(r'declined'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const FinalizeOnboardingRequestConsentsAstrologyDecisionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
