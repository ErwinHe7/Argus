// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_consent_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateConsentRequestCWProxy {
  CreateConsentRequest decision(CreateConsentRequestDecisionEnum decision);

  CreateConsentRequest policyCode(
    CreateConsentRequestPolicyCodeEnum policyCode,
  );

  CreateConsentRequest policyVersion(String policyVersion);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateConsentRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateConsentRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateConsentRequest call({
    CreateConsentRequestDecisionEnum decision,
    CreateConsentRequestPolicyCodeEnum policyCode,
    String policyVersion,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateConsentRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateConsentRequest.copyWith.fieldName(...)`
class _$CreateConsentRequestCWProxyImpl
    implements _$CreateConsentRequestCWProxy {
  const _$CreateConsentRequestCWProxyImpl(this._value);

  final CreateConsentRequest _value;

  @override
  CreateConsentRequest decision(CreateConsentRequestDecisionEnum decision) =>
      this(decision: decision);

  @override
  CreateConsentRequest policyCode(
    CreateConsentRequestPolicyCodeEnum policyCode,
  ) => this(policyCode: policyCode);

  @override
  CreateConsentRequest policyVersion(String policyVersion) =>
      this(policyVersion: policyVersion);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateConsentRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateConsentRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateConsentRequest call({
    Object? decision = const $CopyWithPlaceholder(),
    Object? policyCode = const $CopyWithPlaceholder(),
    Object? policyVersion = const $CopyWithPlaceholder(),
  }) {
    return CreateConsentRequest(
      decision: decision == const $CopyWithPlaceholder()
          ? _value.decision
          // ignore: cast_nullable_to_non_nullable
          : decision as CreateConsentRequestDecisionEnum,
      policyCode: policyCode == const $CopyWithPlaceholder()
          ? _value.policyCode
          // ignore: cast_nullable_to_non_nullable
          : policyCode as CreateConsentRequestPolicyCodeEnum,
      policyVersion: policyVersion == const $CopyWithPlaceholder()
          ? _value.policyVersion
          // ignore: cast_nullable_to_non_nullable
          : policyVersion as String,
    );
  }
}

extension $CreateConsentRequestCopyWith on CreateConsentRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateConsentRequest.copyWith(...)` or like so:`instanceOfCreateConsentRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateConsentRequestCWProxy get copyWith =>
      _$CreateConsentRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateConsentRequest _$CreateConsentRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'CreateConsentRequest',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const ['decision', 'policy_code', 'policy_version'],
    );
    final val = CreateConsentRequest(
      decision: $checkedConvert(
        'decision',
        (v) => $enumDecode(
          _$CreateConsentRequestDecisionEnumEnumMap,
          v,
          unknownValue: CreateConsentRequestDecisionEnum.unknownDefaultOpenApi,
        ),
      ),
      policyCode: $checkedConvert(
        'policy_code',
        (v) => $enumDecode(
          _$CreateConsentRequestPolicyCodeEnumEnumMap,
          v,
          unknownValue:
              CreateConsentRequestPolicyCodeEnum.unknownDefaultOpenApi,
        ),
      ),
      policyVersion: $checkedConvert('policy_version', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'policyCode': 'policy_code',
    'policyVersion': 'policy_version',
  },
);

Map<String, dynamic> _$CreateConsentRequestToJson(
  CreateConsentRequest instance,
) => <String, dynamic>{
  'decision': _$CreateConsentRequestDecisionEnumEnumMap[instance.decision]!,
  'policy_code':
      _$CreateConsentRequestPolicyCodeEnumEnumMap[instance.policyCode]!,
  'policy_version': instance.policyVersion,
};

const _$CreateConsentRequestDecisionEnumEnumMap = {
  CreateConsentRequestDecisionEnum.accepted: 'accepted',
  CreateConsentRequestDecisionEnum.declined: 'declined',
  CreateConsentRequestDecisionEnum.withdrawn: 'withdrawn',
  CreateConsentRequestDecisionEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$CreateConsentRequestPolicyCodeEnumEnumMap = {
  CreateConsentRequestPolicyCodeEnum.terms: 'terms',
  CreateConsentRequestPolicyCodeEnum.privacy: 'privacy',
  CreateConsentRequestPolicyCodeEnum.demoDisclosure: 'demo_disclosure',
  CreateConsentRequestPolicyCodeEnum.astrology: 'astrology',
  CreateConsentRequestPolicyCodeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
