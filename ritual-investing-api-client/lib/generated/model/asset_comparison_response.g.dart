// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_comparison_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AssetComparisonResponseCWProxy {
  AssetComparisonResponse data(AssetComparison data);

  AssetComparisonResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AssetComparisonResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AssetComparisonResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  AssetComparisonResponse call({
    AssetComparison data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAssetComparisonResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAssetComparisonResponse.copyWith.fieldName(...)`
class _$AssetComparisonResponseCWProxyImpl
    implements _$AssetComparisonResponseCWProxy {
  const _$AssetComparisonResponseCWProxyImpl(this._value);

  final AssetComparisonResponse _value;

  @override
  AssetComparisonResponse data(AssetComparison data) => this(data: data);

  @override
  AssetComparisonResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AssetComparisonResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AssetComparisonResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  AssetComparisonResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return AssetComparisonResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as AssetComparison,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $AssetComparisonResponseCopyWith on AssetComparisonResponse {
  /// Returns a callable class that can be used as follows: `instanceOfAssetComparisonResponse.copyWith(...)` or like so:`instanceOfAssetComparisonResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AssetComparisonResponseCWProxy get copyWith =>
      _$AssetComparisonResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AssetComparisonResponse _$AssetComparisonResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AssetComparisonResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = AssetComparisonResponse(
    data: $checkedConvert(
      'data',
      (v) => AssetComparison.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$AssetComparisonResponseToJson(
  AssetComparisonResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
