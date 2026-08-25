//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/ritual_interest.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'finalize_onboarding_request_ritual.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FinalizeOnboardingRequestRitual {
  /// Returns a new [FinalizeOnboardingRequestRitual] instance.
  FinalizeOnboardingRequestRitual({
    required this.familiarity,

    required this.interests,

    required this.languagePreference,
  });

  @JsonKey(
    name: r'familiarity',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        FinalizeOnboardingRequestRitualFamiliarityEnum.unknownDefaultOpenApi,
  )
  final FinalizeOnboardingRequestRitualFamiliarityEnum familiarity;

  @JsonKey(name: r'interests', required: true, includeIfNull: false)
  final List<RitualInterest> interests;

  @JsonKey(
    name: r'language_preference',
    required: true,
    includeIfNull: false,
    unknownEnumValue: FinalizeOnboardingRequestRitualLanguagePreferenceEnum
        .unknownDefaultOpenApi,
  )
  final FinalizeOnboardingRequestRitualLanguagePreferenceEnum
  languagePreference;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinalizeOnboardingRequestRitual &&
          other.familiarity == familiarity &&
          other.interests == interests &&
          other.languagePreference == languagePreference;

  @override
  int get hashCode =>
      familiarity.hashCode + interests.hashCode + languagePreference.hashCode;

  factory FinalizeOnboardingRequestRitual.fromJson(Map<String, dynamic> json) =>
      _$FinalizeOnboardingRequestRitualFromJson(json);

  Map<String, dynamic> toJson() =>
      _$FinalizeOnboardingRequestRitualToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum FinalizeOnboardingRequestRitualFamiliarityEnum {
  @JsonValue(r'new')
  new_(r'new'),
  @JsonValue(r'curious')
  curious(r'curious'),
  @JsonValue(r'familiar')
  familiar(r'familiar'),
  @JsonValue(r'practiced')
  practiced(r'practiced'),
  @JsonValue(r'prefer_not_to_say')
  preferNotToSay(r'prefer_not_to_say'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const FinalizeOnboardingRequestRitualFamiliarityEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum FinalizeOnboardingRequestRitualLanguagePreferenceEnum {
  @JsonValue(r'practical')
  practical(r'practical'),
  @JsonValue(r'balanced')
  balanced(r'balanced'),
  @JsonValue(r'mystical')
  mystical(r'mystical'),
  @JsonValue(r'prefer_not_to_say')
  preferNotToSay(r'prefer_not_to_say'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const FinalizeOnboardingRequestRitualLanguagePreferenceEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
