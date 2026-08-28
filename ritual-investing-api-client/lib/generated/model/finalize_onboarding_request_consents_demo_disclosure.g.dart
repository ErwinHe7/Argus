// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finalize_onboarding_request_consents_demo_disclosure.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FinalizeOnboardingRequestConsentsDemoDisclosureCWProxy {
  FinalizeOnboardingRequestConsentsDemoDisclosure decision(
    FinalizeOnboardingRequestConsentsDemoDisclosureDecisionEnum decision,
  );

  FinalizeOnboardingRequestConsentsDemoDisclosure policyVersion(
    String policyVersion,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FinalizeOnboardingRequestConsentsDemoDisclosure(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FinalizeOnboardingRequestConsentsDemoDisclosure(...).copyWith(id: 12, name: "My name")
  /// ````
  FinalizeOnboardingRequestConsentsDemoDisclosure call({
    FinalizeOnboardingRequestConsentsDemoDisclosureDecisionEnum decision,
    String policyVersion,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfFinalizeOnboardingRequestConsentsDemoDisclosure.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfFinalizeOnboardingRequestConsentsDemoDisclosure.copyWith.fieldName(...)`
class _$FinalizeOnboardingRequestConsentsDemoDisclosureCWProxyImpl
    implements _$FinalizeOnboardingRequestConsentsDemoDisclosureCWProxy {
  const _$FinalizeOnboardingRequestConsentsDemoDisclosureCWProxyImpl(
    this._value,
  );

  final FinalizeOnboardingRequestConsentsDemoDisclosure _value;

  @override
  FinalizeOnboardingRequestConsentsDemoDisclosure decision(
    FinalizeOnboardingRequestConsentsDemoDisclosureDecisionEnum decision,
  ) => this(decision: decision);

  @override
  FinalizeOnboardingRequestConsentsDemoDisclosure policyVersion(
    String policyVersion,
  ) => this(policyVersion: policyVersion);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FinalizeOnboardingRequestConsentsDemoDisclosure(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FinalizeOnboardingRequestConsentsDemoDisclosure(...).copyWith(id: 12, name: "My name")
  /// ````
  FinalizeOnboardingRequestConsentsDemoDisclosure call({
    Object? decision = const $CopyWithPlaceholder(),
    Object? policyVersion = const $CopyWithPlaceholder(),
  }) {
    return FinalizeOnboardingRequestConsentsDemoDisclosure(
      decision: decision == const $CopyWithPlaceholder()
          ? _value.decision
          // ignore: cast_nullable_to_non_nullable
          : decision
                as FinalizeOnboardingRequestConsentsDemoDisclosureDecisionEnum,
      policyVersion: policyVersion == const $CopyWithPlaceholder()
          ? _value.policyVersion
          // ignore: cast_nullable_to_non_nullable
          : policyVersion as String,
    );
  }
}

extension $FinalizeOnboardingRequestConsentsDemoDisclosureCopyWith
    on FinalizeOnboardingRequestConsentsDemoDisclosure {
  /// Returns a callable class that can be used as follows: `instanceOfFinalizeOnboardingRequestConsentsDemoDisclosure.copyWith(...)` or like so:`instanceOfFinalizeOnboardingRequestConsentsDemoDisclosure.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FinalizeOnboardingRequestConsentsDemoDisclosureCWProxy get copyWith =>
      _$FinalizeOnboardingRequestConsentsDemoDisclosureCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FinalizeOnboardingRequestConsentsDemoDisclosure
_$FinalizeOnboardingRequestConsentsDemoDisclosureFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('FinalizeOnboardingRequestConsentsDemoDisclosure', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['decision', 'policy_version']);
  final val = FinalizeOnboardingRequestConsentsDemoDisclosure(
    decision: $checkedConvert(
      'decision',
      (v) => $enumDecode(
        _$FinalizeOnboardingRequestConsentsDemoDisclosureDecisionEnumEnumMap,
        v,
        unknownValue:
            FinalizeOnboardingRequestConsentsDemoDisclosureDecisionEnum
                .unknownDefaultOpenApi,
      ),
    ),
    policyVersion: $checkedConvert('policy_version', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'policyVersion': 'policy_version'});

Map<String, dynamic> _$FinalizeOnboardingRequestConsentsDemoDisclosureToJson(
  FinalizeOnboardingRequestConsentsDemoDisclosure instance,
) => <String, dynamic>{
  'decision':
      _$FinalizeOnboardingRequestConsentsDemoDisclosureDecisionEnumEnumMap[instance
          .decision]!,
  'policy_version': instance.policyVersion,
};

const _$FinalizeOnboardingRequestConsentsDemoDisclosureDecisionEnumEnumMap = {
  FinalizeOnboardingRequestConsentsDemoDisclosureDecisionEnum.accepted:
      'accepted',
  FinalizeOnboardingRequestConsentsDemoDisclosureDecisionEnum
          .unknownDefaultOpenApi:
      'unknown_default_open_api',
};
