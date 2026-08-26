// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'copy_circle_template201_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CopyCircleTemplate201ResponseCWProxy {
  CopyCircleTemplate201Response data(CircleView data);

  CopyCircleTemplate201Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CopyCircleTemplate201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CopyCircleTemplate201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CopyCircleTemplate201Response call({CircleView data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCopyCircleTemplate201Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCopyCircleTemplate201Response.copyWith.fieldName(...)`
class _$CopyCircleTemplate201ResponseCWProxyImpl
    implements _$CopyCircleTemplate201ResponseCWProxy {
  const _$CopyCircleTemplate201ResponseCWProxyImpl(this._value);

  final CopyCircleTemplate201Response _value;

  @override
  CopyCircleTemplate201Response data(CircleView data) => this(data: data);

  @override
  CopyCircleTemplate201Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CopyCircleTemplate201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CopyCircleTemplate201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CopyCircleTemplate201Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CopyCircleTemplate201Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as CircleView,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $CopyCircleTemplate201ResponseCopyWith
    on CopyCircleTemplate201Response {
  /// Returns a callable class that can be used as follows: `instanceOfCopyCircleTemplate201Response.copyWith(...)` or like so:`instanceOfCopyCircleTemplate201Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CopyCircleTemplate201ResponseCWProxy get copyWith =>
      _$CopyCircleTemplate201ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CopyCircleTemplate201Response _$CopyCircleTemplate201ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CopyCircleTemplate201Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = CopyCircleTemplate201Response(
    data: $checkedConvert(
      'data',
      (v) => CircleView.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$CopyCircleTemplate201ResponseToJson(
  CopyCircleTemplate201Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
