// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_evidence_claim.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AdminEvidenceClaimCWProxy {
  AdminEvidenceClaim claimType(String claimType);

  AdminEvidenceClaim id(String id);

  AdminEvidenceClaim observedAt(DateTime? observedAt);

  AdminEvidenceClaim sourceId(String sourceId);

  AdminEvidenceClaim status(AdminEvidenceClaimStatusEnum status);

  AdminEvidenceClaim summary(String summary);

  AdminEvidenceClaim uncertainty(String uncertainty);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminEvidenceClaim(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminEvidenceClaim(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminEvidenceClaim call({
    String claimType,
    String id,
    DateTime? observedAt,
    String sourceId,
    AdminEvidenceClaimStatusEnum status,
    String summary,
    String uncertainty,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAdminEvidenceClaim.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAdminEvidenceClaim.copyWith.fieldName(...)`
class _$AdminEvidenceClaimCWProxyImpl implements _$AdminEvidenceClaimCWProxy {
  const _$AdminEvidenceClaimCWProxyImpl(this._value);

  final AdminEvidenceClaim _value;

  @override
  AdminEvidenceClaim claimType(String claimType) => this(claimType: claimType);

  @override
  AdminEvidenceClaim id(String id) => this(id: id);

  @override
  AdminEvidenceClaim observedAt(DateTime? observedAt) =>
      this(observedAt: observedAt);

  @override
  AdminEvidenceClaim sourceId(String sourceId) => this(sourceId: sourceId);

  @override
  AdminEvidenceClaim status(AdminEvidenceClaimStatusEnum status) =>
      this(status: status);

  @override
  AdminEvidenceClaim summary(String summary) => this(summary: summary);

  @override
  AdminEvidenceClaim uncertainty(String uncertainty) =>
      this(uncertainty: uncertainty);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminEvidenceClaim(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminEvidenceClaim(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminEvidenceClaim call({
    Object? claimType = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? observedAt = const $CopyWithPlaceholder(),
    Object? sourceId = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? summary = const $CopyWithPlaceholder(),
    Object? uncertainty = const $CopyWithPlaceholder(),
  }) {
    return AdminEvidenceClaim(
      claimType: claimType == const $CopyWithPlaceholder()
          ? _value.claimType
          // ignore: cast_nullable_to_non_nullable
          : claimType as String,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      observedAt: observedAt == const $CopyWithPlaceholder()
          ? _value.observedAt
          // ignore: cast_nullable_to_non_nullable
          : observedAt as DateTime?,
      sourceId: sourceId == const $CopyWithPlaceholder()
          ? _value.sourceId
          // ignore: cast_nullable_to_non_nullable
          : sourceId as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as AdminEvidenceClaimStatusEnum,
      summary: summary == const $CopyWithPlaceholder()
          ? _value.summary
          // ignore: cast_nullable_to_non_nullable
          : summary as String,
      uncertainty: uncertainty == const $CopyWithPlaceholder()
          ? _value.uncertainty
          // ignore: cast_nullable_to_non_nullable
          : uncertainty as String,
    );
  }
}

extension $AdminEvidenceClaimCopyWith on AdminEvidenceClaim {
  /// Returns a callable class that can be used as follows: `instanceOfAdminEvidenceClaim.copyWith(...)` or like so:`instanceOfAdminEvidenceClaim.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AdminEvidenceClaimCWProxy get copyWith =>
      _$AdminEvidenceClaimCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminEvidenceClaim _$AdminEvidenceClaimFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'AdminEvidenceClaim',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'claim_type',
            'id',
            'observed_at',
            'source_id',
            'status',
            'summary',
            'uncertainty',
          ],
        );
        final val = AdminEvidenceClaim(
          claimType: $checkedConvert('claim_type', (v) => v as String),
          id: $checkedConvert('id', (v) => v as String),
          observedAt: $checkedConvert(
            'observed_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          sourceId: $checkedConvert('source_id', (v) => v as String),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$AdminEvidenceClaimStatusEnumEnumMap,
              v,
              unknownValue: AdminEvidenceClaimStatusEnum.unknownDefaultOpenApi,
            ),
          ),
          summary: $checkedConvert('summary', (v) => v as String),
          uncertainty: $checkedConvert('uncertainty', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'claimType': 'claim_type',
        'observedAt': 'observed_at',
        'sourceId': 'source_id',
      },
    );

Map<String, dynamic> _$AdminEvidenceClaimToJson(AdminEvidenceClaim instance) =>
    <String, dynamic>{
      'claim_type': instance.claimType,
      'id': instance.id,
      'observed_at': instance.observedAt?.toIso8601String(),
      'source_id': instance.sourceId,
      'status': _$AdminEvidenceClaimStatusEnumEnumMap[instance.status]!,
      'summary': instance.summary,
      'uncertainty': instance.uncertainty,
    };

const _$AdminEvidenceClaimStatusEnumEnumMap = {
  AdminEvidenceClaimStatusEnum.active: 'active',
  AdminEvidenceClaimStatusEnum.superseded: 'superseded',
  AdminEvidenceClaimStatusEnum.withdrawn: 'withdrawn',
  AdminEvidenceClaimStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
