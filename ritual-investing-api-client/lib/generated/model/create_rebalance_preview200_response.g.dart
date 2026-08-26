// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_rebalance_preview200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateRebalancePreview200ResponseCWProxy {
  CreateRebalancePreview200Response data(RebalancePreview data);

  CreateRebalancePreview200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateRebalancePreview200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateRebalancePreview200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateRebalancePreview200Response call({
    RebalancePreview data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateRebalancePreview200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateRebalancePreview200Response.copyWith.fieldName(...)`
class _$CreateRebalancePreview200ResponseCWProxyImpl
    implements _$CreateRebalancePreview200ResponseCWProxy {
  const _$CreateRebalancePreview200ResponseCWProxyImpl(this._value);

  final CreateRebalancePreview200Response _value;

  @override
  CreateRebalancePreview200Response data(RebalancePreview data) =>
      this(data: data);

  @override
  CreateRebalancePreview200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateRebalancePreview200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateRebalancePreview200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateRebalancePreview200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CreateRebalancePreview200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as RebalancePreview,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $CreateRebalancePreview200ResponseCopyWith
    on CreateRebalancePreview200Response {
  /// Returns a callable class that can be used as follows: `instanceOfCreateRebalancePreview200Response.copyWith(...)` or like so:`instanceOfCreateRebalancePreview200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateRebalancePreview200ResponseCWProxy get copyWith =>
      _$CreateRebalancePreview200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateRebalancePreview200Response _$CreateRebalancePreview200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateRebalancePreview200Response', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = CreateRebalancePreview200Response(
    data: $checkedConvert(
      'data',
      (v) => RebalancePreview.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$CreateRebalancePreview200ResponseToJson(
  CreateRebalancePreview200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
