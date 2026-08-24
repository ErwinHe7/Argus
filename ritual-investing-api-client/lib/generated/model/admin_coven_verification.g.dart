// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_coven_verification.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AdminCovenVerificationCWProxy {
  AdminCovenVerification effectiveAsOf(DateTime effectiveAsOf);

  AdminCovenVerification evidenceClaimIds(List<String> evidenceClaimIds);

  AdminCovenVerification id(String id);

  AdminCovenVerification qualificationId(String qualificationId);

  AdminCovenVerification status(AdminCovenVerificationStatusEnum status);

  AdminCovenVerification supersedesId(String? supersedesId);

  AdminCovenVerification verifiedAt(DateTime verifiedAt);

  AdminCovenVerification verifiedBy(String verifiedBy);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminCovenVerification(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminCovenVerification(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminCovenVerification call({
    DateTime effectiveAsOf,
    List<String> evidenceClaimIds,
    String id,
    String qualificationId,
    AdminCovenVerificationStatusEnum status,
    String? supersedesId,
    DateTime verifiedAt,
    String verifiedBy,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAdminCovenVerification.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAdminCovenVerification.copyWith.fieldName(...)`
class _$AdminCovenVerificationCWProxyImpl
    implements _$AdminCovenVerificationCWProxy {
  const _$AdminCovenVerificationCWProxyImpl(this._value);

  final AdminCovenVerification _value;

  @override
  AdminCovenVerification effectiveAsOf(DateTime effectiveAsOf) =>
      this(effectiveAsOf: effectiveAsOf);

  @override
  AdminCovenVerification evidenceClaimIds(List<String> evidenceClaimIds) =>
      this(evidenceClaimIds: evidenceClaimIds);

  @override
  AdminCovenVerification id(String id) => this(id: id);

  @override
  AdminCovenVerification qualificationId(String qualificationId) =>
      this(qualificationId: qualificationId);

  @override
  AdminCovenVerification status(AdminCovenVerificationStatusEnum status) =>
      this(status: status);

  @override
  AdminCovenVerification supersedesId(String? supersedesId) =>
      this(supersedesId: supersedesId);

  @override
  AdminCovenVerification verifiedAt(DateTime verifiedAt) =>
      this(verifiedAt: verifiedAt);

  @override
  AdminCovenVerification verifiedBy(String verifiedBy) =>
      this(verifiedBy: verifiedBy);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminCovenVerification(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminCovenVerification(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminCovenVerification call({
    Object? effectiveAsOf = const $CopyWithPlaceholder(),
    Object? evidenceClaimIds = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? qualificationId = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? supersedesId = const $CopyWithPlaceholder(),
    Object? verifiedAt = const $CopyWithPlaceholder(),
    Object? verifiedBy = const $CopyWithPlaceholder(),
  }) {
    return AdminCovenVerification(
      effectiveAsOf: effectiveAsOf == const $CopyWithPlaceholder()
          ? _value.effectiveAsOf
          // ignore: cast_nullable_to_non_nullable
          : effectiveAsOf as DateTime,
      evidenceClaimIds: evidenceClaimIds == const $CopyWithPlaceholder()
          ? _value.evidenceClaimIds
          // ignore: cast_nullable_to_non_nullable
          : evidenceClaimIds as List<String>,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      qualificationId: qualificationId == const $CopyWithPlaceholder()
          ? _value.qualificationId
          // ignore: cast_nullable_to_non_nullable
          : qualificationId as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as AdminCovenVerificationStatusEnum,
      supersedesId: supersedesId == const $CopyWithPlaceholder()
          ? _value.supersedesId
          // ignore: cast_nullable_to_non_nullable
          : supersedesId as String?,
      verifiedAt: verifiedAt == const $CopyWithPlaceholder()
          ? _value.verifiedAt
          // ignore: cast_nullable_to_non_nullable
          : verifiedAt as DateTime,
      verifiedBy: verifiedBy == const $CopyWithPlaceholder()
          ? _value.verifiedBy
          // ignore: cast_nullable_to_non_nullable
          : verifiedBy as String,
    );
  }
}

extension $AdminCovenVerificationCopyWith on AdminCovenVerification {
  /// Returns a callable class that can be used as follows: `instanceOfAdminCovenVerification.copyWith(...)` or like so:`instanceOfAdminCovenVerification.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AdminCovenVerificationCWProxy get copyWith =>
      _$AdminCovenVerificationCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminCovenVerification _$AdminCovenVerificationFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'AdminCovenVerification',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'effective_as_of',
        'evidence_claim_ids',
        'id',
        'qualification_id',
        'status',
        'supersedes_id',
        'verified_at',
        'verified_by',
      ],
    );
    final val = AdminCovenVerification(
      effectiveAsOf: $checkedConvert(
        'effective_as_of',
        (v) => DateTime.parse(v as String),
      ),
      evidenceClaimIds: $checkedConvert(
        'evidence_claim_ids',
        (v) => (v as List<dynamic>).map((e) => e as String).toList(),
      ),
      id: $checkedConvert('id', (v) => v as String),
      qualificationId: $checkedConvert('qualification_id', (v) => v as String),
      status: $checkedConvert(
        'status',
        (v) => $enumDecode(
          _$AdminCovenVerificationStatusEnumEnumMap,
          v,
          unknownValue: AdminCovenVerificationStatusEnum.unknownDefaultOpenApi,
        ),
      ),
      supersedesId: $checkedConvert('supersedes_id', (v) => v as String?),
      verifiedAt: $checkedConvert(
        'verified_at',
        (v) => DateTime.parse(v as String),
      ),
      verifiedBy: $checkedConvert('verified_by', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'effectiveAsOf': 'effective_as_of',
    'evidenceClaimIds': 'evidence_claim_ids',
    'qualificationId': 'qualification_id',
    'supersedesId': 'supersedes_id',
    'verifiedAt': 'verified_at',
    'verifiedBy': 'verified_by',
  },
);

Map<String, dynamic> _$AdminCovenVerificationToJson(
  AdminCovenVerification instance,
) => <String, dynamic>{
  'effective_as_of': instance.effectiveAsOf.toIso8601String(),
  'evidence_claim_ids': instance.evidenceClaimIds,
  'id': instance.id,
  'qualification_id': instance.qualificationId,
  'status': _$AdminCovenVerificationStatusEnumEnumMap[instance.status]!,
  'supersedes_id': instance.supersedesId,
  'verified_at': instance.verifiedAt.toIso8601String(),
  'verified_by': instance.verifiedBy,
};

const _$AdminCovenVerificationStatusEnumEnumMap = {
  AdminCovenVerificationStatusEnum.verified: 'verified',
  AdminCovenVerificationStatusEnum.rejected: 'rejected',
  AdminCovenVerificationStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
