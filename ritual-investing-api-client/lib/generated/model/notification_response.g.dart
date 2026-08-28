// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$NotificationResponseCWProxy {
  NotificationResponse data(MemberNotification data);

  NotificationResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `NotificationResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// NotificationResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  NotificationResponse call({
    MemberNotification data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfNotificationResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfNotificationResponse.copyWith.fieldName(...)`
class _$NotificationResponseCWProxyImpl
    implements _$NotificationResponseCWProxy {
  const _$NotificationResponseCWProxyImpl(this._value);

  final NotificationResponse _value;

  @override
  NotificationResponse data(MemberNotification data) => this(data: data);

  @override
  NotificationResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `NotificationResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// NotificationResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  NotificationResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return NotificationResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as MemberNotification,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $NotificationResponseCopyWith on NotificationResponse {
  /// Returns a callable class that can be used as follows: `instanceOfNotificationResponse.copyWith(...)` or like so:`instanceOfNotificationResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$NotificationResponseCWProxy get copyWith =>
      _$NotificationResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationResponse _$NotificationResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('NotificationResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = NotificationResponse(
    data: $checkedConvert(
      'data',
      (v) => MemberNotification.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$NotificationResponseToJson(
  NotificationResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
