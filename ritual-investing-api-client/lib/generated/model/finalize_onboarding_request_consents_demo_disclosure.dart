//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'finalize_onboarding_request_consents_demo_disclosure.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FinalizeOnboardingRequestConsentsDemoDisclosure {
  /// Returns a new [FinalizeOnboardingRequestConsentsDemoDisclosure] instance.
  FinalizeOnboardingRequestConsentsDemoDisclosure({
    required this.decision,

    required this.policyVersion,
  });

  @JsonKey(
    name: r'decision',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        FinalizeOnboardingRequestConsentsDemoDisclosureDecisionEnum
            .unknownDefaultOpenApi,
  )
  final FinalizeOnboardingRequestConsentsDemoDisclosureDecisionEnum decision;

  @JsonKey(
    name: r'policy_version',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        FinalizeOnboardingRequestConsentsDemoDisclosurePolicyVersionEnum
            .unknownDefaultOpenApi,
  )
  final FinalizeOnboardingRequestConsentsDemoDisclosurePolicyVersionEnum
  policyVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinalizeOnboardingRequestConsentsDemoDisclosure &&
          other.decision == decision &&
          other.policyVersion == policyVersion;

  @override
  int get hashCode => decision.hashCode + policyVersion.hashCode;

  factory FinalizeOnboardingRequestConsentsDemoDisclosure.fromJson(
    Map<String, dynamic> json,
  ) => _$FinalizeOnboardingRequestConsentsDemoDisclosureFromJson(json);

  Map<String, dynamic> toJson() =>
      _$FinalizeOnboardingRequestConsentsDemoDisclosureToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum FinalizeOnboardingRequestConsentsDemoDisclosureDecisionEnum {
  @JsonValue(r'accepted')
  accepted(r'accepted'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const FinalizeOnboardingRequestConsentsDemoDisclosureDecisionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum FinalizeOnboardingRequestConsentsDemoDisclosurePolicyVersionEnum {
  @JsonValue(r'2026-08')
  n202608(r'2026-08'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const FinalizeOnboardingRequestConsentsDemoDisclosurePolicyVersionEnum(
    this.value,
  );

  final String value;

  @override
  String toString() => value;
}
