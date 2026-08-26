// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_asset_codex200_response_data_inner_revision_payload_any_of_ideas_inner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInnerCWProxy {
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner
  appearanceReason(String appearanceReason);

  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner assetId(
    String assetId,
  );

  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner
  riskSummary(String riskSummary);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner call({
    String appearanceReason,
    String assetId,
    String riskSummary,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner.copyWith.fieldName(...)`
class _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInnerCWProxyImpl
    implements
        _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInnerCWProxy {
  const _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInnerCWProxyImpl(
    this._value,
  );

  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner
  _value;

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner
  appearanceReason(String appearanceReason) =>
      this(appearanceReason: appearanceReason);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner assetId(
    String assetId,
  ) => this(assetId: assetId);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner
  riskSummary(String riskSummary) => this(riskSummary: riskSummary);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner call({
    Object? appearanceReason = const $CopyWithPlaceholder(),
    Object? assetId = const $CopyWithPlaceholder(),
    Object? riskSummary = const $CopyWithPlaceholder(),
  }) {
    return ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner(
      appearanceReason: appearanceReason == const $CopyWithPlaceholder()
          ? _value.appearanceReason
          // ignore: cast_nullable_to_non_nullable
          : appearanceReason as String,
      assetId: assetId == const $CopyWithPlaceholder()
          ? _value.assetId
          // ignore: cast_nullable_to_non_nullable
          : assetId as String,
      riskSummary: riskSummary == const $CopyWithPlaceholder()
          ? _value.riskSummary
          // ignore: cast_nullable_to_non_nullable
          : riskSummary as String,
    );
  }
}

extension $ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInnerCopyWith
    on ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner.copyWith(...)` or like so:`instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInnerCWProxy
  get copyWith =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInnerCWProxyImpl(
        this,
      );
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner
_$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInnerFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const ['appearance_reason', 'asset_id', 'risk_summary'],
    );
    final val =
        ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner(
          appearanceReason: $checkedConvert(
            'appearance_reason',
            (v) => v as String,
          ),
          assetId: $checkedConvert('asset_id', (v) => v as String),
          riskSummary: $checkedConvert('risk_summary', (v) => v as String),
        );
    return val;
  },
  fieldKeyMap: const {
    'appearanceReason': 'appearance_reason',
    'assetId': 'asset_id',
    'riskSummary': 'risk_summary',
  },
);

Map<String, dynamic>
_$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInnerToJson(
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner
  instance,
) => <String, dynamic>{
  'appearance_reason': instance.appearanceReason,
  'asset_id': instance.assetId,
  'risk_summary': instance.riskSummary,
};
