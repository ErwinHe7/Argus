// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discover_asset_collection_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DiscoverAssetCollectionResponseCWProxy {
  DiscoverAssetCollectionResponse data(List<AssetSummary> data);

  DiscoverAssetCollectionResponse meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DiscoverAssetCollectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DiscoverAssetCollectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  DiscoverAssetCollectionResponse call({
    List<AssetSummary> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDiscoverAssetCollectionResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDiscoverAssetCollectionResponse.copyWith.fieldName(...)`
class _$DiscoverAssetCollectionResponseCWProxyImpl
    implements _$DiscoverAssetCollectionResponseCWProxy {
  const _$DiscoverAssetCollectionResponseCWProxyImpl(this._value);

  final DiscoverAssetCollectionResponse _value;

  @override
  DiscoverAssetCollectionResponse data(List<AssetSummary> data) =>
      this(data: data);

  @override
  DiscoverAssetCollectionResponse meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DiscoverAssetCollectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DiscoverAssetCollectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  DiscoverAssetCollectionResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return DiscoverAssetCollectionResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<AssetSummary>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $DiscoverAssetCollectionResponseCopyWith
    on DiscoverAssetCollectionResponse {
  /// Returns a callable class that can be used as follows: `instanceOfDiscoverAssetCollectionResponse.copyWith(...)` or like so:`instanceOfDiscoverAssetCollectionResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DiscoverAssetCollectionResponseCWProxy get copyWith =>
      _$DiscoverAssetCollectionResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DiscoverAssetCollectionResponse _$DiscoverAssetCollectionResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('DiscoverAssetCollectionResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = DiscoverAssetCollectionResponse(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => AssetSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$DiscoverAssetCollectionResponseToJson(
  DiscoverAssetCollectionResponse instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
