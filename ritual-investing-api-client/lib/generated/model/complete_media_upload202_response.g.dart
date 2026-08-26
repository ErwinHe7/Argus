// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'complete_media_upload202_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CompleteMediaUpload202ResponseCWProxy {
  CompleteMediaUpload202Response data(CompleteMediaUpload202ResponseData data);

  CompleteMediaUpload202Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CompleteMediaUpload202Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CompleteMediaUpload202Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CompleteMediaUpload202Response call({
    CompleteMediaUpload202ResponseData data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCompleteMediaUpload202Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCompleteMediaUpload202Response.copyWith.fieldName(...)`
class _$CompleteMediaUpload202ResponseCWProxyImpl
    implements _$CompleteMediaUpload202ResponseCWProxy {
  const _$CompleteMediaUpload202ResponseCWProxyImpl(this._value);

  final CompleteMediaUpload202Response _value;

  @override
  CompleteMediaUpload202Response data(
    CompleteMediaUpload202ResponseData data,
  ) => this(data: data);

  @override
  CompleteMediaUpload202Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CompleteMediaUpload202Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CompleteMediaUpload202Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CompleteMediaUpload202Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CompleteMediaUpload202Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as CompleteMediaUpload202ResponseData,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $CompleteMediaUpload202ResponseCopyWith
    on CompleteMediaUpload202Response {
  /// Returns a callable class that can be used as follows: `instanceOfCompleteMediaUpload202Response.copyWith(...)` or like so:`instanceOfCompleteMediaUpload202Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CompleteMediaUpload202ResponseCWProxy get copyWith =>
      _$CompleteMediaUpload202ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CompleteMediaUpload202Response _$CompleteMediaUpload202ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CompleteMediaUpload202Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = CompleteMediaUpload202Response(
    data: $checkedConvert(
      'data',
      (v) => CompleteMediaUpload202ResponseData.fromJson(
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

Map<String, dynamic> _$CompleteMediaUpload202ResponseToJson(
  CompleteMediaUpload202Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
