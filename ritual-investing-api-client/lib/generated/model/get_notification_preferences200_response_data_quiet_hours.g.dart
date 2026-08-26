// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_notification_preferences200_response_data_quiet_hours.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GetNotificationPreferences200ResponseDataQuietHoursCWProxy {
  GetNotificationPreferences200ResponseDataQuietHours enabled(bool enabled);

  GetNotificationPreferences200ResponseDataQuietHours end(String end);

  GetNotificationPreferences200ResponseDataQuietHours start(String start);

  GetNotificationPreferences200ResponseDataQuietHours timezone(String timezone);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetNotificationPreferences200ResponseDataQuietHours(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetNotificationPreferences200ResponseDataQuietHours(...).copyWith(id: 12, name: "My name")
  /// ````
  GetNotificationPreferences200ResponseDataQuietHours call({
    bool enabled,
    String end,
    String start,
    String timezone,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGetNotificationPreferences200ResponseDataQuietHours.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGetNotificationPreferences200ResponseDataQuietHours.copyWith.fieldName(...)`
class _$GetNotificationPreferences200ResponseDataQuietHoursCWProxyImpl
    implements _$GetNotificationPreferences200ResponseDataQuietHoursCWProxy {
  const _$GetNotificationPreferences200ResponseDataQuietHoursCWProxyImpl(
    this._value,
  );

  final GetNotificationPreferences200ResponseDataQuietHours _value;

  @override
  GetNotificationPreferences200ResponseDataQuietHours enabled(bool enabled) =>
      this(enabled: enabled);

  @override
  GetNotificationPreferences200ResponseDataQuietHours end(String end) =>
      this(end: end);

  @override
  GetNotificationPreferences200ResponseDataQuietHours start(String start) =>
      this(start: start);

  @override
  GetNotificationPreferences200ResponseDataQuietHours timezone(
    String timezone,
  ) => this(timezone: timezone);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetNotificationPreferences200ResponseDataQuietHours(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetNotificationPreferences200ResponseDataQuietHours(...).copyWith(id: 12, name: "My name")
  /// ````
  GetNotificationPreferences200ResponseDataQuietHours call({
    Object? enabled = const $CopyWithPlaceholder(),
    Object? end = const $CopyWithPlaceholder(),
    Object? start = const $CopyWithPlaceholder(),
    Object? timezone = const $CopyWithPlaceholder(),
  }) {
    return GetNotificationPreferences200ResponseDataQuietHours(
      enabled: enabled == const $CopyWithPlaceholder()
          ? _value.enabled
          // ignore: cast_nullable_to_non_nullable
          : enabled as bool,
      end: end == const $CopyWithPlaceholder()
          ? _value.end
          // ignore: cast_nullable_to_non_nullable
          : end as String,
      start: start == const $CopyWithPlaceholder()
          ? _value.start
          // ignore: cast_nullable_to_non_nullable
          : start as String,
      timezone: timezone == const $CopyWithPlaceholder()
          ? _value.timezone
          // ignore: cast_nullable_to_non_nullable
          : timezone as String,
    );
  }
}

extension $GetNotificationPreferences200ResponseDataQuietHoursCopyWith
    on GetNotificationPreferences200ResponseDataQuietHours {
  /// Returns a callable class that can be used as follows: `instanceOfGetNotificationPreferences200ResponseDataQuietHours.copyWith(...)` or like so:`instanceOfGetNotificationPreferences200ResponseDataQuietHours.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GetNotificationPreferences200ResponseDataQuietHoursCWProxy get copyWith =>
      _$GetNotificationPreferences200ResponseDataQuietHoursCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetNotificationPreferences200ResponseDataQuietHours
_$GetNotificationPreferences200ResponseDataQuietHoursFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'GetNotificationPreferences200ResponseDataQuietHours',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const ['enabled', 'end', 'start', 'timezone'],
    );
    final val = GetNotificationPreferences200ResponseDataQuietHours(
      enabled: $checkedConvert('enabled', (v) => v as bool),
      end: $checkedConvert('end', (v) => v as String),
      start: $checkedConvert('start', (v) => v as String),
      timezone: $checkedConvert('timezone', (v) => v as String),
    );
    return val;
  },
);

Map<String, dynamic>
_$GetNotificationPreferences200ResponseDataQuietHoursToJson(
  GetNotificationPreferences200ResponseDataQuietHours instance,
) => <String, dynamic>{
  'enabled': instance.enabled,
  'end': instance.end,
  'start': instance.start,
  'timezone': instance.timezone,
};
