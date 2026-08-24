// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'confirm_demo_checkout200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ConfirmDemoCheckout200ResponseCWProxy {
  ConfirmDemoCheckout200Response data(DemoEntitlement data);

  ConfirmDemoCheckout200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ConfirmDemoCheckout200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ConfirmDemoCheckout200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ConfirmDemoCheckout200Response call({
    DemoEntitlement data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfConfirmDemoCheckout200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfConfirmDemoCheckout200Response.copyWith.fieldName(...)`
class _$ConfirmDemoCheckout200ResponseCWProxyImpl
    implements _$ConfirmDemoCheckout200ResponseCWProxy {
  const _$ConfirmDemoCheckout200ResponseCWProxyImpl(this._value);

  final ConfirmDemoCheckout200Response _value;

  @override
  ConfirmDemoCheckout200Response data(DemoEntitlement data) => this(data: data);

  @override
  ConfirmDemoCheckout200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ConfirmDemoCheckout200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ConfirmDemoCheckout200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ConfirmDemoCheckout200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ConfirmDemoCheckout200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as DemoEntitlement,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $ConfirmDemoCheckout200ResponseCopyWith
    on ConfirmDemoCheckout200Response {
  /// Returns a callable class that can be used as follows: `instanceOfConfirmDemoCheckout200Response.copyWith(...)` or like so:`instanceOfConfirmDemoCheckout200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ConfirmDemoCheckout200ResponseCWProxy get copyWith =>
      _$ConfirmDemoCheckout200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConfirmDemoCheckout200Response _$ConfirmDemoCheckout200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ConfirmDemoCheckout200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = ConfirmDemoCheckout200Response(
    data: $checkedConvert(
      'data',
      (v) => DemoEntitlement.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$ConfirmDemoCheckout200ResponseToJson(
  ConfirmDemoCheckout200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
