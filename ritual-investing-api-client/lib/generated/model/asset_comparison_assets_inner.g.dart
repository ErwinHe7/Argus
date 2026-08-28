// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_comparison_assets_inner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AssetComparisonAssetsInnerCWProxy {
  AssetComparisonAssetsInner asset(AssetSummary asset);

  AssetComparisonAssetsInner latestMetric(AssetMetric? latestMetric);

  AssetComparisonAssetsInner riskCount(int riskCount);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AssetComparisonAssetsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AssetComparisonAssetsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  AssetComparisonAssetsInner call({
    AssetSummary asset,
    AssetMetric? latestMetric,
    int riskCount,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAssetComparisonAssetsInner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAssetComparisonAssetsInner.copyWith.fieldName(...)`
class _$AssetComparisonAssetsInnerCWProxyImpl
    implements _$AssetComparisonAssetsInnerCWProxy {
  const _$AssetComparisonAssetsInnerCWProxyImpl(this._value);

  final AssetComparisonAssetsInner _value;

  @override
  AssetComparisonAssetsInner asset(AssetSummary asset) => this(asset: asset);

  @override
  AssetComparisonAssetsInner latestMetric(AssetMetric? latestMetric) =>
      this(latestMetric: latestMetric);

  @override
  AssetComparisonAssetsInner riskCount(int riskCount) =>
      this(riskCount: riskCount);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AssetComparisonAssetsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AssetComparisonAssetsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  AssetComparisonAssetsInner call({
    Object? asset = const $CopyWithPlaceholder(),
    Object? latestMetric = const $CopyWithPlaceholder(),
    Object? riskCount = const $CopyWithPlaceholder(),
  }) {
    return AssetComparisonAssetsInner(
      asset: asset == const $CopyWithPlaceholder()
          ? _value.asset
          // ignore: cast_nullable_to_non_nullable
          : asset as AssetSummary,
      latestMetric: latestMetric == const $CopyWithPlaceholder()
          ? _value.latestMetric
          // ignore: cast_nullable_to_non_nullable
          : latestMetric as AssetMetric?,
      riskCount: riskCount == const $CopyWithPlaceholder()
          ? _value.riskCount
          // ignore: cast_nullable_to_non_nullable
          : riskCount as int,
    );
  }
}

extension $AssetComparisonAssetsInnerCopyWith on AssetComparisonAssetsInner {
  /// Returns a callable class that can be used as follows: `instanceOfAssetComparisonAssetsInner.copyWith(...)` or like so:`instanceOfAssetComparisonAssetsInner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AssetComparisonAssetsInnerCWProxy get copyWith =>
      _$AssetComparisonAssetsInnerCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AssetComparisonAssetsInner _$AssetComparisonAssetsInnerFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'AssetComparisonAssetsInner',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const ['asset', 'latest_metric', 'risk_count'],
    );
    final val = AssetComparisonAssetsInner(
      asset: $checkedConvert(
        'asset',
        (v) => AssetSummary.fromJson(v as Map<String, dynamic>),
      ),
      latestMetric: $checkedConvert(
        'latest_metric',
        (v) =>
            v == null ? null : AssetMetric.fromJson(v as Map<String, dynamic>),
      ),
      riskCount: $checkedConvert('risk_count', (v) => (v as num).toInt()),
    );
    return val;
  },
  fieldKeyMap: const {
    'latestMetric': 'latest_metric',
    'riskCount': 'risk_count',
  },
);

Map<String, dynamic> _$AssetComparisonAssetsInnerToJson(
  AssetComparisonAssetsInner instance,
) => <String, dynamic>{
  'asset': instance.asset.toJson(),
  'latest_metric': instance.latestMetric?.toJson(),
  'risk_count': instance.riskCount,
};
