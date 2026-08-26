// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_preferences.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemberPreferencesCWProxy {
  MemberPreferences locale(String locale);

  MemberPreferences ritualFamiliarity(
    MemberPreferencesRitualFamiliarityEnum? ritualFamiliarity,
  );

  MemberPreferences ritualInterests(List<RitualInterest>? ritualInterests);

  MemberPreferences ritualLanguage(
    MemberPreferencesRitualLanguageEnum? ritualLanguage,
  );

  MemberPreferences ritualMode(MemberPreferencesRitualModeEnum ritualMode);

  MemberPreferences themeMode(MemberPreferencesThemeModeEnum themeMode);

  MemberPreferences timezone(String timezone);

  MemberPreferences version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberPreferences(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberPreferences(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberPreferences call({
    String locale,
    MemberPreferencesRitualFamiliarityEnum? ritualFamiliarity,
    List<RitualInterest>? ritualInterests,
    MemberPreferencesRitualLanguageEnum? ritualLanguage,
    MemberPreferencesRitualModeEnum ritualMode,
    MemberPreferencesThemeModeEnum themeMode,
    String timezone,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemberPreferences.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemberPreferences.copyWith.fieldName(...)`
class _$MemberPreferencesCWProxyImpl implements _$MemberPreferencesCWProxy {
  const _$MemberPreferencesCWProxyImpl(this._value);

  final MemberPreferences _value;

  @override
  MemberPreferences locale(String locale) => this(locale: locale);

  @override
  MemberPreferences ritualFamiliarity(
    MemberPreferencesRitualFamiliarityEnum? ritualFamiliarity,
  ) => this(ritualFamiliarity: ritualFamiliarity);

  @override
  MemberPreferences ritualInterests(List<RitualInterest>? ritualInterests) =>
      this(ritualInterests: ritualInterests);

  @override
  MemberPreferences ritualLanguage(
    MemberPreferencesRitualLanguageEnum? ritualLanguage,
  ) => this(ritualLanguage: ritualLanguage);

  @override
  MemberPreferences ritualMode(MemberPreferencesRitualModeEnum ritualMode) =>
      this(ritualMode: ritualMode);

  @override
  MemberPreferences themeMode(MemberPreferencesThemeModeEnum themeMode) =>
      this(themeMode: themeMode);

  @override
  MemberPreferences timezone(String timezone) => this(timezone: timezone);

  @override
  MemberPreferences version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberPreferences(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberPreferences(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberPreferences call({
    Object? locale = const $CopyWithPlaceholder(),
    Object? ritualFamiliarity = const $CopyWithPlaceholder(),
    Object? ritualInterests = const $CopyWithPlaceholder(),
    Object? ritualLanguage = const $CopyWithPlaceholder(),
    Object? ritualMode = const $CopyWithPlaceholder(),
    Object? themeMode = const $CopyWithPlaceholder(),
    Object? timezone = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return MemberPreferences(
      locale: locale == const $CopyWithPlaceholder()
          ? _value.locale
          // ignore: cast_nullable_to_non_nullable
          : locale as String,
      ritualFamiliarity: ritualFamiliarity == const $CopyWithPlaceholder()
          ? _value.ritualFamiliarity
          // ignore: cast_nullable_to_non_nullable
          : ritualFamiliarity as MemberPreferencesRitualFamiliarityEnum?,
      ritualInterests: ritualInterests == const $CopyWithPlaceholder()
          ? _value.ritualInterests
          // ignore: cast_nullable_to_non_nullable
          : ritualInterests as List<RitualInterest>?,
      ritualLanguage: ritualLanguage == const $CopyWithPlaceholder()
          ? _value.ritualLanguage
          // ignore: cast_nullable_to_non_nullable
          : ritualLanguage as MemberPreferencesRitualLanguageEnum?,
      ritualMode: ritualMode == const $CopyWithPlaceholder()
          ? _value.ritualMode
          // ignore: cast_nullable_to_non_nullable
          : ritualMode as MemberPreferencesRitualModeEnum,
      themeMode: themeMode == const $CopyWithPlaceholder()
          ? _value.themeMode
          // ignore: cast_nullable_to_non_nullable
          : themeMode as MemberPreferencesThemeModeEnum,
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

extension $MemberPreferencesCopyWith on MemberPreferences {
  /// Returns a callable class that can be used as follows: `instanceOfMemberPreferences.copyWith(...)` or like so:`instanceOfMemberPreferences.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MemberPreferencesCWProxy get copyWith =>
      _$MemberPreferencesCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemberPreferences _$MemberPreferencesFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'MemberPreferences',
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
    final val = MemberPreferences(
      locale: $checkedConvert('locale', (v) => v as String),
      ritualFamiliarity: $checkedConvert(
        'ritual_familiarity',
        (v) => $enumDecodeNullable(
          _$MemberPreferencesRitualFamiliarityEnumEnumMap,
          v,
          unknownValue:
              MemberPreferencesRitualFamiliarityEnum.unknownDefaultOpenApi,
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
          _$MemberPreferencesRitualLanguageEnumEnumMap,
          v,
          unknownValue:
              MemberPreferencesRitualLanguageEnum.unknownDefaultOpenApi,
        ),
      ),
      ritualMode: $checkedConvert(
        'ritual_mode',
        (v) => $enumDecode(
          _$MemberPreferencesRitualModeEnumEnumMap,
          v,
          unknownValue: MemberPreferencesRitualModeEnum.unknownDefaultOpenApi,
        ),
      ),
      themeMode: $checkedConvert(
        'theme_mode',
        (v) => $enumDecode(
          _$MemberPreferencesThemeModeEnumEnumMap,
          v,
          unknownValue: MemberPreferencesThemeModeEnum.unknownDefaultOpenApi,
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

Map<String, dynamic> _$MemberPreferencesToJson(
  MemberPreferences instance,
) => <String, dynamic>{
  'locale': instance.locale,
  'ritual_familiarity':
      _$MemberPreferencesRitualFamiliarityEnumEnumMap[instance
          .ritualFamiliarity],
  'ritual_interests': instance.ritualInterests
      ?.map((e) => _$RitualInterestEnumMap[e]!)
      .toList(),
  'ritual_language':
      _$MemberPreferencesRitualLanguageEnumEnumMap[instance.ritualLanguage],
  'ritual_mode': _$MemberPreferencesRitualModeEnumEnumMap[instance.ritualMode]!,
  'theme_mode': _$MemberPreferencesThemeModeEnumEnumMap[instance.themeMode]!,
  'timezone': instance.timezone,
  'version': instance.version,
};

const _$MemberPreferencesRitualFamiliarityEnumEnumMap = {
  MemberPreferencesRitualFamiliarityEnum.new_: 'new',
  MemberPreferencesRitualFamiliarityEnum.curious: 'curious',
  MemberPreferencesRitualFamiliarityEnum.familiar: 'familiar',
  MemberPreferencesRitualFamiliarityEnum.practiced: 'practiced',
  MemberPreferencesRitualFamiliarityEnum.preferNotToSay: 'prefer_not_to_say',
  MemberPreferencesRitualFamiliarityEnum.unknownDefaultOpenApi:
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

const _$MemberPreferencesRitualLanguageEnumEnumMap = {
  MemberPreferencesRitualLanguageEnum.practical: 'practical',
  MemberPreferencesRitualLanguageEnum.balanced: 'balanced',
  MemberPreferencesRitualLanguageEnum.mystical: 'mystical',
  MemberPreferencesRitualLanguageEnum.preferNotToSay: 'prefer_not_to_say',
  MemberPreferencesRitualLanguageEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$MemberPreferencesRitualModeEnumEnumMap = {
  MemberPreferencesRitualModeEnum.tarot: 'tarot',
  MemberPreferencesRitualModeEnum.astrology: 'astrology',
  MemberPreferencesRitualModeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$MemberPreferencesThemeModeEnumEnumMap = {
  MemberPreferencesThemeModeEnum.system: 'system',
  MemberPreferencesThemeModeEnum.light: 'light',
  MemberPreferencesThemeModeEnum.dark: 'dark',
  MemberPreferencesThemeModeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
