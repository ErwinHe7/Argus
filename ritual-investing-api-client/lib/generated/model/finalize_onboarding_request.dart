//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/finalize_onboarding_request_ritual.dart';
import 'package:ritual_investing_api_client/generated/model/finalize_onboarding_request_investing.dart';
import 'package:ritual_investing_api_client/generated/model/finalize_onboarding_request_astrology.dart';
import 'package:ritual_investing_api_client/generated/model/finalize_onboarding_request_consents.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'finalize_onboarding_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FinalizeOnboardingRequest {
  /// Returns a new [FinalizeOnboardingRequest] instance.
  FinalizeOnboardingRequest({
    required this.astrology,

    required this.consents,

    required this.expectedOnboardingVersion,

    required this.investing,

    required this.ritual,

    required this.schemaVersion,
  });

  @JsonKey(name: r'astrology', required: true, includeIfNull: false)
  final FinalizeOnboardingRequestAstrology astrology;

  @JsonKey(name: r'consents', required: true, includeIfNull: false)
  final FinalizeOnboardingRequestConsents consents;

  // minimum: 0
  @JsonKey(
    name: r'expected_onboarding_version',
    required: true,
    includeIfNull: false,
  )
  final int expectedOnboardingVersion;

  @JsonKey(name: r'investing', required: true, includeIfNull: false)
  final FinalizeOnboardingRequestInvesting investing;

  @JsonKey(name: r'ritual', required: true, includeIfNull: false)
  final FinalizeOnboardingRequestRitual ritual;

  // minimum: 2
  // maximum: 2
  @JsonKey(name: r'schema_version', required: true, includeIfNull: false)
  final int schemaVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinalizeOnboardingRequest &&
          other.astrology == astrology &&
          other.consents == consents &&
          other.expectedOnboardingVersion == expectedOnboardingVersion &&
          other.investing == investing &&
          other.ritual == ritual &&
          other.schemaVersion == schemaVersion;

  @override
  int get hashCode =>
      astrology.hashCode +
      consents.hashCode +
      expectedOnboardingVersion.hashCode +
      investing.hashCode +
      ritual.hashCode +
      schemaVersion.hashCode;

  factory FinalizeOnboardingRequest.fromJson(Map<String, dynamic> json) =>
      _$FinalizeOnboardingRequestFromJson(json);

  Map<String, dynamic> toJson() => _$FinalizeOnboardingRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
