// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'read_all_notifications_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ReadAllNotificationsResponseCWProxy {
  ReadAllNotificationsResponse data(ReadAllNotificationsResponseData data);

  ReadAllNotificationsResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReadAllNotificationsResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReadAllNotificationsResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  ReadAllNotificationsResponse call({
    ReadAllNotificationsResponseData data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfReadAllNotificationsResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfReadAllNotificationsResponse.copyWith.fieldName(...)`
class _$ReadAllNotificationsResponseCWProxyImpl
    implements _$ReadAllNotificationsResponseCWProxy {
  const _$ReadAllNotificationsResponseCWProxyImpl(this._value);

  final ReadAllNotificationsResponse _value;

  @override
  ReadAllNotificationsResponse data(ReadAllNotificationsResponseData data) =>
      this(data: data);

  @override
  ReadAllNotificationsResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReadAllNotificationsResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReadAllNotificationsResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  ReadAllNotificationsResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ReadAllNotificationsResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as ReadAllNotificationsResponseData,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $ReadAllNotificationsResponseCopyWith
    on ReadAllNotificationsResponse {
  /// Returns a callable class that can be used as follows: `instanceOfReadAllNotificationsResponse.copyWith(...)` or like so:`instanceOfReadAllNotificationsResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ReadAllNotificationsResponseCWProxy get copyWith =>
      _$ReadAllNotificationsResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReadAllNotificationsResponse _$ReadAllNotificationsResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ReadAllNotificationsResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = ReadAllNotificationsResponse(
    data: $checkedConvert(
      'data',
      (v) =>
          ReadAllNotificationsResponseData.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$ReadAllNotificationsResponseToJson(
  ReadAllNotificationsResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
