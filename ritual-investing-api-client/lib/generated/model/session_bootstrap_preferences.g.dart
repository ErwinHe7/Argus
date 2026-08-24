// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_bootstrap_preferences.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SessionBootstrapPreferencesCWProxy {
  SessionBootstrapPreferences locale(String locale);

  SessionBootstrapPreferences ritualMode(
    SessionBootstrapPreferencesRitualModeEnum ritualMode,
  );

  SessionBootstrapPreferences themeMode(
    SessionBootstrapPreferencesThemeModeEnum themeMode,
  );

  SessionBootstrapPreferences timezone(String timezone);

  SessionBootstrapPreferences version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionBootstrapPreferences(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionBootstrapPreferences(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionBootstrapPreferences call({
    String locale,
    SessionBootstrapPreferencesRitualModeEnum ritualMode,
    SessionBootstrapPreferencesThemeModeEnum themeMode,
    String timezone,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSessionBootstrapPreferences.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSessionBootstrapPreferences.copyWith.fieldName(...)`
class _$SessionBootstrapPreferencesCWProxyImpl
    implements _$SessionBootstrapPreferencesCWProxy {
  const _$SessionBootstrapPreferencesCWProxyImpl(this._value);

  final SessionBootstrapPreferences _value;

  @override
  SessionBootstrapPreferences locale(String locale) => this(locale: locale);

  @override
  SessionBootstrapPreferences ritualMode(
    SessionBootstrapPreferencesRitualModeEnum ritualMode,
  ) => this(ritualMode: ritualMode);

  @override
  SessionBootstrapPreferences themeMode(
    SessionBootstrapPreferencesThemeModeEnum themeMode,
  ) => this(themeMode: themeMode);

  @override
  SessionBootstrapPreferences timezone(String timezone) =>
      this(timezone: timezone);

  @override
  SessionBootstrapPreferences version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionBootstrapPreferences(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionBootstrapPreferences(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionBootstrapPreferences call({
    Object? locale = const $CopyWithPlaceholder(),
    Object? ritualMode = const $CopyWithPlaceholder(),
    Object? themeMode = const $CopyWithPlaceholder(),
    Object? timezone = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return SessionBootstrapPreferences(
      locale: locale == const $CopyWithPlaceholder()
          ? _value.locale
          // ignore: cast_nullable_to_non_nullable
          : locale as String,
      ritualMode: ritualMode == const $CopyWithPlaceholder()
          ? _value.ritualMode
          // ignore: cast_nullable_to_non_nullable
          : ritualMode as SessionBootstrapPreferencesRitualModeEnum,
      themeMode: themeMode == const $CopyWithPlaceholder()
          ? _value.themeMode
          // ignore: cast_nullable_to_non_nullable
          : themeMode as SessionBootstrapPreferencesThemeModeEnum,
      timezone: timezone == const $CopyWithPlaceholder()
          ? _value.timezone
          // ignore: cast_nullable_to_non_nullable
          : timezone as String,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $SessionBootstrapPreferencesCopyWith on SessionBootstrapPreferences {
  /// Returns a callable class that can be used as follows: `instanceOfSessionBootstrapPreferences.copyWith(...)` or like so:`instanceOfSessionBootstrapPreferences.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SessionBootstrapPreferencesCWProxy get copyWith =>
      _$SessionBootstrapPreferencesCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionBootstrapPreferences _$SessionBootstrapPreferencesFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SessionBootstrapPreferences', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'locale',
      'ritual_mode',
      'theme_mode',
      'timezone',
      'version',
    ],
  );
  final val = SessionBootstrapPreferences(
    locale: $checkedConvert('locale', (v) => v as String),
    ritualMode: $checkedConvert(
      'ritual_mode',
      (v) => $enumDecode(
        _$SessionBootstrapPreferencesRitualModeEnumEnumMap,
        v,
        unknownValue:
            SessionBootstrapPreferencesRitualModeEnum.unknownDefaultOpenApi,
      ),
    ),
    themeMode: $checkedConvert(
      'theme_mode',
      (v) => $enumDecode(
        _$SessionBootstrapPreferencesThemeModeEnumEnumMap,
        v,
        unknownValue:
            SessionBootstrapPreferencesThemeModeEnum.unknownDefaultOpenApi,
      ),
    ),
    timezone: $checkedConvert('timezone', (v) => v as String),
    version: $checkedConvert('version', (v) => (v as num).toInt()),
  );
  return val;
}, fieldKeyMap: const {'ritualMode': 'ritual_mode', 'themeMode': 'theme_mode'});

Map<String, dynamic> _$SessionBootstrapPreferencesToJson(
  SessionBootstrapPreferences instance,
) => <String, dynamic>{
  'locale': instance.locale,
  'ritual_mode':
      _$SessionBootstrapPreferencesRitualModeEnumEnumMap[instance.ritualMode]!,
  'theme_mode':
      _$SessionBootstrapPreferencesThemeModeEnumEnumMap[instance.themeMode]!,
  'timezone': instance.timezone,
  'version': instance.version,
};

const _$SessionBootstrapPreferencesRitualModeEnumEnumMap = {
  SessionBootstrapPreferencesRitualModeEnum.tarot: 'tarot',
  SessionBootstrapPreferencesRitualModeEnum.astrology: 'astrology',
  SessionBootstrapPreferencesRitualModeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$SessionBootstrapPreferencesThemeModeEnumEnumMap = {
  SessionBootstrapPreferencesThemeModeEnum.system: 'system',
  SessionBootstrapPreferencesThemeModeEnum.light: 'light',
  SessionBootstrapPreferencesThemeModeEnum.dark: 'dark',
  SessionBootstrapPreferencesThemeModeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
