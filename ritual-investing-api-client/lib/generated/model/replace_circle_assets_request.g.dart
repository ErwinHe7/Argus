// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'replace_circle_assets_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ReplaceCircleAssetsRequestCWProxy {
  ReplaceCircleAssetsRequest assets(List<CircleAssetInput> assets);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReplaceCircleAssetsRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReplaceCircleAssetsRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  ReplaceCircleAssetsRequest call({List<CircleAssetInput> assets});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfReplaceCircleAssetsRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfReplaceCircleAssetsRequest.copyWith.fieldName(...)`
class _$ReplaceCircleAssetsRequestCWProxyImpl
    implements _$ReplaceCircleAssetsRequestCWProxy {
  const _$ReplaceCircleAssetsRequestCWProxyImpl(this._value);

  final ReplaceCircleAssetsRequest _value;

  @override
  ReplaceCircleAssetsRequest assets(List<CircleAssetInput> assets) =>
      this(assets: assets);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReplaceCircleAssetsRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReplaceCircleAssetsRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  ReplaceCircleAssetsRequest call({
    Object? assets = const $CopyWithPlaceholder(),
  }) {
    return ReplaceCircleAssetsRequest(
      assets: assets == const $CopyWithPlaceholder()
          ? _value.assets
          // ignore: cast_nullable_to_non_nullable
          : assets as List<CircleAssetInput>,
    );
  }
}

extension $ReplaceCircleAssetsRequestCopyWith on ReplaceCircleAssetsRequest {
  /// Returns a callable class that can be used as follows: `instanceOfReplaceCircleAssetsRequest.copyWith(...)` or like so:`instanceOfReplaceCircleAssetsRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ReplaceCircleAssetsRequestCWProxy get copyWith =>
      _$ReplaceCircleAssetsRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReplaceCircleAssetsRequest _$ReplaceCircleAssetsRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ReplaceCircleAssetsRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['assets']);
  final val = ReplaceCircleAssetsRequest(
    assets: $checkedConvert(
      'assets',
      (v) => (v as List<dynamic>)
          .map((e) => CircleAssetInput.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$ReplaceCircleAssetsRequestToJson(
  ReplaceCircleAssetsRequest instance,
) => <String, dynamic>{
  'assets': instance.assets.map((e) => e.toJson()).toList(),
};
