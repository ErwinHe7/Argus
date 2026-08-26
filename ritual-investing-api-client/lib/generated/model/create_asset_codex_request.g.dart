// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_asset_codex_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateAssetCodexRequestCWProxy {
  CreateAssetCodexRequest appearanceReason(String appearanceReason);

  CreateAssetCodexRequest assetId(String assetId);

  CreateAssetCodexRequest evidenceClaimIds(List<String> evidenceClaimIds);

  CreateAssetCodexRequest limitations(String limitations);

  CreateAssetCodexRequest metricsAsOf(DateTime metricsAsOf);

  CreateAssetCodexRequest risks(
    List<ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner>
    risks,
  );

  CreateAssetCodexRequest slug(String slug);

  CreateAssetCodexRequest thesis(String thesis);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAssetCodexRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAssetCodexRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAssetCodexRequest call({
    String appearanceReason,
    String assetId,
    List<String> evidenceClaimIds,
    String limitations,
    DateTime metricsAsOf,
    List<ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner>
    risks,
    String slug,
    String thesis,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateAssetCodexRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateAssetCodexRequest.copyWith.fieldName(...)`
class _$CreateAssetCodexRequestCWProxyImpl
    implements _$CreateAssetCodexRequestCWProxy {
  const _$CreateAssetCodexRequestCWProxyImpl(this._value);

  final CreateAssetCodexRequest _value;

  @override
  CreateAssetCodexRequest appearanceReason(String appearanceReason) =>
      this(appearanceReason: appearanceReason);

  @override
  CreateAssetCodexRequest assetId(String assetId) => this(assetId: assetId);

  @override
  CreateAssetCodexRequest evidenceClaimIds(List<String> evidenceClaimIds) =>
      this(evidenceClaimIds: evidenceClaimIds);

  @override
  CreateAssetCodexRequest limitations(String limitations) =>
      this(limitations: limitations);

  @override
  CreateAssetCodexRequest metricsAsOf(DateTime metricsAsOf) =>
      this(metricsAsOf: metricsAsOf);

  @override
  CreateAssetCodexRequest risks(
    List<ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner>
    risks,
  ) => this(risks: risks);

  @override
  CreateAssetCodexRequest slug(String slug) => this(slug: slug);

  @override
  CreateAssetCodexRequest thesis(String thesis) => this(thesis: thesis);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAssetCodexRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAssetCodexRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAssetCodexRequest call({
    Object? appearanceReason = const $CopyWithPlaceholder(),
    Object? assetId = const $CopyWithPlaceholder(),
    Object? evidenceClaimIds = const $CopyWithPlaceholder(),
    Object? limitations = const $CopyWithPlaceholder(),
    Object? metricsAsOf = const $CopyWithPlaceholder(),
    Object? risks = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? thesis = const $CopyWithPlaceholder(),
  }) {
    return CreateAssetCodexRequest(
      appearanceReason: appearanceReason == const $CopyWithPlaceholder()
          ? _value.appearanceReason
          // ignore: cast_nullable_to_non_nullable
          : appearanceReason as String,
      assetId: assetId == const $CopyWithPlaceholder()
          ? _value.assetId
          // ignore: cast_nullable_to_non_nullable
          : assetId as String,
      evidenceClaimIds: evidenceClaimIds == const $CopyWithPlaceholder()
          ? _value.evidenceClaimIds
          // ignore: cast_nullable_to_non_nullable
          : evidenceClaimIds as List<String>,
      limitations: limitations == const $CopyWithPlaceholder()
          ? _value.limitations
          // ignore: cast_nullable_to_non_nullable
          : limitations as String,
      metricsAsOf: metricsAsOf == const $CopyWithPlaceholder()
          ? _value.metricsAsOf
          // ignore: cast_nullable_to_non_nullable
          : metricsAsOf as DateTime,
      risks: risks == const $CopyWithPlaceholder()
          ? _value.risks
          // ignore: cast_nullable_to_non_nullable
          : risks
                as List<
                  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner
                >,
      slug: slug == const $CopyWithPlaceholder()
          ? _value.slug
          // ignore: cast_nullable_to_non_nullable
          : slug as String,
      thesis: thesis == const $CopyWithPlaceholder()
          ? _value.thesis
          // ignore: cast_nullable_to_non_nullable
          : thesis as String,
    );
  }
}

extension $CreateAssetCodexRequestCopyWith on CreateAssetCodexRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateAssetCodexRequest.copyWith(...)` or like so:`instanceOfCreateAssetCodexRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateAssetCodexRequestCWProxy get copyWith =>
      _$CreateAssetCodexRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAssetCodexRequest _$CreateAssetCodexRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'CreateAssetCodexRequest',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'appearance_reason',
        'asset_id',
        'evidence_claim_ids',
        'limitations',
        'metrics_as_of',
        'risks',
        'slug',
        'thesis',
      ],
    );
    final val = CreateAssetCodexRequest(
      appearanceReason: $checkedConvert(
        'appearance_reason',
        (v) => v as String,
      ),
      assetId: $checkedConvert('asset_id', (v) => v as String),
      evidenceClaimIds: $checkedConvert(
        'evidence_claim_ids',
        (v) => (v as List<dynamic>).map((e) => e as String).toList(),
      ),
      limitations: $checkedConvert('limitations', (v) => v as String),
      metricsAsOf: $checkedConvert(
        'metrics_as_of',
        (v) => DateTime.parse(v as String),
      ),
      risks: $checkedConvert(
        'risks',
        (v) => (v as List<dynamic>)
            .map(
              (e) =>
                  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner.fromJson(
                    e as Map<String, dynamic>,
                  ),
            )
            .toList(),
      ),
      slug: $checkedConvert('slug', (v) => v as String),
      thesis: $checkedConvert('thesis', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'appearanceReason': 'appearance_reason',
    'assetId': 'asset_id',
    'evidenceClaimIds': 'evidence_claim_ids',
    'metricsAsOf': 'metrics_as_of',
  },
);

Map<String, dynamic> _$CreateAssetCodexRequestToJson(
  CreateAssetCodexRequest instance,
) => <String, dynamic>{
  'appearance_reason': instance.appearanceReason,
  'asset_id': instance.assetId,
  'evidence_claim_ids': instance.evidenceClaimIds,
  'limitations': instance.limitations,
  'metrics_as_of': instance.metricsAsOf.toIso8601String(),
  'risks': instance.risks.map((e) => e.toJson()).toList(),
  'slug': instance.slug,
  'thesis': instance.thesis,
};
