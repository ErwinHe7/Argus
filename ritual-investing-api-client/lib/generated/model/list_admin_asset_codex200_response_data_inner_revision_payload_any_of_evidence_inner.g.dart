// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_asset_codex200_response_data_inner_revision_payload_any_of_evidence_inner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInnerCWProxy {
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner
  claimId(String claimId);

  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner
  factorLabel(String factorLabel);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner
  call({String claimId, String factorLabel});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner.copyWith.fieldName(...)`
class _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInnerCWProxyImpl
    implements
        _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInnerCWProxy {
  const _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInnerCWProxyImpl(
    this._value,
  );

  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner
  _value;

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner
  claimId(String claimId) => this(claimId: claimId);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner
  factorLabel(String factorLabel) => this(factorLabel: factorLabel);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner
  call({
    Object? claimId = const $CopyWithPlaceholder(),
    Object? factorLabel = const $CopyWithPlaceholder(),
  }) {
    return ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner(
      claimId: claimId == const $CopyWithPlaceholder()
          ? _value.claimId
          // ignore: cast_nullable_to_non_nullable
          : claimId as String,
      factorLabel: factorLabel == const $CopyWithPlaceholder()
          ? _value.factorLabel
          // ignore: cast_nullable_to_non_nullable
          : factorLabel as String,
    );
  }
}

extension $ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInnerCopyWith
    on ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner.copyWith(...)` or like so:`instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInnerCWProxy
  get copyWith =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInnerCWProxyImpl(
        this,
      );
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner
_$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInnerFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['claim_id', 'factor_label']);
    final val =
        ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner(
          claimId: $checkedConvert('claim_id', (v) => v as String),
          factorLabel: $checkedConvert('factor_label', (v) => v as String),
        );
    return val;
  },
  fieldKeyMap: const {'claimId': 'claim_id', 'factorLabel': 'factor_label'},
);

Map<String, dynamic>
_$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInnerToJson(
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner
  instance,
) => <String, dynamic>{
  'claim_id': instance.claimId,
  'factor_label': instance.factorLabel,
};
