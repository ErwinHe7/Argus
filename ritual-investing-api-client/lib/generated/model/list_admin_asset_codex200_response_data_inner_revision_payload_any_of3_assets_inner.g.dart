// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_asset_codex200_response_data_inner_revision_payload_any_of3_assets_inner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInnerCWProxy {
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner
  assetId(String assetId);

  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner note(
    String note,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner call({
    String assetId,
    String note,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner.copyWith.fieldName(...)`
class _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInnerCWProxyImpl
    implements
        _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInnerCWProxy {
  const _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInnerCWProxyImpl(
    this._value,
  );

  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner
  _value;

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner
  assetId(String assetId) => this(assetId: assetId);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner note(
    String note,
  ) => this(note: note);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner call({
    Object? assetId = const $CopyWithPlaceholder(),
    Object? note = const $CopyWithPlaceholder(),
  }) {
    return ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner(
      assetId: assetId == const $CopyWithPlaceholder()
          ? _value.assetId
          // ignore: cast_nullable_to_non_nullable
          : assetId as String,
      note: note == const $CopyWithPlaceholder()
          ? _value.note
          // ignore: cast_nullable_to_non_nullable
          : note as String,
    );
  }
}

extension $ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInnerCopyWith
    on ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner.copyWith(...)` or like so:`instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInnerCWProxy
  get copyWith =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInnerCWProxyImpl(
        this,
      );
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner
_$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInnerFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['asset_id', 'note']);
    final val =
        ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner(
          assetId: $checkedConvert('asset_id', (v) => v as String),
          note: $checkedConvert('note', (v) => v as String),
        );
    return val;
  },
  fieldKeyMap: const {'assetId': 'asset_id'},
);

Map<String, dynamic>
_$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInnerToJson(
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner
  instance,
) => <String, dynamic>{'asset_id': instance.assetId, 'note': instance.note};
