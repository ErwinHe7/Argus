// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_notification_preferences200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GetNotificationPreferences200ResponseCWProxy {
  GetNotificationPreferences200Response data(
    GetNotificationPreferences200ResponseData data,
  );

  GetNotificationPreferences200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetNotificationPreferences200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetNotificationPreferences200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetNotificationPreferences200Response call({
    GetNotificationPreferences200ResponseData data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGetNotificationPreferences200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGetNotificationPreferences200Response.copyWith.fieldName(...)`
class _$GetNotificationPreferences200ResponseCWProxyImpl
    implements _$GetNotificationPreferences200ResponseCWProxy {
  const _$GetNotificationPreferences200ResponseCWProxyImpl(this._value);

  final GetNotificationPreferences200Response _value;

  @override
  GetNotificationPreferences200Response data(
    GetNotificationPreferences200ResponseData data,
  ) => this(data: data);

  @override
  GetNotificationPreferences200Response meta(ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetNotificationPreferences200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetNotificationPreferences200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetNotificationPreferences200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return GetNotificationPreferences200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as GetNotificationPreferences200ResponseData,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $GetNotificationPreferences200ResponseCopyWith
    on GetNotificationPreferences200Response {
  /// Returns a callable class that can be used as follows: `instanceOfGetNotificationPreferences200Response.copyWith(...)` or like so:`instanceOfGetNotificationPreferences200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GetNotificationPreferences200ResponseCWProxy get copyWith =>
      _$GetNotificationPreferences200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetNotificationPreferences200Response
_$GetNotificationPreferences200ResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GetNotificationPreferences200Response', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = GetNotificationPreferences200Response(
        data: $checkedConvert(
          'data',
          (v) => GetNotificationPreferences200ResponseData.fromJson(
            v as Map<String, dynamic>,
          ),
        ),
        meta: $checkedConvert(
          'meta',
          (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$GetNotificationPreferences200ResponseToJson(
  GetNotificationPreferences200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
