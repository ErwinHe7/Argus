// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_demo_checkout201_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateDemoCheckout201ResponseCWProxy {
  CreateDemoCheckout201Response data(DemoCheckoutSession data);

  CreateDemoCheckout201Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateDemoCheckout201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateDemoCheckout201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateDemoCheckout201Response call({
    DemoCheckoutSession data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateDemoCheckout201Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateDemoCheckout201Response.copyWith.fieldName(...)`
class _$CreateDemoCheckout201ResponseCWProxyImpl
    implements _$CreateDemoCheckout201ResponseCWProxy {
  const _$CreateDemoCheckout201ResponseCWProxyImpl(this._value);

  final CreateDemoCheckout201Response _value;

  @override
  CreateDemoCheckout201Response data(DemoCheckoutSession data) =>
      this(data: data);

  @override
  CreateDemoCheckout201Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateDemoCheckout201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateDemoCheckout201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateDemoCheckout201Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CreateDemoCheckout201Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as DemoCheckoutSession,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $CreateDemoCheckout201ResponseCopyWith
    on CreateDemoCheckout201Response {
  /// Returns a callable class that can be used as follows: `instanceOfCreateDemoCheckout201Response.copyWith(...)` or like so:`instanceOfCreateDemoCheckout201Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateDemoCheckout201ResponseCWProxy get copyWith =>
      _$CreateDemoCheckout201ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateDemoCheckout201Response _$CreateDemoCheckout201ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateDemoCheckout201Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = CreateDemoCheckout201Response(
    data: $checkedConvert(
      'data',
      (v) => DemoCheckoutSession.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$CreateDemoCheckout201ResponseToJson(
  CreateDemoCheckout201Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
