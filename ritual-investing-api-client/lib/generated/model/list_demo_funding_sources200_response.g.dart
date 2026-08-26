// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_demo_funding_sources200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListDemoFundingSources200ResponseCWProxy {
  ListDemoFundingSources200Response data(List<DemoFundingSource> data);

  ListDemoFundingSources200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListDemoFundingSources200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListDemoFundingSources200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListDemoFundingSources200Response call({
    List<DemoFundingSource> data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListDemoFundingSources200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListDemoFundingSources200Response.copyWith.fieldName(...)`
class _$ListDemoFundingSources200ResponseCWProxyImpl
    implements _$ListDemoFundingSources200ResponseCWProxy {
  const _$ListDemoFundingSources200ResponseCWProxyImpl(this._value);

  final ListDemoFundingSources200Response _value;

  @override
  ListDemoFundingSources200Response data(List<DemoFundingSource> data) =>
      this(data: data);

  @override
  ListDemoFundingSources200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListDemoFundingSources200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListDemoFundingSources200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListDemoFundingSources200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ListDemoFundingSources200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<DemoFundingSource>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $ListDemoFundingSources200ResponseCopyWith
    on ListDemoFundingSources200Response {
  /// Returns a callable class that can be used as follows: `instanceOfListDemoFundingSources200Response.copyWith(...)` or like so:`instanceOfListDemoFundingSources200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListDemoFundingSources200ResponseCWProxy get copyWith =>
      _$ListDemoFundingSources200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListDemoFundingSources200Response _$ListDemoFundingSources200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ListDemoFundingSources200Response', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = ListDemoFundingSources200Response(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => DemoFundingSource.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$ListDemoFundingSources200ResponseToJson(
  ListDemoFundingSources200Response instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
