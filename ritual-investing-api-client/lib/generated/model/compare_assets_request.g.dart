// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'compare_assets_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CompareAssetsRequestCWProxy {
  CompareAssetsRequest assetIds(List<String> assetIds);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CompareAssetsRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CompareAssetsRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CompareAssetsRequest call({List<String> assetIds});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCompareAssetsRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCompareAssetsRequest.copyWith.fieldName(...)`
class _$CompareAssetsRequestCWProxyImpl
    implements _$CompareAssetsRequestCWProxy {
  const _$CompareAssetsRequestCWProxyImpl(this._value);

  final CompareAssetsRequest _value;

  @override
  CompareAssetsRequest assetIds(List<String> assetIds) =>
      this(assetIds: assetIds);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CompareAssetsRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CompareAssetsRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CompareAssetsRequest call({Object? assetIds = const $CopyWithPlaceholder()}) {
    return CompareAssetsRequest(
      assetIds: assetIds == const $CopyWithPlaceholder()
          ? _value.assetIds
          // ignore: cast_nullable_to_non_nullable
          : assetIds as List<String>,
    );
  }
}

extension $CompareAssetsRequestCopyWith on CompareAssetsRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCompareAssetsRequest.copyWith(...)` or like so:`instanceOfCompareAssetsRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CompareAssetsRequestCWProxy get copyWith =>
      _$CompareAssetsRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CompareAssetsRequest _$CompareAssetsRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CompareAssetsRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['assetIds']);
  final val = CompareAssetsRequest(
    assetIds: $checkedConvert(
      'assetIds',
      (v) => (v as List<dynamic>).map((e) => e as String).toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$CompareAssetsRequestToJson(
  CompareAssetsRequest instance,
) => <String, dynamic>{'assetIds': instance.assetIds};
