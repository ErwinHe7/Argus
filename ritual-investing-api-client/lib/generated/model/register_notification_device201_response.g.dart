// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'register_notification_device201_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RegisterNotificationDevice201ResponseCWProxy {
  RegisterNotificationDevice201Response data(
    RegisterNotificationDevice201ResponseData data,
  );

  RegisterNotificationDevice201Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RegisterNotificationDevice201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RegisterNotificationDevice201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  RegisterNotificationDevice201Response call({
    RegisterNotificationDevice201ResponseData data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRegisterNotificationDevice201Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRegisterNotificationDevice201Response.copyWith.fieldName(...)`
class _$RegisterNotificationDevice201ResponseCWProxyImpl
    implements _$RegisterNotificationDevice201ResponseCWProxy {
  const _$RegisterNotificationDevice201ResponseCWProxyImpl(this._value);

  final RegisterNotificationDevice201Response _value;

  @override
  RegisterNotificationDevice201Response data(
    RegisterNotificationDevice201ResponseData data,
  ) => this(data: data);

  @override
  RegisterNotificationDevice201Response meta(ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RegisterNotificationDevice201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RegisterNotificationDevice201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  RegisterNotificationDevice201Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return RegisterNotificationDevice201Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as RegisterNotificationDevice201ResponseData,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $RegisterNotificationDevice201ResponseCopyWith
    on RegisterNotificationDevice201Response {
  /// Returns a callable class that can be used as follows: `instanceOfRegisterNotificationDevice201Response.copyWith(...)` or like so:`instanceOfRegisterNotificationDevice201Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RegisterNotificationDevice201ResponseCWProxy get copyWith =>
      _$RegisterNotificationDevice201ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RegisterNotificationDevice201Response
_$RegisterNotificationDevice201ResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RegisterNotificationDevice201Response', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = RegisterNotificationDevice201Response(
        data: $checkedConvert(
          'data',
          (v) => RegisterNotificationDevice201ResponseData.fromJson(
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

Map<String, dynamic> _$RegisterNotificationDevice201ResponseToJson(
  RegisterNotificationDevice201Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
