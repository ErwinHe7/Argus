// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_collection_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$NotificationCollectionResponseCWProxy {
  NotificationCollectionResponse data(List<MemberNotification> data);

  NotificationCollectionResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `NotificationCollectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// NotificationCollectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  NotificationCollectionResponse call({
    List<MemberNotification> data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfNotificationCollectionResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfNotificationCollectionResponse.copyWith.fieldName(...)`
class _$NotificationCollectionResponseCWProxyImpl
    implements _$NotificationCollectionResponseCWProxy {
  const _$NotificationCollectionResponseCWProxyImpl(this._value);

  final NotificationCollectionResponse _value;

  @override
  NotificationCollectionResponse data(List<MemberNotification> data) =>
      this(data: data);

  @override
  NotificationCollectionResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `NotificationCollectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// NotificationCollectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  NotificationCollectionResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return NotificationCollectionResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<MemberNotification>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $NotificationCollectionResponseCopyWith
    on NotificationCollectionResponse {
  /// Returns a callable class that can be used as follows: `instanceOfNotificationCollectionResponse.copyWith(...)` or like so:`instanceOfNotificationCollectionResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$NotificationCollectionResponseCWProxy get copyWith =>
      _$NotificationCollectionResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationCollectionResponse _$NotificationCollectionResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('NotificationCollectionResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = NotificationCollectionResponse(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => MemberNotification.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$NotificationCollectionResponseToJson(
  NotificationCollectionResponse instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
