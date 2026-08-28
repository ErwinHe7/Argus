//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'update_preferences_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class UpdatePreferencesRequest {
  /// Returns a new [UpdatePreferencesRequest] instance.
  UpdatePreferencesRequest({
    this.locale,

    this.ritualMode,

    this.themeMode,

    this.timezone,
  });

  @JsonKey(name: r'locale', required: false, includeIfNull: false)
  final String? locale;

  @JsonKey(
    name: r'ritualMode',
    required: false,
    includeIfNull: false,
    unknownEnumValue:
        UpdatePreferencesRequestRitualModeEnum.unknownDefaultOpenApi,
  )
  final UpdatePreferencesRequestRitualModeEnum? ritualMode;

  @JsonKey(
    name: r'themeMode',
    required: false,
    includeIfNull: false,
    unknownEnumValue:
        UpdatePreferencesRequestThemeModeEnum.unknownDefaultOpenApi,
  )
  final UpdatePreferencesRequestThemeModeEnum? themeMode;

  @JsonKey(name: r'timezone', required: false, includeIfNull: false)
  final String? timezone;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdatePreferencesRequest &&
          other.locale == locale &&
          other.ritualMode == ritualMode &&
          other.themeMode == themeMode &&
          other.timezone == timezone;

  @override
  int get hashCode =>
      locale.hashCode +
      ritualMode.hashCode +
      themeMode.hashCode +
      timezone.hashCode;

  factory UpdatePreferencesRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdatePreferencesRequestFromJson(json);

  Map<String, dynamic> toJson() => _$UpdatePreferencesRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum UpdatePreferencesRequestRitualModeEnum {
  @JsonValue(r'tarot')
  tarot(r'tarot'),
  @JsonValue(r'astrology')
  astrology(r'astrology'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const UpdatePreferencesRequestRitualModeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum UpdatePreferencesRequestThemeModeEnum {
  @JsonValue(r'system')
  system(r'system'),
  @JsonValue(r'light')
  light(r'light'),
  @JsonValue(r'dark')
  dark(r'dark'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const UpdatePreferencesRequestThemeModeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
