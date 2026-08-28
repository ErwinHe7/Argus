// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_evidence_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AssetEvidenceResponseCWProxy {
  AssetEvidenceResponse data(List<EvidenceDetail> data);

  AssetEvidenceResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AssetEvidenceResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AssetEvidenceResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  AssetEvidenceResponse call({
    List<EvidenceDetail> data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAssetEvidenceResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAssetEvidenceResponse.copyWith.fieldName(...)`
class _$AssetEvidenceResponseCWProxyImpl
    implements _$AssetEvidenceResponseCWProxy {
  const _$AssetEvidenceResponseCWProxyImpl(this._value);

  final AssetEvidenceResponse _value;

  @override
  AssetEvidenceResponse data(List<EvidenceDetail> data) => this(data: data);

  @override
  AssetEvidenceResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AssetEvidenceResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AssetEvidenceResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  AssetEvidenceResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return AssetEvidenceResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<EvidenceDetail>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $AssetEvidenceResponseCopyWith on AssetEvidenceResponse {
  /// Returns a callable class that can be used as follows: `instanceOfAssetEvidenceResponse.copyWith(...)` or like so:`instanceOfAssetEvidenceResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AssetEvidenceResponseCWProxy get copyWith =>
      _$AssetEvidenceResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AssetEvidenceResponse _$AssetEvidenceResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AssetEvidenceResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = AssetEvidenceResponse(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => EvidenceDetail.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$AssetEvidenceResponseToJson(
  AssetEvidenceResponse instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
