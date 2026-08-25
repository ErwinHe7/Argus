//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/finalize_onboarding_request_consents_demo_disclosure.dart';
import 'package:ritual_investing_api_client/generated/model/finalize_onboarding_request_consents_astrology.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'finalize_onboarding_request_consents.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FinalizeOnboardingRequestConsents {
  /// Returns a new [FinalizeOnboardingRequestConsents] instance.
  FinalizeOnboardingRequestConsents({
    required this.astrology,

    required this.demoDisclosure,

    required this.privacy,

    required this.terms,
  });

  @JsonKey(name: r'astrology', required: true, includeIfNull: false)
  final FinalizeOnboardingRequestConsentsAstrology astrology;

  @JsonKey(name: r'demo_disclosure', required: true, includeIfNull: false)
  final FinalizeOnboardingRequestConsentsDemoDisclosure demoDisclosure;

  @JsonKey(name: r'privacy', required: true, includeIfNull: false)
  final FinalizeOnboardingRequestConsentsDemoDisclosure privacy;

  @JsonKey(name: r'terms', required: true, includeIfNull: false)
  final FinalizeOnboardingRequestConsentsDemoDisclosure terms;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinalizeOnboardingRequestConsents &&
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

  factory FinalizeOnboardingRequestConsents.fromJson(
    Map<String, dynamic> json,
  ) => _$FinalizeOnboardingRequestConsentsFromJson(json);

  Map<String, dynamic> toJson() =>
      _$FinalizeOnboardingRequestConsentsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
