// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_preferences_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchPreferencesRequestCWProxy {
  PatchPreferencesRequest locale(String? locale);

  PatchPreferencesRequest ritualFamiliarity(
    PatchPreferencesRequestRitualFamiliarityEnum? ritualFamiliarity,
  );

  PatchPreferencesRequest ritualInterests(
    List<RitualInterest>? ritualInterests,
  );

  PatchPreferencesRequest ritualLanguage(
    PatchPreferencesRequestRitualLanguageEnum? ritualLanguage,
  );

  PatchPreferencesRequest ritualMode(
    PatchPreferencesRequestRitualModeEnum? ritualMode,
  );

  PatchPreferencesRequest themeMode(
    PatchPreferencesRequestThemeModeEnum? themeMode,
  );

  PatchPreferencesRequest timezone(String? timezone);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchPreferencesRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchPreferencesRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchPreferencesRequest call({
    String? locale,
    PatchPreferencesRequestRitualFamiliarityEnum? ritualFamiliarity,
    List<RitualInterest>? ritualInterests,
    PatchPreferencesRequestRitualLanguageEnum? ritualLanguage,
    PatchPreferencesRequestRitualModeEnum? ritualMode,
    PatchPreferencesRequestThemeModeEnum? themeMode,
    String? timezone,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchPreferencesRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchPreferencesRequest.copyWith.fieldName(...)`
class _$PatchPreferencesRequestCWProxyImpl
    implements _$PatchPreferencesRequestCWProxy {
  const _$PatchPreferencesRequestCWProxyImpl(this._value);

  final PatchPreferencesRequest _value;

  @override
  PatchPreferencesRequest locale(String? locale) => this(locale: locale);

  @override
  PatchPreferencesRequest ritualFamiliarity(
    PatchPreferencesRequestRitualFamiliarityEnum? ritualFamiliarity,
  ) => this(ritualFamiliarity: ritualFamiliarity);

  @override
  PatchPreferencesRequest ritualInterests(
    List<RitualInterest>? ritualInterests,
  ) => this(ritualInterests: ritualInterests);

  @override
  PatchPreferencesRequest ritualLanguage(
    PatchPreferencesRequestRitualLanguageEnum? ritualLanguage,
  ) => this(ritualLanguage: ritualLanguage);

  @override
  PatchPreferencesRequest ritualMode(
    PatchPreferencesRequestRitualModeEnum? ritualMode,
  ) => this(ritualMode: ritualMode);

  @override
  PatchPreferencesRequest themeMode(
    PatchPreferencesRequestThemeModeEnum? themeMode,
  ) => this(themeMode: themeMode);

  @override
  PatchPreferencesRequest timezone(String? timezone) =>
      this(timezone: timezone);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchPreferencesRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchPreferencesRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchPreferencesRequest call({
    Object? locale = const $CopyWithPlaceholder(),
    Object? ritualFamiliarity = const $CopyWithPlaceholder(),
    Object? ritualInterests = const $CopyWithPlaceholder(),
    Object? ritualLanguage = const $CopyWithPlaceholder(),
    Object? ritualMode = const $CopyWithPlaceholder(),
    Object? themeMode = const $CopyWithPlaceholder(),
    Object? timezone = const $CopyWithPlaceholder(),
  }) {
    return PatchPreferencesRequest(
      locale: locale == const $CopyWithPlaceholder()
          ? _value.locale
          // ignore: cast_nullable_to_non_nullable
          : locale as String?,
      ritualFamiliarity: ritualFamiliarity == const $CopyWithPlaceholder()
          ? _value.ritualFamiliarity
          // ignore: cast_nullable_to_non_nullable
          : ritualFamiliarity as PatchPreferencesRequestRitualFamiliarityEnum?,
      ritualInterests: ritualInterests == const $CopyWithPlaceholder()
          ? _value.ritualInterests
          // ignore: cast_nullable_to_non_nullable
          : ritualInterests as List<RitualInterest>?,
      ritualLanguage: ritualLanguage == const $CopyWithPlaceholder()
          ? _value.ritualLanguage
          // ignore: cast_nullable_to_non_nullable
          : ritualLanguage as PatchPreferencesRequestRitualLanguageEnum?,
      ritualMode: ritualMode == const $CopyWithPlaceholder()
          ? _value.ritualMode
          // ignore: cast_nullable_to_non_nullable
          : ritualMode as PatchPreferencesRequestRitualModeEnum?,
      themeMode: themeMode == const $CopyWithPlaceholder()
          ? _value.themeMode
          // ignore: cast_nullable_to_non_nullable
          : themeMode as PatchPreferencesRequestThemeModeEnum?,
      timezone: timezone == const $CopyWithPlaceholder()
          ? _value.timezone
          // ignore: cast_nullable_to_non_nullable
          : timezone as String?,
    );
  }
}

extension $PatchPreferencesRequestCopyWith on PatchPreferencesRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPatchPreferencesRequest.copyWith(...)` or like so:`instanceOfPatchPreferencesRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchPreferencesRequestCWProxy get copyWith =>
      _$PatchPreferencesRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchPreferencesRequest _$PatchPreferencesRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'PatchPreferencesRequest',
  json,
  ($checkedConvert) {
    final val = PatchPreferencesRequest(
      locale: $checkedConvert('locale', (v) => v as String?),
      ritualFamiliarity: $checkedConvert(
        'ritual_familiarity',
        (v) => $enumDecodeNullable(
          _$PatchPreferencesRequestRitualFamiliarityEnumEnumMap,
          v,
          unknownValue: PatchPreferencesRequestRitualFamiliarityEnum
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
          _$PatchPreferencesRequestRitualLanguageEnumEnumMap,
          v,
          unknownValue:
              PatchPreferencesRequestRitualLanguageEnum.unknownDefaultOpenApi,
        ),
      ),
      ritualMode: $checkedConvert(
        'ritual_mode',
        (v) => $enumDecodeNullable(
          _$PatchPreferencesRequestRitualModeEnumEnumMap,
          v,
          unknownValue:
              PatchPreferencesRequestRitualModeEnum.unknownDefaultOpenApi,
        ),
      ),
      themeMode: $checkedConvert(
        'theme_mode',
        (v) => $enumDecodeNullable(
          _$PatchPreferencesRequestThemeModeEnumEnumMap,
          v,
          unknownValue:
              PatchPreferencesRequestThemeModeEnum.unknownDefaultOpenApi,
        ),
      ),
      timezone: $checkedConvert('timezone', (v) => v as String?),
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

Map<String, dynamic> _$PatchPreferencesRequestToJson(
  PatchPreferencesRequest instance,
) => <String, dynamic>{
  'locale': ?instance.locale,
  'ritual_familiarity':
      ?_$PatchPreferencesRequestRitualFamiliarityEnumEnumMap[instance
          .ritualFamiliarity],
  'ritual_interests': ?instance.ritualInterests
      ?.map((e) => _$RitualInterestEnumMap[e]!)
      .toList(),
  'ritual_language':
      ?_$PatchPreferencesRequestRitualLanguageEnumEnumMap[instance
          .ritualLanguage],
  'ritual_mode':
      ?_$PatchPreferencesRequestRitualModeEnumEnumMap[instance.ritualMode],
  'theme_mode':
      ?_$PatchPreferencesRequestThemeModeEnumEnumMap[instance.themeMode],
  'timezone': ?instance.timezone,
};

const _$PatchPreferencesRequestRitualFamiliarityEnumEnumMap = {
  PatchPreferencesRequestRitualFamiliarityEnum.new_: 'new',
  PatchPreferencesRequestRitualFamiliarityEnum.curious: 'curious',
  PatchPreferencesRequestRitualFamiliarityEnum.familiar: 'familiar',
  PatchPreferencesRequestRitualFamiliarityEnum.practiced: 'practiced',
  PatchPreferencesRequestRitualFamiliarityEnum.preferNotToSay:
      'prefer_not_to_say',
  PatchPreferencesRequestRitualFamiliarityEnum.unknownDefaultOpenApi:
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

const _$PatchPreferencesRequestRitualLanguageEnumEnumMap = {
  PatchPreferencesRequestRitualLanguageEnum.practical: 'practical',
  PatchPreferencesRequestRitualLanguageEnum.balanced: 'balanced',
  PatchPreferencesRequestRitualLanguageEnum.mystical: 'mystical',
  PatchPreferencesRequestRitualLanguageEnum.preferNotToSay: 'prefer_not_to_say',
  PatchPreferencesRequestRitualLanguageEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$PatchPreferencesRequestRitualModeEnumEnumMap = {
  PatchPreferencesRequestRitualModeEnum.tarot: 'tarot',
  PatchPreferencesRequestRitualModeEnum.astrology: 'astrology',
  PatchPreferencesRequestRitualModeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$PatchPreferencesRequestThemeModeEnumEnumMap = {
  PatchPreferencesRequestThemeModeEnum.system: 'system',
  PatchPreferencesRequestThemeModeEnum.light: 'light',
  PatchPreferencesRequestThemeModeEnum.dark: 'dark',
  PatchPreferencesRequestThemeModeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
