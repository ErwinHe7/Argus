// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_future_mirror200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateFutureMirror200ResponseCWProxy {
  CreateFutureMirror200Response data(FutureMirrorView data);

  CreateFutureMirror200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateFutureMirror200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateFutureMirror200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateFutureMirror200Response call({
    FutureMirrorView data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateFutureMirror200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateFutureMirror200Response.copyWith.fieldName(...)`
class _$CreateFutureMirror200ResponseCWProxyImpl
    implements _$CreateFutureMirror200ResponseCWProxy {
  const _$CreateFutureMirror200ResponseCWProxyImpl(this._value);

  final CreateFutureMirror200Response _value;

  @override
  CreateFutureMirror200Response data(FutureMirrorView data) => this(data: data);

  @override
  CreateFutureMirror200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateFutureMirror200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateFutureMirror200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateFutureMirror200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CreateFutureMirror200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as FutureMirrorView,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $CreateFutureMirror200ResponseCopyWith
    on CreateFutureMirror200Response {
  /// Returns a callable class that can be used as follows: `instanceOfCreateFutureMirror200Response.copyWith(...)` or like so:`instanceOfCreateFutureMirror200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateFutureMirror200ResponseCWProxy get copyWith =>
      _$CreateFutureMirror200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateFutureMirror200Response _$CreateFutureMirror200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateFutureMirror200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = CreateFutureMirror200Response(
    data: $checkedConvert(
      'data',
      (v) => FutureMirrorView.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$CreateFutureMirror200ResponseToJson(
  CreateFutureMirror200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
