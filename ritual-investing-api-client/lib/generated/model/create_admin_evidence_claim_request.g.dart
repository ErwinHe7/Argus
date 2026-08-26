// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_admin_evidence_claim_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateAdminEvidenceClaimRequestCWProxy {
  CreateAdminEvidenceClaimRequest claimType(String claimType);

  CreateAdminEvidenceClaimRequest observedAt(DateTime? observedAt);

  CreateAdminEvidenceClaimRequest sourceId(String sourceId);

  CreateAdminEvidenceClaimRequest status(
    CreateAdminEvidenceClaimRequestStatusEnum status,
  );

  CreateAdminEvidenceClaimRequest summary(String summary);

  CreateAdminEvidenceClaimRequest uncertainty(String uncertainty);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminEvidenceClaimRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminEvidenceClaimRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminEvidenceClaimRequest call({
    String claimType,
    DateTime? observedAt,
    String sourceId,
    CreateAdminEvidenceClaimRequestStatusEnum status,
    String summary,
    String uncertainty,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateAdminEvidenceClaimRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateAdminEvidenceClaimRequest.copyWith.fieldName(...)`
class _$CreateAdminEvidenceClaimRequestCWProxyImpl
    implements _$CreateAdminEvidenceClaimRequestCWProxy {
  const _$CreateAdminEvidenceClaimRequestCWProxyImpl(this._value);

  final CreateAdminEvidenceClaimRequest _value;

  @override
  CreateAdminEvidenceClaimRequest claimType(String claimType) =>
      this(claimType: claimType);

  @override
  CreateAdminEvidenceClaimRequest observedAt(DateTime? observedAt) =>
      this(observedAt: observedAt);

  @override
  CreateAdminEvidenceClaimRequest sourceId(String sourceId) =>
      this(sourceId: sourceId);

  @override
  CreateAdminEvidenceClaimRequest status(
    CreateAdminEvidenceClaimRequestStatusEnum status,
  ) => this(status: status);

  @override
  CreateAdminEvidenceClaimRequest summary(String summary) =>
      this(summary: summary);

  @override
  CreateAdminEvidenceClaimRequest uncertainty(String uncertainty) =>
      this(uncertainty: uncertainty);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminEvidenceClaimRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminEvidenceClaimRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminEvidenceClaimRequest call({
    Object? claimType = const $CopyWithPlaceholder(),
    Object? observedAt = const $CopyWithPlaceholder(),
    Object? sourceId = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? summary = const $CopyWithPlaceholder(),
    Object? uncertainty = const $CopyWithPlaceholder(),
  }) {
    return CreateAdminEvidenceClaimRequest(
      claimType: claimType == const $CopyWithPlaceholder()
          ? _value.claimType
          // ignore: cast_nullable_to_non_nullable
          : claimType as String,
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
          : status as CreateAdminEvidenceClaimRequestStatusEnum,
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

extension $CreateAdminEvidenceClaimRequestCopyWith
    on CreateAdminEvidenceClaimRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateAdminEvidenceClaimRequest.copyWith(...)` or like so:`instanceOfCreateAdminEvidenceClaimRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateAdminEvidenceClaimRequestCWProxy get copyWith =>
      _$CreateAdminEvidenceClaimRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAdminEvidenceClaimRequest _$CreateAdminEvidenceClaimRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'CreateAdminEvidenceClaimRequest',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'claim_type',
        'observed_at',
        'source_id',
        'status',
        'summary',
        'uncertainty',
      ],
    );
    final val = CreateAdminEvidenceClaimRequest(
      claimType: $checkedConvert('claim_type', (v) => v as String),
      observedAt: $checkedConvert(
        'observed_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      sourceId: $checkedConvert('source_id', (v) => v as String),
      status: $checkedConvert(
        'status',
        (v) => $enumDecode(
          _$CreateAdminEvidenceClaimRequestStatusEnumEnumMap,
          v,
          unknownValue:
              CreateAdminEvidenceClaimRequestStatusEnum.unknownDefaultOpenApi,
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

Map<String, dynamic> _$CreateAdminEvidenceClaimRequestToJson(
  CreateAdminEvidenceClaimRequest instance,
) => <String, dynamic>{
  'claim_type': instance.claimType,
  'observed_at': instance.observedAt?.toIso8601String(),
  'source_id': instance.sourceId,
  'status':
      _$CreateAdminEvidenceClaimRequestStatusEnumEnumMap[instance.status]!,
  'summary': instance.summary,
  'uncertainty': instance.uncertainty,
};

const _$CreateAdminEvidenceClaimRequestStatusEnumEnumMap = {
  CreateAdminEvidenceClaimRequestStatusEnum.active: 'active',
  CreateAdminEvidenceClaimRequestStatusEnum.superseded: 'superseded',
  CreateAdminEvidenceClaimRequestStatusEnum.withdrawn: 'withdrawn',
  CreateAdminEvidenceClaimRequestStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
