// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_collection_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AssetCollectionResponseCWProxy {
  AssetCollectionResponse data(List<AssetSummary> data);

  AssetCollectionResponse meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AssetCollectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AssetCollectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  AssetCollectionResponse call({List<AssetSummary> data, CollectionMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAssetCollectionResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAssetCollectionResponse.copyWith.fieldName(...)`
class _$AssetCollectionResponseCWProxyImpl
    implements _$AssetCollectionResponseCWProxy {
  const _$AssetCollectionResponseCWProxyImpl(this._value);

  final AssetCollectionResponse _value;

  @override
  AssetCollectionResponse data(List<AssetSummary> data) => this(data: data);

  @override
  AssetCollectionResponse meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AssetCollectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AssetCollectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  AssetCollectionResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return AssetCollectionResponse(
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

extension $AssetCollectionResponseCopyWith on AssetCollectionResponse {
  /// Returns a callable class that can be used as follows: `instanceOfAssetCollectionResponse.copyWith(...)` or like so:`instanceOfAssetCollectionResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AssetCollectionResponseCWProxy get copyWith =>
      _$AssetCollectionResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AssetCollectionResponse _$AssetCollectionResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AssetCollectionResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = AssetCollectionResponse(
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

Map<String, dynamic> _$AssetCollectionResponseToJson(
  AssetCollectionResponse instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
