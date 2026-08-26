// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_admin_asset_metric_snapshot201_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateAdminAssetMetricSnapshot201ResponseCWProxy {
  CreateAdminAssetMetricSnapshot201Response data(AdminAssetMetricSnapshot data);

  CreateAdminAssetMetricSnapshot201Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminAssetMetricSnapshot201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminAssetMetricSnapshot201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminAssetMetricSnapshot201Response call({
    AdminAssetMetricSnapshot data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateAdminAssetMetricSnapshot201Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateAdminAssetMetricSnapshot201Response.copyWith.fieldName(...)`
class _$CreateAdminAssetMetricSnapshot201ResponseCWProxyImpl
    implements _$CreateAdminAssetMetricSnapshot201ResponseCWProxy {
  const _$CreateAdminAssetMetricSnapshot201ResponseCWProxyImpl(this._value);

  final CreateAdminAssetMetricSnapshot201Response _value;

  @override
  CreateAdminAssetMetricSnapshot201Response data(
    AdminAssetMetricSnapshot data,
  ) => this(data: data);

  @override
  CreateAdminAssetMetricSnapshot201Response meta(ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminAssetMetricSnapshot201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminAssetMetricSnapshot201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminAssetMetricSnapshot201Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CreateAdminAssetMetricSnapshot201Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as AdminAssetMetricSnapshot,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $CreateAdminAssetMetricSnapshot201ResponseCopyWith
    on CreateAdminAssetMetricSnapshot201Response {
  /// Returns a callable class that can be used as follows: `instanceOfCreateAdminAssetMetricSnapshot201Response.copyWith(...)` or like so:`instanceOfCreateAdminAssetMetricSnapshot201Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateAdminAssetMetricSnapshot201ResponseCWProxy get copyWith =>
      _$CreateAdminAssetMetricSnapshot201ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAdminAssetMetricSnapshot201Response
_$CreateAdminAssetMetricSnapshot201ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateAdminAssetMetricSnapshot201Response', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = CreateAdminAssetMetricSnapshot201Response(
    data: $checkedConvert(
      'data',
      (v) => AdminAssetMetricSnapshot.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$CreateAdminAssetMetricSnapshot201ResponseToJson(
  CreateAdminAssetMetricSnapshot201Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
