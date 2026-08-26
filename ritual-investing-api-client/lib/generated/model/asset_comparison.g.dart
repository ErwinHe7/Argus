// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_comparison.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AssetComparisonCWProxy {
  AssetComparison assets(List<AssetComparisonAssetsInner> assets);

  AssetComparison comparedAt(DateTime comparedAt);

  AssetComparison demo(DemoDisclosure demo);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AssetComparison(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AssetComparison(...).copyWith(id: 12, name: "My name")
  /// ````
  AssetComparison call({
    List<AssetComparisonAssetsInner> assets,
    DateTime comparedAt,
    DemoDisclosure demo,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAssetComparison.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAssetComparison.copyWith.fieldName(...)`
class _$AssetComparisonCWProxyImpl implements _$AssetComparisonCWProxy {
  const _$AssetComparisonCWProxyImpl(this._value);

  final AssetComparison _value;

  @override
  AssetComparison assets(List<AssetComparisonAssetsInner> assets) =>
      this(assets: assets);

  @override
  AssetComparison comparedAt(DateTime comparedAt) =>
      this(comparedAt: comparedAt);

  @override
  AssetComparison demo(DemoDisclosure demo) => this(demo: demo);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AssetComparison(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AssetComparison(...).copyWith(id: 12, name: "My name")
  /// ````
  AssetComparison call({
    Object? assets = const $CopyWithPlaceholder(),
    Object? comparedAt = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
  }) {
    return AssetComparison(
      assets: assets == const $CopyWithPlaceholder()
          ? _value.assets
          // ignore: cast_nullable_to_non_nullable
          : assets as List<AssetComparisonAssetsInner>,
      comparedAt: comparedAt == const $CopyWithPlaceholder()
          ? _value.comparedAt
          // ignore: cast_nullable_to_non_nullable
          : comparedAt as DateTime,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as DemoDisclosure,
    );
  }
}

extension $AssetComparisonCopyWith on AssetComparison {
  /// Returns a callable class that can be used as follows: `instanceOfAssetComparison.copyWith(...)` or like so:`instanceOfAssetComparison.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AssetComparisonCWProxy get copyWith => _$AssetComparisonCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AssetComparison _$AssetComparisonFromJson(Map<String, dynamic> json) =>
    $checkedCreate('AssetComparison', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['assets', 'compared_at', 'demo']);
      final val = AssetComparison(
        assets: $checkedConvert(
          'assets',
          (v) => (v as List<dynamic>)
              .map(
                (e) => AssetComparisonAssetsInner.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList(),
        ),
        comparedAt: $checkedConvert(
          'compared_at',
          (v) => DateTime.parse(v as String),
        ),
        demo: $checkedConvert(
          'demo',
          (v) => DemoDisclosure.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    }, fieldKeyMap: const {'comparedAt': 'compared_at'});

Map<String, dynamic> _$AssetComparisonToJson(AssetComparison instance) =>
    <String, dynamic>{
      'assets': instance.assets.map((e) => e.toJson()).toList(),
      'compared_at': instance.comparedAt.toIso8601String(),
      'demo': instance.demo.toJson(),
    };
