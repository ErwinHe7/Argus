// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_preferences.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemberPreferencesCWProxy {
  MemberPreferences deletionEpoch(int? deletionEpoch);

  MemberPreferences locale(String locale);

  MemberPreferences ritualMode(MemberPreferencesRitualModeEnum ritualMode);

  MemberPreferences themeMode(MemberPreferencesThemeModeEnum themeMode);

  MemberPreferences timezone(String timezone);

  MemberPreferences userId(String userId);

  MemberPreferences version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberPreferences(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberPreferences(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberPreferences call({
    int? deletionEpoch,
    String locale,
    MemberPreferencesRitualModeEnum ritualMode,
    MemberPreferencesThemeModeEnum themeMode,
    String timezone,
    String userId,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemberPreferences.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemberPreferences.copyWith.fieldName(...)`
class _$MemberPreferencesCWProxyImpl implements _$MemberPreferencesCWProxy {
  const _$MemberPreferencesCWProxyImpl(this._value);

  final MemberPreferences _value;

  @override
  MemberPreferences deletionEpoch(int? deletionEpoch) =>
      this(deletionEpoch: deletionEpoch);

  @override
  MemberPreferences locale(String locale) => this(locale: locale);

  @override
  MemberPreferences ritualMode(MemberPreferencesRitualModeEnum ritualMode) =>
      this(ritualMode: ritualMode);

  @override
  MemberPreferences themeMode(MemberPreferencesThemeModeEnum themeMode) =>
      this(themeMode: themeMode);

  @override
  MemberPreferences timezone(String timezone) => this(timezone: timezone);

  @override
  MemberPreferences userId(String userId) => this(userId: userId);

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
    Object? deletionEpoch = const $CopyWithPlaceholder(),
    Object? locale = const $CopyWithPlaceholder(),
    Object? ritualMode = const $CopyWithPlaceholder(),
    Object? themeMode = const $CopyWithPlaceholder(),
    Object? timezone = const $CopyWithPlaceholder(),
    Object? userId = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return MemberPreferences(
      deletionEpoch: deletionEpoch == const $CopyWithPlaceholder()
          ? _value.deletionEpoch
          // ignore: cast_nullable_to_non_nullable
          : deletionEpoch as int?,
      locale: locale == const $CopyWithPlaceholder()
          ? _value.locale
          // ignore: cast_nullable_to_non_nullable
          : locale as String,
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
      userId: userId == const $CopyWithPlaceholder()
          ? _value.userId
          // ignore: cast_nullable_to_non_nullable
          : userId as String,
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
        'deletion_epoch',
        'locale',
        'ritual_mode',
        'theme_mode',
        'timezone',
        'user_id',
        'version',
      ],
    );
    final val = MemberPreferences(
      deletionEpoch: $checkedConvert(
        'deletion_epoch',
        (v) => (v as num?)?.toInt(),
      ),
      locale: $checkedConvert('locale', (v) => v as String),
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
      userId: $checkedConvert('user_id', (v) => v as String),
      version: $checkedConvert('version', (v) => (v as num).toInt()),
    );
    return val;
  },
  fieldKeyMap: const {
    'deletionEpoch': 'deletion_epoch',
    'ritualMode': 'ritual_mode',
    'themeMode': 'theme_mode',
    'userId': 'user_id',
  },
);

Map<String, dynamic> _$MemberPreferencesToJson(
  MemberPreferences instance,
) => <String, dynamic>{
  'deletion_epoch': instance.deletionEpoch,
  'locale': instance.locale,
  'ritual_mode': _$MemberPreferencesRitualModeEnumEnumMap[instance.ritualMode]!,
  'theme_mode': _$MemberPreferencesThemeModeEnumEnumMap[instance.themeMode]!,
  'timezone': instance.timezone,
  'user_id': instance.userId,
  'version': instance.version,
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
