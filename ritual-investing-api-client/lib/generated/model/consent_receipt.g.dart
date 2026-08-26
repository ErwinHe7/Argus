// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'consent_receipt.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ConsentReceiptCWProxy {
  ConsentReceipt decision(ConsentReceiptDecisionEnum decision);

  ConsentReceipt id(String id);

  ConsentReceipt policyCode(ConsentReceiptPolicyCodeEnum policyCode);

  ConsentReceipt policyVersion(String policyVersion);

  ConsentReceipt recordedAt(DateTime recordedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ConsentReceipt(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ConsentReceipt(...).copyWith(id: 12, name: "My name")
  /// ````
  ConsentReceipt call({
    ConsentReceiptDecisionEnum decision,
    String id,
    ConsentReceiptPolicyCodeEnum policyCode,
    String policyVersion,
    DateTime recordedAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfConsentReceipt.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfConsentReceipt.copyWith.fieldName(...)`
class _$ConsentReceiptCWProxyImpl implements _$ConsentReceiptCWProxy {
  const _$ConsentReceiptCWProxyImpl(this._value);

  final ConsentReceipt _value;

  @override
  ConsentReceipt decision(ConsentReceiptDecisionEnum decision) =>
      this(decision: decision);

  @override
  ConsentReceipt id(String id) => this(id: id);

  @override
  ConsentReceipt policyCode(ConsentReceiptPolicyCodeEnum policyCode) =>
      this(policyCode: policyCode);

  @override
  ConsentReceipt policyVersion(String policyVersion) =>
      this(policyVersion: policyVersion);

  @override
  ConsentReceipt recordedAt(DateTime recordedAt) =>
      this(recordedAt: recordedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ConsentReceipt(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ConsentReceipt(...).copyWith(id: 12, name: "My name")
  /// ````
  ConsentReceipt call({
    Object? decision = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? policyCode = const $CopyWithPlaceholder(),
    Object? policyVersion = const $CopyWithPlaceholder(),
    Object? recordedAt = const $CopyWithPlaceholder(),
  }) {
    return ConsentReceipt(
      decision: decision == const $CopyWithPlaceholder()
          ? _value.decision
          // ignore: cast_nullable_to_non_nullable
          : decision as ConsentReceiptDecisionEnum,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      policyCode: policyCode == const $CopyWithPlaceholder()
          ? _value.policyCode
          // ignore: cast_nullable_to_non_nullable
          : policyCode as ConsentReceiptPolicyCodeEnum,
      policyVersion: policyVersion == const $CopyWithPlaceholder()
          ? _value.policyVersion
          // ignore: cast_nullable_to_non_nullable
          : policyVersion as String,
      recordedAt: recordedAt == const $CopyWithPlaceholder()
          ? _value.recordedAt
          // ignore: cast_nullable_to_non_nullable
          : recordedAt as DateTime,
    );
  }
}

extension $ConsentReceiptCopyWith on ConsentReceipt {
  /// Returns a callable class that can be used as follows: `instanceOfConsentReceipt.copyWith(...)` or like so:`instanceOfConsentReceipt.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ConsentReceiptCWProxy get copyWith => _$ConsentReceiptCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConsentReceipt _$ConsentReceiptFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'ConsentReceipt',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'decision',
            'id',
            'policy_code',
            'policy_version',
            'recorded_at',
          ],
        );
        final val = ConsentReceipt(
          decision: $checkedConvert(
            'decision',
            (v) => $enumDecode(
              _$ConsentReceiptDecisionEnumEnumMap,
              v,
              unknownValue: ConsentReceiptDecisionEnum.unknownDefaultOpenApi,
            ),
          ),
          id: $checkedConvert('id', (v) => v as String),
          policyCode: $checkedConvert(
            'policy_code',
            (v) => $enumDecode(
              _$ConsentReceiptPolicyCodeEnumEnumMap,
              v,
              unknownValue: ConsentReceiptPolicyCodeEnum.unknownDefaultOpenApi,
            ),
          ),
          policyVersion: $checkedConvert('policy_version', (v) => v as String),
          recordedAt: $checkedConvert(
            'recorded_at',
            (v) => DateTime.parse(v as String),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'policyCode': 'policy_code',
        'policyVersion': 'policy_version',
        'recordedAt': 'recorded_at',
      },
    );

Map<String, dynamic> _$ConsentReceiptToJson(
  ConsentReceipt instance,
) => <String, dynamic>{
  'decision': _$ConsentReceiptDecisionEnumEnumMap[instance.decision]!,
  'id': instance.id,
  'policy_code': _$ConsentReceiptPolicyCodeEnumEnumMap[instance.policyCode]!,
  'policy_version': instance.policyVersion,
  'recorded_at': instance.recordedAt.toIso8601String(),
};

const _$ConsentReceiptDecisionEnumEnumMap = {
  ConsentReceiptDecisionEnum.accepted: 'accepted',
  ConsentReceiptDecisionEnum.declined: 'declined',
  ConsentReceiptDecisionEnum.withdrawn: 'withdrawn',
  ConsentReceiptDecisionEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$ConsentReceiptPolicyCodeEnumEnumMap = {
  ConsentReceiptPolicyCodeEnum.terms: 'terms',
  ConsentReceiptPolicyCodeEnum.privacy: 'privacy',
  ConsentReceiptPolicyCodeEnum.demoDisclosure: 'demo_disclosure',
  ConsentReceiptPolicyCodeEnum.astrology: 'astrology',
  ConsentReceiptPolicyCodeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
