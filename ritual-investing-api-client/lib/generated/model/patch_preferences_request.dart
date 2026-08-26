//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/ritual_interest.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patch_preferences_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchPreferencesRequest {
  /// Returns a new [PatchPreferencesRequest] instance.
  PatchPreferencesRequest({
    this.locale,

    this.ritualFamiliarity,

    this.ritualInterests,

    this.ritualLanguage,

    this.ritualMode,

    this.themeMode,

    this.timezone,
  });

  @JsonKey(name: r'locale', required: false, includeIfNull: false)
  final String? locale;

  @JsonKey(
    name: r'ritual_familiarity',
    required: false,
    includeIfNull: false,
    unknownEnumValue:
        PatchPreferencesRequestRitualFamiliarityEnum.unknownDefaultOpenApi,
  )
  final PatchPreferencesRequestRitualFamiliarityEnum? ritualFamiliarity;

  @JsonKey(name: r'ritual_interests', required: false, includeIfNull: false)
  final List<RitualInterest>? ritualInterests;

  @JsonKey(
    name: r'ritual_language',
    required: false,
    includeIfNull: false,
    unknownEnumValue:
        PatchPreferencesRequestRitualLanguageEnum.unknownDefaultOpenApi,
  )
  final PatchPreferencesRequestRitualLanguageEnum? ritualLanguage;

  @JsonKey(
    name: r'ritual_mode',
    required: false,
    includeIfNull: false,
    unknownEnumValue:
        PatchPreferencesRequestRitualModeEnum.unknownDefaultOpenApi,
  )
  final PatchPreferencesRequestRitualModeEnum? ritualMode;

  @JsonKey(
    name: r'theme_mode',
    required: false,
    includeIfNull: false,
    unknownEnumValue:
        PatchPreferencesRequestThemeModeEnum.unknownDefaultOpenApi,
  )
  final PatchPreferencesRequestThemeModeEnum? themeMode;

  @JsonKey(name: r'timezone', required: false, includeIfNull: false)
  final String? timezone;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchPreferencesRequest &&
          other.locale == locale &&
          other.ritualFamiliarity == ritualFamiliarity &&
          other.ritualInterests == ritualInterests &&
          other.ritualLanguage == ritualLanguage &&
          other.ritualMode == ritualMode &&
          other.themeMode == themeMode &&
          other.timezone == timezone;

  @override
  int get hashCode =>
      locale.hashCode +
      (ritualFamiliarity == null ? 0 : ritualFamiliarity.hashCode) +
      (ritualInterests == null ? 0 : ritualInterests.hashCode) +
      (ritualLanguage == null ? 0 : ritualLanguage.hashCode) +
      ritualMode.hashCode +
      themeMode.hashCode +
      timezone.hashCode;

  factory PatchPreferencesRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchPreferencesRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PatchPreferencesRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum PatchPreferencesRequestRitualFamiliarityEnum {
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

  const PatchPreferencesRequestRitualFamiliarityEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum PatchPreferencesRequestRitualLanguageEnum {
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

  const PatchPreferencesRequestRitualLanguageEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum PatchPreferencesRequestRitualModeEnum {
  @JsonValue(r'tarot')
  tarot(r'tarot'),
  @JsonValue(r'astrology')
  astrology(r'astrology'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PatchPreferencesRequestRitualModeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum PatchPreferencesRequestThemeModeEnum {
  @JsonValue(r'system')
  system(r'system'),
  @JsonValue(r'light')
  light(r'light'),
  @JsonValue(r'dark')
  dark(r'dark'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PatchPreferencesRequestThemeModeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
