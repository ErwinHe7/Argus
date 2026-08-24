// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_asset_codex200_response_data_inner_revision_payload_any_of2.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2CWProxy {
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2 companyId(
    String companyId,
  );

  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2
  inclusionRationale(String inclusionRationale);

  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2 limitations(
    String limitations,
  );

  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2 summary(
    String summary,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2 call({
    String companyId,
    String inclusionRationale,
    String limitations,
    String summary,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2.copyWith.fieldName(...)`
class _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2CWProxyImpl
    implements
        _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2CWProxy {
  const _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2CWProxyImpl(
    this._value,
  );

  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2 _value;

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2 companyId(
    String companyId,
  ) => this(companyId: companyId);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2
  inclusionRationale(String inclusionRationale) =>
      this(inclusionRationale: inclusionRationale);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2 limitations(
    String limitations,
  ) => this(limitations: limitations);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2 summary(
    String summary,
  ) => this(summary: summary);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2 call({
    Object? companyId = const $CopyWithPlaceholder(),
    Object? inclusionRationale = const $CopyWithPlaceholder(),
    Object? limitations = const $CopyWithPlaceholder(),
    Object? summary = const $CopyWithPlaceholder(),
  }) {
    return ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2(
      companyId: companyId == const $CopyWithPlaceholder()
          ? _value.companyId
          // ignore: cast_nullable_to_non_nullable
          : companyId as String,
      inclusionRationale: inclusionRationale == const $CopyWithPlaceholder()
          ? _value.inclusionRationale
          // ignore: cast_nullable_to_non_nullable
          : inclusionRationale as String,
      limitations: limitations == const $CopyWithPlaceholder()
          ? _value.limitations
          // ignore: cast_nullable_to_non_nullable
          : limitations as String,
      summary: summary == const $CopyWithPlaceholder()
          ? _value.summary
          // ignore: cast_nullable_to_non_nullable
          : summary as String,
    );
  }
}

extension $ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2CopyWith
    on ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2 {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2.copyWith(...)` or like so:`instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2CWProxy
  get copyWith =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2CWProxyImpl(
        this,
      );
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2
_$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2FromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'company_id',
        'inclusion_rationale',
        'limitations',
        'summary',
      ],
    );
    final val = ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2(
      companyId: $checkedConvert('company_id', (v) => v as String),
      inclusionRationale: $checkedConvert(
        'inclusion_rationale',
        (v) => v as String,
      ),
      limitations: $checkedConvert('limitations', (v) => v as String),
      summary: $checkedConvert('summary', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'companyId': 'company_id',
    'inclusionRationale': 'inclusion_rationale',
  },
);

Map<String, dynamic>
_$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2ToJson(
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2 instance,
) => <String, dynamic>{
  'company_id': instance.companyId,
  'inclusion_rationale': instance.inclusionRationale,
  'limitations': instance.limitations,
  'summary': instance.summary,
};
