// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_content_report201_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateContentReport201ResponseCWProxy {
  CreateContentReport201Response data(CreateContentReport201ResponseData data);

  CreateContentReport201Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateContentReport201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateContentReport201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateContentReport201Response call({
    CreateContentReport201ResponseData data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateContentReport201Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateContentReport201Response.copyWith.fieldName(...)`
class _$CreateContentReport201ResponseCWProxyImpl
    implements _$CreateContentReport201ResponseCWProxy {
  const _$CreateContentReport201ResponseCWProxyImpl(this._value);

  final CreateContentReport201Response _value;

  @override
  CreateContentReport201Response data(
    CreateContentReport201ResponseData data,
  ) => this(data: data);

  @override
  CreateContentReport201Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateContentReport201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateContentReport201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateContentReport201Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CreateContentReport201Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as CreateContentReport201ResponseData,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $CreateContentReport201ResponseCopyWith
    on CreateContentReport201Response {
  /// Returns a callable class that can be used as follows: `instanceOfCreateContentReport201Response.copyWith(...)` or like so:`instanceOfCreateContentReport201Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateContentReport201ResponseCWProxy get copyWith =>
      _$CreateContentReport201ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateContentReport201Response _$CreateContentReport201ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateContentReport201Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = CreateContentReport201Response(
    data: $checkedConvert(
      'data',
      (v) => CreateContentReport201ResponseData.fromJson(
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

Map<String, dynamic> _$CreateContentReport201ResponseToJson(
  CreateContentReport201Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
