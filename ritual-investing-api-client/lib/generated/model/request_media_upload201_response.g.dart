// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_media_upload201_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RequestMediaUpload201ResponseCWProxy {
  RequestMediaUpload201Response data(RequestMediaUpload201ResponseData data);

  RequestMediaUpload201Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestMediaUpload201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestMediaUpload201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestMediaUpload201Response call({
    RequestMediaUpload201ResponseData data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRequestMediaUpload201Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRequestMediaUpload201Response.copyWith.fieldName(...)`
class _$RequestMediaUpload201ResponseCWProxyImpl
    implements _$RequestMediaUpload201ResponseCWProxy {
  const _$RequestMediaUpload201ResponseCWProxyImpl(this._value);

  final RequestMediaUpload201Response _value;

  @override
  RequestMediaUpload201Response data(RequestMediaUpload201ResponseData data) =>
      this(data: data);

  @override
  RequestMediaUpload201Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestMediaUpload201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestMediaUpload201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestMediaUpload201Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return RequestMediaUpload201Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as RequestMediaUpload201ResponseData,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $RequestMediaUpload201ResponseCopyWith
    on RequestMediaUpload201Response {
  /// Returns a callable class that can be used as follows: `instanceOfRequestMediaUpload201Response.copyWith(...)` or like so:`instanceOfRequestMediaUpload201Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RequestMediaUpload201ResponseCWProxy get copyWith =>
      _$RequestMediaUpload201ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestMediaUpload201Response _$RequestMediaUpload201ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('RequestMediaUpload201Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = RequestMediaUpload201Response(
    data: $checkedConvert(
      'data',
      (v) =>
          RequestMediaUpload201ResponseData.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$RequestMediaUpload201ResponseToJson(
  RequestMediaUpload201Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
