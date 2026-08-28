// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_metrics_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AssetMetricsResponseCWProxy {
  AssetMetricsResponse data(List<AssetMetric> data);

  AssetMetricsResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AssetMetricsResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AssetMetricsResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  AssetMetricsResponse call({
    List<AssetMetric> data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAssetMetricsResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAssetMetricsResponse.copyWith.fieldName(...)`
class _$AssetMetricsResponseCWProxyImpl
    implements _$AssetMetricsResponseCWProxy {
  const _$AssetMetricsResponseCWProxyImpl(this._value);

  final AssetMetricsResponse _value;

  @override
  AssetMetricsResponse data(List<AssetMetric> data) => this(data: data);

  @override
  AssetMetricsResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AssetMetricsResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AssetMetricsResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  AssetMetricsResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return AssetMetricsResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<AssetMetric>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $AssetMetricsResponseCopyWith on AssetMetricsResponse {
  /// Returns a callable class that can be used as follows: `instanceOfAssetMetricsResponse.copyWith(...)` or like so:`instanceOfAssetMetricsResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AssetMetricsResponseCWProxy get copyWith =>
      _$AssetMetricsResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AssetMetricsResponse _$AssetMetricsResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AssetMetricsResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = AssetMetricsResponse(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => AssetMetric.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$AssetMetricsResponseToJson(
  AssetMetricsResponse instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
