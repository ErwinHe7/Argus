// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_preferences_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$UpdatePreferencesRequestCWProxy {
  UpdatePreferencesRequest locale(String? locale);

  UpdatePreferencesRequest ritualMode(
    UpdatePreferencesRequestRitualModeEnum? ritualMode,
  );

  UpdatePreferencesRequest themeMode(
    UpdatePreferencesRequestThemeModeEnum? themeMode,
  );

  UpdatePreferencesRequest timezone(String? timezone);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `UpdatePreferencesRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// UpdatePreferencesRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  UpdatePreferencesRequest call({
    String? locale,
    UpdatePreferencesRequestRitualModeEnum? ritualMode,
    UpdatePreferencesRequestThemeModeEnum? themeMode,
    String? timezone,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfUpdatePreferencesRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfUpdatePreferencesRequest.copyWith.fieldName(...)`
class _$UpdatePreferencesRequestCWProxyImpl
    implements _$UpdatePreferencesRequestCWProxy {
  const _$UpdatePreferencesRequestCWProxyImpl(this._value);

  final UpdatePreferencesRequest _value;

  @override
  UpdatePreferencesRequest locale(String? locale) => this(locale: locale);

  @override
  UpdatePreferencesRequest ritualMode(
    UpdatePreferencesRequestRitualModeEnum? ritualMode,
  ) => this(ritualMode: ritualMode);

  @override
  UpdatePreferencesRequest themeMode(
    UpdatePreferencesRequestThemeModeEnum? themeMode,
  ) => this(themeMode: themeMode);

  @override
  UpdatePreferencesRequest timezone(String? timezone) =>
      this(timezone: timezone);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `UpdatePreferencesRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// UpdatePreferencesRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  UpdatePreferencesRequest call({
    Object? locale = const $CopyWithPlaceholder(),
    Object? ritualMode = const $CopyWithPlaceholder(),
    Object? themeMode = const $CopyWithPlaceholder(),
    Object? timezone = const $CopyWithPlaceholder(),
  }) {
    return UpdatePreferencesRequest(
      locale: locale == const $CopyWithPlaceholder()
          ? _value.locale
          // ignore: cast_nullable_to_non_nullable
          : locale as String?,
      ritualMode: ritualMode == const $CopyWithPlaceholder()
          ? _value.ritualMode
          // ignore: cast_nullable_to_non_nullable
          : ritualMode as UpdatePreferencesRequestRitualModeEnum?,
      themeMode: themeMode == const $CopyWithPlaceholder()
          ? _value.themeMode
          // ignore: cast_nullable_to_non_nullable
          : themeMode as UpdatePreferencesRequestThemeModeEnum?,
      timezone: timezone == const $CopyWithPlaceholder()
          ? _value.timezone
          // ignore: cast_nullable_to_non_nullable
          : timezone as String?,
    );
  }
}

extension $UpdatePreferencesRequestCopyWith on UpdatePreferencesRequest {
  /// Returns a callable class that can be used as follows: `instanceOfUpdatePreferencesRequest.copyWith(...)` or like so:`instanceOfUpdatePreferencesRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$UpdatePreferencesRequestCWProxy get copyWith =>
      _$UpdatePreferencesRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdatePreferencesRequest _$UpdatePreferencesRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('UpdatePreferencesRequest', json, ($checkedConvert) {
  final val = UpdatePreferencesRequest(
    locale: $checkedConvert('locale', (v) => v as String?),
    ritualMode: $checkedConvert(
      'ritualMode',
      (v) => $enumDecodeNullable(
        _$UpdatePreferencesRequestRitualModeEnumEnumMap,
        v,
        unknownValue:
            UpdatePreferencesRequestRitualModeEnum.unknownDefaultOpenApi,
      ),
    ),
    themeMode: $checkedConvert(
      'themeMode',
      (v) => $enumDecodeNullable(
        _$UpdatePreferencesRequestThemeModeEnumEnumMap,
        v,
        unknownValue:
            UpdatePreferencesRequestThemeModeEnum.unknownDefaultOpenApi,
      ),
    ),
    timezone: $checkedConvert('timezone', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$UpdatePreferencesRequestToJson(
  UpdatePreferencesRequest instance,
) => <String, dynamic>{
  'locale': ?instance.locale,
  'ritualMode':
      ?_$UpdatePreferencesRequestRitualModeEnumEnumMap[instance.ritualMode],
  'themeMode':
      ?_$UpdatePreferencesRequestThemeModeEnumEnumMap[instance.themeMode],
  'timezone': ?instance.timezone,
};

const _$UpdatePreferencesRequestRitualModeEnumEnumMap = {
  UpdatePreferencesRequestRitualModeEnum.tarot: 'tarot',
  UpdatePreferencesRequestRitualModeEnum.astrology: 'astrology',
  UpdatePreferencesRequestRitualModeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$UpdatePreferencesRequestThemeModeEnumEnumMap = {
  UpdatePreferencesRequestThemeModeEnum.system: 'system',
  UpdatePreferencesRequestThemeModeEnum.light: 'light',
  UpdatePreferencesRequestThemeModeEnum.dark: 'dark',
  UpdatePreferencesRequestThemeModeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
