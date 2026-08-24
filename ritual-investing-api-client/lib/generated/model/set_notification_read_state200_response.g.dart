// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_notification_read_state200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SetNotificationReadState200ResponseCWProxy {
  SetNotificationReadState200Response data(
    ListNotifications200ResponseDataInner data,
  );

  SetNotificationReadState200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SetNotificationReadState200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SetNotificationReadState200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  SetNotificationReadState200Response call({
    ListNotifications200ResponseDataInner data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSetNotificationReadState200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSetNotificationReadState200Response.copyWith.fieldName(...)`
class _$SetNotificationReadState200ResponseCWProxyImpl
    implements _$SetNotificationReadState200ResponseCWProxy {
  const _$SetNotificationReadState200ResponseCWProxyImpl(this._value);

  final SetNotificationReadState200Response _value;

  @override
  SetNotificationReadState200Response data(
    ListNotifications200ResponseDataInner data,
  ) => this(data: data);

  @override
  SetNotificationReadState200Response meta(ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SetNotificationReadState200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SetNotificationReadState200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  SetNotificationReadState200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return SetNotificationReadState200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as ListNotifications200ResponseDataInner,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $SetNotificationReadState200ResponseCopyWith
    on SetNotificationReadState200Response {
  /// Returns a callable class that can be used as follows: `instanceOfSetNotificationReadState200Response.copyWith(...)` or like so:`instanceOfSetNotificationReadState200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SetNotificationReadState200ResponseCWProxy get copyWith =>
      _$SetNotificationReadState200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SetNotificationReadState200Response
_$SetNotificationReadState200ResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SetNotificationReadState200Response', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = SetNotificationReadState200Response(
        data: $checkedConvert(
          'data',
          (v) => ListNotifications200ResponseDataInner.fromJson(
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

Map<String, dynamic> _$SetNotificationReadState200ResponseToJson(
  SetNotificationReadState200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
