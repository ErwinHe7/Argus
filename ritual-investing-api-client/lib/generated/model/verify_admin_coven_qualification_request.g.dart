// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'verify_admin_coven_qualification_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$VerifyAdminCovenQualificationRequestCWProxy {
  VerifyAdminCovenQualificationRequest decision(
    VerifyAdminCovenQualificationRequestDecisionEnum decision,
  );

  VerifyAdminCovenQualificationRequest effectiveAsOf(DateTime effectiveAsOf);

  VerifyAdminCovenQualificationRequest evidenceClaimIds(
    List<String> evidenceClaimIds,
  );

  VerifyAdminCovenQualificationRequest reason(String reason);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `VerifyAdminCovenQualificationRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// VerifyAdminCovenQualificationRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  VerifyAdminCovenQualificationRequest call({
    VerifyAdminCovenQualificationRequestDecisionEnum decision,
    DateTime effectiveAsOf,
    List<String> evidenceClaimIds,
    String reason,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfVerifyAdminCovenQualificationRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfVerifyAdminCovenQualificationRequest.copyWith.fieldName(...)`
class _$VerifyAdminCovenQualificationRequestCWProxyImpl
    implements _$VerifyAdminCovenQualificationRequestCWProxy {
  const _$VerifyAdminCovenQualificationRequestCWProxyImpl(this._value);

  final VerifyAdminCovenQualificationRequest _value;

  @override
  VerifyAdminCovenQualificationRequest decision(
    VerifyAdminCovenQualificationRequestDecisionEnum decision,
  ) => this(decision: decision);

  @override
  VerifyAdminCovenQualificationRequest effectiveAsOf(DateTime effectiveAsOf) =>
      this(effectiveAsOf: effectiveAsOf);

  @override
  VerifyAdminCovenQualificationRequest evidenceClaimIds(
    List<String> evidenceClaimIds,
  ) => this(evidenceClaimIds: evidenceClaimIds);

  @override
  VerifyAdminCovenQualificationRequest reason(String reason) =>
      this(reason: reason);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `VerifyAdminCovenQualificationRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// VerifyAdminCovenQualificationRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  VerifyAdminCovenQualificationRequest call({
    Object? decision = const $CopyWithPlaceholder(),
    Object? effectiveAsOf = const $CopyWithPlaceholder(),
    Object? evidenceClaimIds = const $CopyWithPlaceholder(),
    Object? reason = const $CopyWithPlaceholder(),
  }) {
    return VerifyAdminCovenQualificationRequest(
      decision: decision == const $CopyWithPlaceholder()
          ? _value.decision
          // ignore: cast_nullable_to_non_nullable
          : decision as VerifyAdminCovenQualificationRequestDecisionEnum,
      effectiveAsOf: effectiveAsOf == const $CopyWithPlaceholder()
          ? _value.effectiveAsOf
          // ignore: cast_nullable_to_non_nullable
          : effectiveAsOf as DateTime,
      evidenceClaimIds: evidenceClaimIds == const $CopyWithPlaceholder()
          ? _value.evidenceClaimIds
          // ignore: cast_nullable_to_non_nullable
          : evidenceClaimIds as List<String>,
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as String,
    );
  }
}

extension $VerifyAdminCovenQualificationRequestCopyWith
    on VerifyAdminCovenQualificationRequest {
  /// Returns a callable class that can be used as follows: `instanceOfVerifyAdminCovenQualificationRequest.copyWith(...)` or like so:`instanceOfVerifyAdminCovenQualificationRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$VerifyAdminCovenQualificationRequestCWProxy get copyWith =>
      _$VerifyAdminCovenQualificationRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VerifyAdminCovenQualificationRequest
_$VerifyAdminCovenQualificationRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'VerifyAdminCovenQualificationRequest',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'decision',
            'effective_as_of',
            'evidence_claim_ids',
            'reason',
          ],
        );
        final val = VerifyAdminCovenQualificationRequest(
          decision: $checkedConvert(
            'decision',
            (v) => $enumDecode(
              _$VerifyAdminCovenQualificationRequestDecisionEnumEnumMap,
              v,
              unknownValue: VerifyAdminCovenQualificationRequestDecisionEnum
                  .unknownDefaultOpenApi,
            ),
          ),
          effectiveAsOf: $checkedConvert(
            'effective_as_of',
            (v) => DateTime.parse(v as String),
          ),
          evidenceClaimIds: $checkedConvert(
            'evidence_claim_ids',
            (v) => (v as List<dynamic>).map((e) => e as String).toList(),
          ),
          reason: $checkedConvert('reason', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'effectiveAsOf': 'effective_as_of',
        'evidenceClaimIds': 'evidence_claim_ids',
      },
    );

Map<String, dynamic> _$VerifyAdminCovenQualificationRequestToJson(
  VerifyAdminCovenQualificationRequest instance,
) => <String, dynamic>{
  'decision':
      _$VerifyAdminCovenQualificationRequestDecisionEnumEnumMap[instance
          .decision]!,
  'effective_as_of': instance.effectiveAsOf.toIso8601String(),
  'evidence_claim_ids': instance.evidenceClaimIds,
  'reason': instance.reason,
};

const _$VerifyAdminCovenQualificationRequestDecisionEnumEnumMap = {
  VerifyAdminCovenQualificationRequestDecisionEnum.verified: 'verified',
  VerifyAdminCovenQualificationRequestDecisionEnum.rejected: 'rejected',
  VerifyAdminCovenQualificationRequestDecisionEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
