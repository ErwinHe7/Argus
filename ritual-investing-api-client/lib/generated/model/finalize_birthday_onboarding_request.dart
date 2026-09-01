//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/finalize_birthday_onboarding_request_astrology.dart';
import 'package:ritual_investing_api_client/generated/model/finalize_birthday_onboarding_request_consents.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'finalize_birthday_onboarding_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FinalizeBirthdayOnboardingRequest {
  /// Returns a new [FinalizeBirthdayOnboardingRequest] instance.
  FinalizeBirthdayOnboardingRequest({
    required this.astrology,

    required this.consents,

    required this.expectedOnboardingVersion,

    required this.schemaVersion,
  });

  @JsonKey(name: r'astrology', required: true, includeIfNull: false)
  final FinalizeBirthdayOnboardingRequestAstrology astrology;

  @JsonKey(name: r'consents', required: true, includeIfNull: false)
  final FinalizeBirthdayOnboardingRequestConsents consents;

  // minimum: 0
  @JsonKey(
    name: r'expected_onboarding_version',
    required: true,
    includeIfNull: false,
  )
  final int expectedOnboardingVersion;

  // minimum: 3
  // maximum: 3
  @JsonKey(name: r'schema_version', required: true, includeIfNull: false)
  final int schemaVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinalizeBirthdayOnboardingRequest &&
          other.astrology == astrology &&
          other.consents == consents &&
          other.expectedOnboardingVersion == expectedOnboardingVersion &&
          other.schemaVersion == schemaVersion;

  @override
  int get hashCode =>
      astrology.hashCode +
      consents.hashCode +
      expectedOnboardingVersion.hashCode +
      schemaVersion.hashCode;

  factory FinalizeBirthdayOnboardingRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$FinalizeBirthdayOnboardingRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$FinalizeBirthdayOnboardingRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
