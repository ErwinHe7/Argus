// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_preferences.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$NotificationPreferencesCWProxy {
  NotificationPreferences dailyRitual(bool dailyRitual);

  NotificationPreferences deletionEpoch(int? deletionEpoch);

  NotificationPreferences moonCycle(bool moonCycle);

  NotificationPreferences quietHours(Map<String, Object?> quietHours);

  NotificationPreferences userId(String userId);

  NotificationPreferences version(int version);

  NotificationPreferences weeklyRecap(bool weeklyRecap);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `NotificationPreferences(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// NotificationPreferences(...).copyWith(id: 12, name: "My name")
  /// ````
  NotificationPreferences call({
    bool dailyRitual,
    int? deletionEpoch,
    bool moonCycle,
    Map<String, Object?> quietHours,
    String userId,
    int version,
    bool weeklyRecap,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfNotificationPreferences.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfNotificationPreferences.copyWith.fieldName(...)`
class _$NotificationPreferencesCWProxyImpl
    implements _$NotificationPreferencesCWProxy {
  const _$NotificationPreferencesCWProxyImpl(this._value);

  final NotificationPreferences _value;

  @override
  NotificationPreferences dailyRitual(bool dailyRitual) =>
      this(dailyRitual: dailyRitual);

  @override
  NotificationPreferences deletionEpoch(int? deletionEpoch) =>
      this(deletionEpoch: deletionEpoch);

  @override
  NotificationPreferences moonCycle(bool moonCycle) =>
      this(moonCycle: moonCycle);

  @override
  NotificationPreferences quietHours(Map<String, Object?> quietHours) =>
      this(quietHours: quietHours);

  @override
  NotificationPreferences userId(String userId) => this(userId: userId);

  @override
  NotificationPreferences version(int version) => this(version: version);

  @override
  NotificationPreferences weeklyRecap(bool weeklyRecap) =>
      this(weeklyRecap: weeklyRecap);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `NotificationPreferences(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// NotificationPreferences(...).copyWith(id: 12, name: "My name")
  /// ````
  NotificationPreferences call({
    Object? dailyRitual = const $CopyWithPlaceholder(),
    Object? deletionEpoch = const $CopyWithPlaceholder(),
    Object? moonCycle = const $CopyWithPlaceholder(),
    Object? quietHours = const $CopyWithPlaceholder(),
    Object? userId = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
    Object? weeklyRecap = const $CopyWithPlaceholder(),
  }) {
    return NotificationPreferences(
      dailyRitual: dailyRitual == const $CopyWithPlaceholder()
          ? _value.dailyRitual
          // ignore: cast_nullable_to_non_nullable
          : dailyRitual as bool,
      deletionEpoch: deletionEpoch == const $CopyWithPlaceholder()
          ? _value.deletionEpoch
          // ignore: cast_nullable_to_non_nullable
          : deletionEpoch as int?,
      moonCycle: moonCycle == const $CopyWithPlaceholder()
          ? _value.moonCycle
          // ignore: cast_nullable_to_non_nullable
          : moonCycle as bool,
      quietHours: quietHours == const $CopyWithPlaceholder()
          ? _value.quietHours
          // ignore: cast_nullable_to_non_nullable
          : quietHours as Map<String, Object?>,
      userId: userId == const $CopyWithPlaceholder()
          ? _value.userId
          // ignore: cast_nullable_to_non_nullable
          : userId as String,
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

extension $NotificationPreferencesCopyWith on NotificationPreferences {
  /// Returns a callable class that can be used as follows: `instanceOfNotificationPreferences.copyWith(...)` or like so:`instanceOfNotificationPreferences.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$NotificationPreferencesCWProxy get copyWith =>
      _$NotificationPreferencesCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationPreferences _$NotificationPreferencesFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'NotificationPreferences',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'daily_ritual',
        'deletion_epoch',
        'moon_cycle',
        'quiet_hours',
        'user_id',
        'version',
        'weekly_recap',
      ],
    );
    final val = NotificationPreferences(
      dailyRitual: $checkedConvert('daily_ritual', (v) => v as bool),
      deletionEpoch: $checkedConvert(
        'deletion_epoch',
        (v) => (v as num?)?.toInt(),
      ),
      moonCycle: $checkedConvert('moon_cycle', (v) => v as bool),
      quietHours: $checkedConvert(
        'quiet_hours',
        (v) => v as Map<String, dynamic>,
      ),
      userId: $checkedConvert('user_id', (v) => v as String),
      version: $checkedConvert('version', (v) => (v as num).toInt()),
      weeklyRecap: $checkedConvert('weekly_recap', (v) => v as bool),
    );
    return val;
  },
  fieldKeyMap: const {
    'dailyRitual': 'daily_ritual',
    'deletionEpoch': 'deletion_epoch',
    'moonCycle': 'moon_cycle',
    'quietHours': 'quiet_hours',
    'userId': 'user_id',
    'weeklyRecap': 'weekly_recap',
  },
);

Map<String, dynamic> _$NotificationPreferencesToJson(
  NotificationPreferences instance,
) => <String, dynamic>{
  'daily_ritual': instance.dailyRitual,
  'deletion_epoch': instance.deletionEpoch,
  'moon_cycle': instance.moonCycle,
  'quiet_hours': instance.quietHours,
  'user_id': instance.userId,
  'version': instance.version,
  'weekly_recap': instance.weeklyRecap,
};
