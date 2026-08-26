// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'read_all_notifications200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ReadAllNotifications200ResponseCWProxy {
  ReadAllNotifications200Response data(
    ReadAllNotifications200ResponseData data,
  );

  ReadAllNotifications200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReadAllNotifications200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReadAllNotifications200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ReadAllNotifications200Response call({
    ReadAllNotifications200ResponseData data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfReadAllNotifications200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfReadAllNotifications200Response.copyWith.fieldName(...)`
class _$ReadAllNotifications200ResponseCWProxyImpl
    implements _$ReadAllNotifications200ResponseCWProxy {
  const _$ReadAllNotifications200ResponseCWProxyImpl(this._value);

  final ReadAllNotifications200Response _value;

  @override
  ReadAllNotifications200Response data(
    ReadAllNotifications200ResponseData data,
  ) => this(data: data);

  @override
  ReadAllNotifications200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReadAllNotifications200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReadAllNotifications200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ReadAllNotifications200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ReadAllNotifications200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as ReadAllNotifications200ResponseData,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $ReadAllNotifications200ResponseCopyWith
    on ReadAllNotifications200Response {
  /// Returns a callable class that can be used as follows: `instanceOfReadAllNotifications200Response.copyWith(...)` or like so:`instanceOfReadAllNotifications200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ReadAllNotifications200ResponseCWProxy get copyWith =>
      _$ReadAllNotifications200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReadAllNotifications200Response _$ReadAllNotifications200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ReadAllNotifications200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = ReadAllNotifications200Response(
    data: $checkedConvert(
      'data',
      (v) => ReadAllNotifications200ResponseData.fromJson(
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

Map<String, dynamic> _$ReadAllNotifications200ResponseToJson(
  ReadAllNotifications200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
