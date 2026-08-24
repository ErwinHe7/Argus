//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'member_preferences.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MemberPreferences {
  /// Returns a new [MemberPreferences] instance.
  MemberPreferences({
    required this.locale,

    required this.ritualMode,

    required this.themeMode,

    required this.timezone,

    required this.version,
  });

  @JsonKey(name: r'locale', required: true, includeIfNull: false)
  final String locale;

  @JsonKey(
    name: r'ritual_mode',
    required: true,
    includeIfNull: false,
    unknownEnumValue: MemberPreferencesRitualModeEnum.unknownDefaultOpenApi,
  )
  final MemberPreferencesRitualModeEnum ritualMode;

  @JsonKey(
    name: r'theme_mode',
    required: true,
    includeIfNull: false,
    unknownEnumValue: MemberPreferencesThemeModeEnum.unknownDefaultOpenApi,
  )
  final MemberPreferencesThemeModeEnum themeMode;

  @JsonKey(name: r'timezone', required: true, includeIfNull: false)
  final String timezone;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberPreferences &&
          other.locale == locale &&
          other.ritualMode == ritualMode &&
          other.themeMode == themeMode &&
          other.timezone == timezone &&
          other.version == version;

  @override
  int get hashCode =>
      locale.hashCode +
      ritualMode.hashCode +
      themeMode.hashCode +
      timezone.hashCode +
      version.hashCode;

  factory MemberPreferences.fromJson(Map<String, dynamic> json) =>
      _$MemberPreferencesFromJson(json);

  Map<String, dynamic> toJson() => _$MemberPreferencesToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum MemberPreferencesRitualModeEnum {
  @JsonValue(r'tarot')
  tarot(r'tarot'),
  @JsonValue(r'astrology')
  astrology(r'astrology'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const MemberPreferencesRitualModeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum MemberPreferencesThemeModeEnum {
  @JsonValue(r'system')
  system(r'system'),
  @JsonValue(r'light')
  light(r'light'),
  @JsonValue(r'dark')
  dark(r'dark'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const MemberPreferencesThemeModeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
