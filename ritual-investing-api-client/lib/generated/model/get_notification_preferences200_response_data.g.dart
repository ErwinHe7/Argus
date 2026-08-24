// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_notification_preferences200_response_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GetNotificationPreferences200ResponseDataCWProxy {
  GetNotificationPreferences200ResponseData dailyRitual(bool dailyRitual);

  GetNotificationPreferences200ResponseData moonCycle(bool moonCycle);

  GetNotificationPreferences200ResponseData quietHours(
    GetNotificationPreferences200ResponseDataQuietHours quietHours,
  );

  GetNotificationPreferences200ResponseData version(int version);

  GetNotificationPreferences200ResponseData weeklyRecap(bool weeklyRecap);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetNotificationPreferences200ResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetNotificationPreferences200ResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  GetNotificationPreferences200ResponseData call({
    bool dailyRitual,
    bool moonCycle,
    GetNotificationPreferences200ResponseDataQuietHours quietHours,
    int version,
    bool weeklyRecap,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGetNotificationPreferences200ResponseData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGetNotificationPreferences200ResponseData.copyWith.fieldName(...)`
class _$GetNotificationPreferences200ResponseDataCWProxyImpl
    implements _$GetNotificationPreferences200ResponseDataCWProxy {
  const _$GetNotificationPreferences200ResponseDataCWProxyImpl(this._value);

  final GetNotificationPreferences200ResponseData _value;

  @override
  GetNotificationPreferences200ResponseData dailyRitual(bool dailyRitual) =>
      this(dailyRitual: dailyRitual);

  @override
  GetNotificationPreferences200ResponseData moonCycle(bool moonCycle) =>
      this(moonCycle: moonCycle);

  @override
  GetNotificationPreferences200ResponseData quietHours(
    GetNotificationPreferences200ResponseDataQuietHours quietHours,
  ) => this(quietHours: quietHours);

  @override
  GetNotificationPreferences200ResponseData version(int version) =>
      this(version: version);

  @override
  GetNotificationPreferences200ResponseData weeklyRecap(bool weeklyRecap) =>
      this(weeklyRecap: weeklyRecap);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetNotificationPreferences200ResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetNotificationPreferences200ResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  GetNotificationPreferences200ResponseData call({
    Object? dailyRitual = const $CopyWithPlaceholder(),
    Object? moonCycle = const $CopyWithPlaceholder(),
    Object? quietHours = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
    Object? weeklyRecap = const $CopyWithPlaceholder(),
  }) {
    return GetNotificationPreferences200ResponseData(
      dailyRitual: dailyRitual == const $CopyWithPlaceholder()
          ? _value.dailyRitual
          // ignore: cast_nullable_to_non_nullable
          : dailyRitual as bool,
      moonCycle: moonCycle == const $CopyWithPlaceholder()
          ? _value.moonCycle
          // ignore: cast_nullable_to_non_nullable
          : moonCycle as bool,
      quietHours: quietHours == const $CopyWithPlaceholder()
          ? _value.quietHours
          // ignore: cast_nullable_to_non_nullable
          : quietHours as GetNotificationPreferences200ResponseDataQuietHours,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
      weeklyRecap: weeklyRecap == const $CopyWithPlaceholder()
          ? _value.weeklyRecap
          // ignore: cast_nullable_to_non_nullable
          : weeklyRecap as bool,
    );
  }
}

extension $GetNotificationPreferences200ResponseDataCopyWith
    on GetNotificationPreferences200ResponseData {
  /// Returns a callable class that can be used as follows: `instanceOfGetNotificationPreferences200ResponseData.copyWith(...)` or like so:`instanceOfGetNotificationPreferences200ResponseData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GetNotificationPreferences200ResponseDataCWProxy get copyWith =>
      _$GetNotificationPreferences200ResponseDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetNotificationPreferences200ResponseData
_$GetNotificationPreferences200ResponseDataFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'GetNotificationPreferences200ResponseData',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'daily_ritual',
        'moon_cycle',
        'quiet_hours',
        'version',
        'weekly_recap',
      ],
    );
    final val = GetNotificationPreferences200ResponseData(
      dailyRitual: $checkedConvert('daily_ritual', (v) => v as bool),
      moonCycle: $checkedConvert('moon_cycle', (v) => v as bool),
      quietHours: $checkedConvert(
        'quiet_hours',
        (v) => GetNotificationPreferences200ResponseDataQuietHours.fromJson(
          v as Map<String, dynamic>,
        ),
      ),
      version: $checkedConvert('version', (v) => (v as num).toInt()),
      weeklyRecap: $checkedConvert('weekly_recap', (v) => v as bool),
    );
    return val;
  },
  fieldKeyMap: const {
    'dailyRitual': 'daily_ritual',
    'moonCycle': 'moon_cycle',
    'quietHours': 'quiet_hours',
    'weeklyRecap': 'weekly_recap',
  },
);

Map<String, dynamic> _$GetNotificationPreferences200ResponseDataToJson(
  GetNotificationPreferences200ResponseData instance,
) => <String, dynamic>{
  'daily_ritual': instance.dailyRitual,
  'moon_cycle': instance.moonCycle,
  'quiet_hours': instance.quietHours.toJson(),
  'version': instance.version,
  'weekly_recap': instance.weeklyRecap,
};
