// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_preferences_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$NotificationPreferencesResponseCWProxy {
  NotificationPreferencesResponse data(NotificationPreferences data);

  NotificationPreferencesResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `NotificationPreferencesResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// NotificationPreferencesResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  NotificationPreferencesResponse call({
    NotificationPreferences data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfNotificationPreferencesResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfNotificationPreferencesResponse.copyWith.fieldName(...)`
class _$NotificationPreferencesResponseCWProxyImpl
    implements _$NotificationPreferencesResponseCWProxy {
  const _$NotificationPreferencesResponseCWProxyImpl(this._value);

  final NotificationPreferencesResponse _value;

  @override
  NotificationPreferencesResponse data(NotificationPreferences data) =>
      this(data: data);

  @override
  NotificationPreferencesResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `NotificationPreferencesResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// NotificationPreferencesResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  NotificationPreferencesResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return NotificationPreferencesResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as NotificationPreferences,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $NotificationPreferencesResponseCopyWith
    on NotificationPreferencesResponse {
  /// Returns a callable class that can be used as follows: `instanceOfNotificationPreferencesResponse.copyWith(...)` or like so:`instanceOfNotificationPreferencesResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$NotificationPreferencesResponseCWProxy get copyWith =>
      _$NotificationPreferencesResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationPreferencesResponse _$NotificationPreferencesResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('NotificationPreferencesResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = NotificationPreferencesResponse(
    data: $checkedConvert(
      'data',
      (v) => NotificationPreferences.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$NotificationPreferencesResponseToJson(
  NotificationPreferencesResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
