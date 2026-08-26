// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_asset_codex200_response_data_inner_revision_payload_any_of4_assets_inner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInnerCWProxy {
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner
  assetId(String assetId);

  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner note(
    String note,
  );

  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner
  weightBps(int weightBps);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner call({
    String assetId,
    String note,
    int weightBps,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner.copyWith.fieldName(...)`
class _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInnerCWProxyImpl
    implements
        _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInnerCWProxy {
  const _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInnerCWProxyImpl(
    this._value,
  );

  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner
  _value;

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner
  assetId(String assetId) => this(assetId: assetId);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner note(
    String note,
  ) => this(note: note);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner
  weightBps(int weightBps) => this(weightBps: weightBps);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner call({
    Object? assetId = const $CopyWithPlaceholder(),
    Object? note = const $CopyWithPlaceholder(),
    Object? weightBps = const $CopyWithPlaceholder(),
  }) {
    return ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner(
      assetId: assetId == const $CopyWithPlaceholder()
          ? _value.assetId
          // ignore: cast_nullable_to_non_nullable
          : assetId as String,
      note: note == const $CopyWithPlaceholder()
          ? _value.note
          // ignore: cast_nullable_to_non_nullable
          : note as String,
      weightBps: weightBps == const $CopyWithPlaceholder()
          ? _value.weightBps
          // ignore: cast_nullable_to_non_nullable
          : weightBps as int,
    );
  }
}

extension $ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInnerCopyWith
    on ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner.copyWith(...)` or like so:`instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInnerCWProxy
  get copyWith =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInnerCWProxyImpl(
        this,
      );
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner
_$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInnerFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['asset_id', 'note', 'weight_bps']);
    final val =
        ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner(
          assetId: $checkedConvert('asset_id', (v) => v as String),
          note: $checkedConvert('note', (v) => v as String),
          weightBps: $checkedConvert('weight_bps', (v) => (v as num).toInt()),
        );
    return val;
  },
  fieldKeyMap: const {'assetId': 'asset_id', 'weightBps': 'weight_bps'},
);

Map<String, dynamic>
_$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInnerToJson(
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner
  instance,
) => <String, dynamic>{
  'asset_id': instance.assetId,
  'note': instance.note,
  'weight_bps': instance.weightBps,
};
