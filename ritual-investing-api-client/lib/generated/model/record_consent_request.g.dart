// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'record_consent_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RecordConsentRequestCWProxy {
  RecordConsentRequest decision(RecordConsentRequestDecisionEnum decision);

  RecordConsentRequest policyCode(String policyCode);

  RecordConsentRequest policyVersion(String policyVersion);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RecordConsentRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RecordConsentRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RecordConsentRequest call({
    RecordConsentRequestDecisionEnum decision,
    String policyCode,
    String policyVersion,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRecordConsentRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRecordConsentRequest.copyWith.fieldName(...)`
class _$RecordConsentRequestCWProxyImpl
    implements _$RecordConsentRequestCWProxy {
  const _$RecordConsentRequestCWProxyImpl(this._value);

  final RecordConsentRequest _value;

  @override
  RecordConsentRequest decision(RecordConsentRequestDecisionEnum decision) =>
      this(decision: decision);

  @override
  RecordConsentRequest policyCode(String policyCode) =>
      this(policyCode: policyCode);

  @override
  RecordConsentRequest policyVersion(String policyVersion) =>
      this(policyVersion: policyVersion);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RecordConsentRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RecordConsentRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RecordConsentRequest call({
    Object? decision = const $CopyWithPlaceholder(),
    Object? policyCode = const $CopyWithPlaceholder(),
    Object? policyVersion = const $CopyWithPlaceholder(),
  }) {
    return RecordConsentRequest(
      decision: decision == const $CopyWithPlaceholder()
          ? _value.decision
          // ignore: cast_nullable_to_non_nullable
          : decision as RecordConsentRequestDecisionEnum,
      policyCode: policyCode == const $CopyWithPlaceholder()
          ? _value.policyCode
          // ignore: cast_nullable_to_non_nullable
          : policyCode as String,
      policyVersion: policyVersion == const $CopyWithPlaceholder()
          ? _value.policyVersion
          // ignore: cast_nullable_to_non_nullable
          : policyVersion as String,
    );
  }
}

extension $RecordConsentRequestCopyWith on RecordConsentRequest {
  /// Returns a callable class that can be used as follows: `instanceOfRecordConsentRequest.copyWith(...)` or like so:`instanceOfRecordConsentRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RecordConsentRequestCWProxy get copyWith =>
      _$RecordConsentRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecordConsentRequest _$RecordConsentRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('RecordConsentRequest', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['decision', 'policyCode', 'policyVersion'],
  );
  final val = RecordConsentRequest(
    decision: $checkedConvert(
      'decision',
      (v) => $enumDecode(
        _$RecordConsentRequestDecisionEnumEnumMap,
        v,
        unknownValue: RecordConsentRequestDecisionEnum.unknownDefaultOpenApi,
      ),
    ),
    policyCode: $checkedConvert('policyCode', (v) => v as String),
    policyVersion: $checkedConvert('policyVersion', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$RecordConsentRequestToJson(
  RecordConsentRequest instance,
) => <String, dynamic>{
  'decision': _$RecordConsentRequestDecisionEnumEnumMap[instance.decision]!,
  'policyCode': instance.policyCode,
  'policyVersion': instance.policyVersion,
};

const _$RecordConsentRequestDecisionEnumEnumMap = {
  RecordConsentRequestDecisionEnum.accepted: 'accepted',
  RecordConsentRequestDecisionEnum.declined: 'declined',
  RecordConsentRequestDecisionEnum.withdrawn: 'withdrawn',
  RecordConsentRequestDecisionEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
