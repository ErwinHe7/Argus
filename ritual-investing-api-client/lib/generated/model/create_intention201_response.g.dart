// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_intention201_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateIntention201ResponseCWProxy {
  CreateIntention201Response data(Intention data);

  CreateIntention201Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateIntention201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateIntention201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateIntention201Response call({Intention data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateIntention201Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateIntention201Response.copyWith.fieldName(...)`
class _$CreateIntention201ResponseCWProxyImpl
    implements _$CreateIntention201ResponseCWProxy {
  const _$CreateIntention201ResponseCWProxyImpl(this._value);

  final CreateIntention201Response _value;

  @override
  CreateIntention201Response data(Intention data) => this(data: data);

  @override
  CreateIntention201Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateIntention201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateIntention201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateIntention201Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CreateIntention201Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as Intention,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $CreateIntention201ResponseCopyWith on CreateIntention201Response {
  /// Returns a callable class that can be used as follows: `instanceOfCreateIntention201Response.copyWith(...)` or like so:`instanceOfCreateIntention201Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateIntention201ResponseCWProxy get copyWith =>
      _$CreateIntention201ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateIntention201Response _$CreateIntention201ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateIntention201Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = CreateIntention201Response(
    data: $checkedConvert(
      'data',
      (v) => Intention.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$CreateIntention201ResponseToJson(
  CreateIntention201Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
