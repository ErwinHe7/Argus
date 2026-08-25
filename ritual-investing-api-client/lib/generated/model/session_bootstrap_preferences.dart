//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/ritual_interest.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'session_bootstrap_preferences.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SessionBootstrapPreferences {
  /// Returns a new [SessionBootstrapPreferences] instance.
  SessionBootstrapPreferences({
    required this.locale,

    required this.ritualFamiliarity,

    required this.ritualInterests,

    required this.ritualLanguage,

    required this.ritualMode,

    required this.themeMode,

    required this.timezone,

    required this.version,
  });

  @JsonKey(name: r'locale', required: true, includeIfNull: false)
  final String locale;

  @JsonKey(
    name: r'ritual_familiarity',
    required: true,
    includeIfNull: true,
    unknownEnumValue:
        SessionBootstrapPreferencesRitualFamiliarityEnum.unknownDefaultOpenApi,
  )
  final SessionBootstrapPreferencesRitualFamiliarityEnum? ritualFamiliarity;

  @JsonKey(name: r'ritual_interests', required: true, includeIfNull: true)
  final List<RitualInterest>? ritualInterests;

  @JsonKey(
    name: r'ritual_language',
    required: true,
    includeIfNull: true,
    unknownEnumValue:
        SessionBootstrapPreferencesRitualLanguageEnum.unknownDefaultOpenApi,
  )
  final SessionBootstrapPreferencesRitualLanguageEnum? ritualLanguage;

  @JsonKey(
    name: r'ritual_mode',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        SessionBootstrapPreferencesRitualModeEnum.unknownDefaultOpenApi,
  )
  final SessionBootstrapPreferencesRitualModeEnum ritualMode;

  @JsonKey(
    name: r'theme_mode',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        SessionBootstrapPreferencesThemeModeEnum.unknownDefaultOpenApi,
  )
  final SessionBootstrapPreferencesThemeModeEnum themeMode;

  @JsonKey(name: r'timezone', required: true, includeIfNull: false)
  final String timezone;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionBootstrapPreferences &&
          other.locale == locale &&
          other.ritualFamiliarity == ritualFamiliarity &&
          other.ritualInterests == ritualInterests &&
          other.ritualLanguage == ritualLanguage &&
          other.ritualMode == ritualMode &&
          other.themeMode == themeMode &&
          other.timezone == timezone &&
          other.version == version;

  @override
  int get hashCode =>
      locale.hashCode +
      (ritualFamiliarity == null ? 0 : ritualFamiliarity.hashCode) +
      (ritualInterests == null ? 0 : ritualInterests.hashCode) +
      (ritualLanguage == null ? 0 : ritualLanguage.hashCode) +
      ritualMode.hashCode +
      themeMode.hashCode +
      timezone.hashCode +
      version.hashCode;

  factory SessionBootstrapPreferences.fromJson(Map<String, dynamic> json) =>
      _$SessionBootstrapPreferencesFromJson(json);

  Map<String, dynamic> toJson() => _$SessionBootstrapPreferencesToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum SessionBootstrapPreferencesRitualFamiliarityEnum {
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

  const SessionBootstrapPreferencesRitualFamiliarityEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum SessionBootstrapPreferencesRitualLanguageEnum {
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

  const SessionBootstrapPreferencesRitualLanguageEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum SessionBootstrapPreferencesRitualModeEnum {
  @JsonValue(r'tarot')
  tarot(r'tarot'),
  @JsonValue(r'astrology')
  astrology(r'astrology'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const SessionBootstrapPreferencesRitualModeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum SessionBootstrapPreferencesThemeModeEnum {
  @JsonValue(r'system')
  system(r'system'),
  @JsonValue(r'light')
  light(r'light'),
  @JsonValue(r'dark')
  dark(r'dark'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const SessionBootstrapPreferencesThemeModeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
