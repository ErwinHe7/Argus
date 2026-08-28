// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_detail_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AssetDetailResponseCWProxy {
  AssetDetailResponse data(AssetCodexDetail data);

  AssetDetailResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AssetDetailResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AssetDetailResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  AssetDetailResponse call({
    AssetCodexDetail data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAssetDetailResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAssetDetailResponse.copyWith.fieldName(...)`
class _$AssetDetailResponseCWProxyImpl implements _$AssetDetailResponseCWProxy {
  const _$AssetDetailResponseCWProxyImpl(this._value);

  final AssetDetailResponse _value;

  @override
  AssetDetailResponse data(AssetCodexDetail data) => this(data: data);

  @override
  AssetDetailResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AssetDetailResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AssetDetailResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  AssetDetailResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return AssetDetailResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as AssetCodexDetail,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $AssetDetailResponseCopyWith on AssetDetailResponse {
  /// Returns a callable class that can be used as follows: `instanceOfAssetDetailResponse.copyWith(...)` or like so:`instanceOfAssetDetailResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AssetDetailResponseCWProxy get copyWith =>
      _$AssetDetailResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AssetDetailResponse _$AssetDetailResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('AssetDetailResponse', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = AssetDetailResponse(
        data: $checkedConvert(
          'data',
          (v) => AssetCodexDetail.fromJson(v as Map<String, dynamic>),
        ),
        meta: $checkedConvert(
          'meta',
          (v) =>
              ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$AssetDetailResponseToJson(
  AssetDetailResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
