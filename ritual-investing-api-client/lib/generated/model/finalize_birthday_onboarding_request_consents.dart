//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/birthday_accepted_onboarding_consent.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'finalize_birthday_onboarding_request_consents.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FinalizeBirthdayOnboardingRequestConsents {
  /// Returns a new [FinalizeBirthdayOnboardingRequestConsents] instance.
  FinalizeBirthdayOnboardingRequestConsents({
    required this.astrology,

    required this.demoDisclosure,

    required this.privacy,

    required this.terms,
  });

  @JsonKey(name: r'astrology', required: true, includeIfNull: false)
  final BirthdayAcceptedOnboardingConsent astrology;

  @JsonKey(name: r'demo_disclosure', required: true, includeIfNull: false)
  final BirthdayAcceptedOnboardingConsent demoDisclosure;

  @JsonKey(name: r'privacy', required: true, includeIfNull: false)
  final BirthdayAcceptedOnboardingConsent privacy;

  @JsonKey(name: r'terms', required: true, includeIfNull: false)
  final BirthdayAcceptedOnboardingConsent terms;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinalizeBirthdayOnboardingRequestConsents &&
          other.astrology == astrology &&
          other.demoDisclosure == demoDisclosure &&
          other.privacy == privacy &&
          other.terms == terms;

  @override
  int get hashCode =>
      astrology.hashCode +
      demoDisclosure.hashCode +
      privacy.hashCode +
      terms.hashCode;

  factory FinalizeBirthdayOnboardingRequestConsents.fromJson(
    Map<String, dynamic> json,
  ) => _$FinalizeBirthdayOnboardingRequestConsentsFromJson(json);

  Map<String, dynamic> toJson() =>
      _$FinalizeBirthdayOnboardingRequestConsentsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
