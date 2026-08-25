// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_bootstrap_preferences.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SessionBootstrapPreferencesCWProxy {
  SessionBootstrapPreferences locale(String locale);

  SessionBootstrapPreferences ritualFamiliarity(
    SessionBootstrapPreferencesRitualFamiliarityEnum? ritualFamiliarity,
  );

  SessionBootstrapPreferences ritualInterests(
    List<RitualInterest>? ritualInterests,
  );

  SessionBootstrapPreferences ritualLanguage(
    SessionBootstrapPreferencesRitualLanguageEnum? ritualLanguage,
  );

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
    SessionBootstrapPreferencesRitualFamiliarityEnum? ritualFamiliarity,
    List<RitualInterest>? ritualInterests,
    SessionBootstrapPreferencesRitualLanguageEnum? ritualLanguage,
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
  SessionBootstrapPreferences ritualFamiliarity(
    SessionBootstrapPreferencesRitualFamiliarityEnum? ritualFamiliarity,
  ) => this(ritualFamiliarity: ritualFamiliarity);

  @override
  SessionBootstrapPreferences ritualInterests(
    List<RitualInterest>? ritualInterests,
  ) => this(ritualInterests: ritualInterests);

  @override
  SessionBootstrapPreferences ritualLanguage(
    SessionBootstrapPreferencesRitualLanguageEnum? ritualLanguage,
  ) => this(ritualLanguage: ritualLanguage);

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
    Object? ritualFamiliarity = const $CopyWithPlaceholder(),
    Object? ritualInterests = const $CopyWithPlaceholder(),
    Object? ritualLanguage = const $CopyWithPlaceholder(),
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
      ritualFamiliarity: ritualFamiliarity == const $CopyWithPlaceholder()
          ? _value.ritualFamiliarity
          // ignore: cast_nullable_to_non_nullable
          : ritualFamiliarity
                as SessionBootstrapPreferencesRitualFamiliarityEnum?,
      ritualInterests: ritualInterests == const $CopyWithPlaceholder()
          ? _value.ritualInterests
          // ignore: cast_nullable_to_non_nullable
          : ritualInterests as List<RitualInterest>?,
      ritualLanguage: ritualLanguage == const $CopyWithPlaceholder()
          ? _value.ritualLanguage
          // ignore: cast_nullable_to_non_nullable
          : ritualLanguage as SessionBootstrapPreferencesRitualLanguageEnum?,
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
) => $checkedCreate(
  'SessionBootstrapPreferences',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'locale',
        'ritual_familiarity',
        'ritual_interests',
        'ritual_language',
        'ritual_mode',
        'theme_mode',
        'timezone',
        'version',
      ],
    );
    final val = SessionBootstrapPreferences(
      locale: $checkedConvert('locale', (v) => v as String),
      ritualFamiliarity: $checkedConvert(
        'ritual_familiarity',
        (v) => $enumDecodeNullable(
          _$SessionBootstrapPreferencesRitualFamiliarityEnumEnumMap,
          v,
          unknownValue: SessionBootstrapPreferencesRitualFamiliarityEnum
              .unknownDefaultOpenApi,
        ),
      ),
      ritualInterests: $checkedConvert(
        'ritual_interests',
        (v) => (v as List<dynamic>?)
            ?.map((e) => $enumDecode(_$RitualInterestEnumMap, e))
            .toList(),
      ),
      ritualLanguage: $checkedConvert(
        'ritual_language',
        (v) => $enumDecodeNullable(
          _$SessionBootstrapPreferencesRitualLanguageEnumEnumMap,
          v,
          unknownValue: SessionBootstrapPreferencesRitualLanguageEnum
              .unknownDefaultOpenApi,
        ),
      ),
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
  },
  fieldKeyMap: const {
    'ritualFamiliarity': 'ritual_familiarity',
    'ritualInterests': 'ritual_interests',
    'ritualLanguage': 'ritual_language',
    'ritualMode': 'ritual_mode',
    'themeMode': 'theme_mode',
  },
);

Map<String, dynamic> _$SessionBootstrapPreferencesToJson(
  SessionBootstrapPreferences instance,
) => <String, dynamic>{
  'locale': instance.locale,
  'ritual_familiarity':
      _$SessionBootstrapPreferencesRitualFamiliarityEnumEnumMap[instance
          .ritualFamiliarity],
  'ritual_interests': instance.ritualInterests
      ?.map((e) => _$RitualInterestEnumMap[e]!)
      .toList(),
  'ritual_language':
      _$SessionBootstrapPreferencesRitualLanguageEnumEnumMap[instance
          .ritualLanguage],
  'ritual_mode':
      _$SessionBootstrapPreferencesRitualModeEnumEnumMap[instance.ritualMode]!,
  'theme_mode':
      _$SessionBootstrapPreferencesThemeModeEnumEnumMap[instance.themeMode]!,
  'timezone': instance.timezone,
  'version': instance.version,
};

const _$SessionBootstrapPreferencesRitualFamiliarityEnumEnumMap = {
  SessionBootstrapPreferencesRitualFamiliarityEnum.new_: 'new',
  SessionBootstrapPreferencesRitualFamiliarityEnum.curious: 'curious',
  SessionBootstrapPreferencesRitualFamiliarityEnum.familiar: 'familiar',
  SessionBootstrapPreferencesRitualFamiliarityEnum.practiced: 'practiced',
  SessionBootstrapPreferencesRitualFamiliarityEnum.preferNotToSay:
      'prefer_not_to_say',
  SessionBootstrapPreferencesRitualFamiliarityEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$RitualInterestEnumMap = {
  RitualInterest.practicalResearch: 'practical_research',
  RitualInterest.tarot: 'tarot',
  RitualInterest.astrology: 'astrology',
  RitualInterest.moonCycles: 'moon_cycles',
  RitualInterest.reflection: 'reflection',
  RitualInterest.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$SessionBootstrapPreferencesRitualLanguageEnumEnumMap = {
  SessionBootstrapPreferencesRitualLanguageEnum.practical: 'practical',
  SessionBootstrapPreferencesRitualLanguageEnum.balanced: 'balanced',
  SessionBootstrapPreferencesRitualLanguageEnum.mystical: 'mystical',
  SessionBootstrapPreferencesRitualLanguageEnum.preferNotToSay:
      'prefer_not_to_say',
  SessionBootstrapPreferencesRitualLanguageEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
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
