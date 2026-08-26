// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_notification_preferences_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchNotificationPreferencesRequestCWProxy {
  PatchNotificationPreferencesRequest dailyRitual(bool? dailyRitual);

  PatchNotificationPreferencesRequest moonCycle(bool? moonCycle);

  PatchNotificationPreferencesRequest quietHours(
    GetNotificationPreferences200ResponseDataQuietHours? quietHours,
  );

  PatchNotificationPreferencesRequest weeklyRecap(bool? weeklyRecap);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchNotificationPreferencesRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchNotificationPreferencesRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchNotificationPreferencesRequest call({
    bool? dailyRitual,
    bool? moonCycle,
    GetNotificationPreferences200ResponseDataQuietHours? quietHours,
    bool? weeklyRecap,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchNotificationPreferencesRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchNotificationPreferencesRequest.copyWith.fieldName(...)`
class _$PatchNotificationPreferencesRequestCWProxyImpl
    implements _$PatchNotificationPreferencesRequestCWProxy {
  const _$PatchNotificationPreferencesRequestCWProxyImpl(this._value);

  final PatchNotificationPreferencesRequest _value;

  @override
  PatchNotificationPreferencesRequest dailyRitual(bool? dailyRitual) =>
      this(dailyRitual: dailyRitual);

  @override
  PatchNotificationPreferencesRequest moonCycle(bool? moonCycle) =>
      this(moonCycle: moonCycle);

  @override
  PatchNotificationPreferencesRequest quietHours(
    GetNotificationPreferences200ResponseDataQuietHours? quietHours,
  ) => this(quietHours: quietHours);

  @override
  PatchNotificationPreferencesRequest weeklyRecap(bool? weeklyRecap) =>
      this(weeklyRecap: weeklyRecap);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchNotificationPreferencesRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchNotificationPreferencesRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchNotificationPreferencesRequest call({
    Object? dailyRitual = const $CopyWithPlaceholder(),
    Object? moonCycle = const $CopyWithPlaceholder(),
    Object? quietHours = const $CopyWithPlaceholder(),
    Object? weeklyRecap = const $CopyWithPlaceholder(),
  }) {
    return PatchNotificationPreferencesRequest(
      dailyRitual: dailyRitual == const $CopyWithPlaceholder()
          ? _value.dailyRitual
          // ignore: cast_nullable_to_non_nullable
          : dailyRitual as bool?,
      moonCycle: moonCycle == const $CopyWithPlaceholder()
          ? _value.moonCycle
          // ignore: cast_nullable_to_non_nullable
          : moonCycle as bool?,
      quietHours: quietHours == const $CopyWithPlaceholder()
          ? _value.quietHours
          // ignore: cast_nullable_to_non_nullable
          : quietHours as GetNotificationPreferences200ResponseDataQuietHours?,
      weeklyRecap: weeklyRecap == const $CopyWithPlaceholder()
          ? _value.weeklyRecap
          // ignore: cast_nullable_to_non_nullable
          : weeklyRecap as bool?,
    );
  }
}

extension $PatchNotificationPreferencesRequestCopyWith
    on PatchNotificationPreferencesRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPatchNotificationPreferencesRequest.copyWith(...)` or like so:`instanceOfPatchNotificationPreferencesRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchNotificationPreferencesRequestCWProxy get copyWith =>
      _$PatchNotificationPreferencesRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchNotificationPreferencesRequest
_$PatchNotificationPreferencesRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'PatchNotificationPreferencesRequest',
      json,
      ($checkedConvert) {
        final val = PatchNotificationPreferencesRequest(
          dailyRitual: $checkedConvert('daily_ritual', (v) => v as bool?),
          moonCycle: $checkedConvert('moon_cycle', (v) => v as bool?),
          quietHours: $checkedConvert(
            'quiet_hours',
            (v) => v == null
                ? null
                : GetNotificationPreferences200ResponseDataQuietHours.fromJson(
                    v as Map<String, dynamic>,
                  ),
          ),
          weeklyRecap: $checkedConvert('weekly_recap', (v) => v as bool?),
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

Map<String, dynamic> _$PatchNotificationPreferencesRequestToJson(
  PatchNotificationPreferencesRequest instance,
) => <String, dynamic>{
  'daily_ritual': ?instance.dailyRitual,
  'moon_cycle': ?instance.moonCycle,
  'quiet_hours': ?instance.quietHours?.toJson(),
  'weekly_recap': ?instance.weeklyRecap,
};
