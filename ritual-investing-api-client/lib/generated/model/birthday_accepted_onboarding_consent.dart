//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'birthday_accepted_onboarding_consent.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BirthdayAcceptedOnboardingConsent {
  /// Returns a new [BirthdayAcceptedOnboardingConsent] instance.
  BirthdayAcceptedOnboardingConsent({
    required this.decision,

    required this.policyVersion,
  });

  @JsonKey(
    name: r'decision',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        BirthdayAcceptedOnboardingConsentDecisionEnum.unknownDefaultOpenApi,
  )
  final BirthdayAcceptedOnboardingConsentDecisionEnum decision;

  @JsonKey(name: r'policy_version', required: true, includeIfNull: false)
  final String policyVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BirthdayAcceptedOnboardingConsent &&
          other.decision == decision &&
          other.policyVersion == policyVersion;

  @override
  int get hashCode => decision.hashCode + policyVersion.hashCode;

  factory BirthdayAcceptedOnboardingConsent.fromJson(
    Map<String, dynamic> json,
  ) => _$BirthdayAcceptedOnboardingConsentFromJson(json);

  Map<String, dynamic> toJson() =>
      _$BirthdayAcceptedOnboardingConsentToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum BirthdayAcceptedOnboardingConsentDecisionEnum {
  @JsonValue(r'accepted')
  accepted(r'accepted'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const BirthdayAcceptedOnboardingConsentDecisionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
