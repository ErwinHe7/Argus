// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_demo_funding_source201_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateDemoFundingSource201ResponseCWProxy {
  CreateDemoFundingSource201Response data(DemoFundingSource data);

  CreateDemoFundingSource201Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateDemoFundingSource201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateDemoFundingSource201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateDemoFundingSource201Response call({
    DemoFundingSource data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateDemoFundingSource201Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateDemoFundingSource201Response.copyWith.fieldName(...)`
class _$CreateDemoFundingSource201ResponseCWProxyImpl
    implements _$CreateDemoFundingSource201ResponseCWProxy {
  const _$CreateDemoFundingSource201ResponseCWProxyImpl(this._value);

  final CreateDemoFundingSource201Response _value;

  @override
  CreateDemoFundingSource201Response data(DemoFundingSource data) =>
      this(data: data);

  @override
  CreateDemoFundingSource201Response meta(ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateDemoFundingSource201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateDemoFundingSource201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateDemoFundingSource201Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CreateDemoFundingSource201Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as DemoFundingSource,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $CreateDemoFundingSource201ResponseCopyWith
    on CreateDemoFundingSource201Response {
  /// Returns a callable class that can be used as follows: `instanceOfCreateDemoFundingSource201Response.copyWith(...)` or like so:`instanceOfCreateDemoFundingSource201Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateDemoFundingSource201ResponseCWProxy get copyWith =>
      _$CreateDemoFundingSource201ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateDemoFundingSource201Response _$CreateDemoFundingSource201ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateDemoFundingSource201Response', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = CreateDemoFundingSource201Response(
    data: $checkedConvert(
      'data',
      (v) => DemoFundingSource.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$CreateDemoFundingSource201ResponseToJson(
  CreateDemoFundingSource201Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
