// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'birthday_accepted_onboarding_consent.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BirthdayAcceptedOnboardingConsentCWProxy {
  BirthdayAcceptedOnboardingConsent decision(
    BirthdayAcceptedOnboardingConsentDecisionEnum decision,
  );

  BirthdayAcceptedOnboardingConsent policyVersion(String policyVersion);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BirthdayAcceptedOnboardingConsent(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BirthdayAcceptedOnboardingConsent(...).copyWith(id: 12, name: "My name")
  /// ````
  BirthdayAcceptedOnboardingConsent call({
    BirthdayAcceptedOnboardingConsentDecisionEnum decision,
    String policyVersion,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBirthdayAcceptedOnboardingConsent.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBirthdayAcceptedOnboardingConsent.copyWith.fieldName(...)`
class _$BirthdayAcceptedOnboardingConsentCWProxyImpl
    implements _$BirthdayAcceptedOnboardingConsentCWProxy {
  const _$BirthdayAcceptedOnboardingConsentCWProxyImpl(this._value);

  final BirthdayAcceptedOnboardingConsent _value;

  @override
  BirthdayAcceptedOnboardingConsent decision(
    BirthdayAcceptedOnboardingConsentDecisionEnum decision,
  ) => this(decision: decision);

  @override
  BirthdayAcceptedOnboardingConsent policyVersion(String policyVersion) =>
      this(policyVersion: policyVersion);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BirthdayAcceptedOnboardingConsent(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BirthdayAcceptedOnboardingConsent(...).copyWith(id: 12, name: "My name")
  /// ````
  BirthdayAcceptedOnboardingConsent call({
    Object? decision = const $CopyWithPlaceholder(),
    Object? policyVersion = const $CopyWithPlaceholder(),
  }) {
    return BirthdayAcceptedOnboardingConsent(
      decision: decision == const $CopyWithPlaceholder()
          ? _value.decision
          // ignore: cast_nullable_to_non_nullable
          : decision as BirthdayAcceptedOnboardingConsentDecisionEnum,
      policyVersion: policyVersion == const $CopyWithPlaceholder()
          ? _value.policyVersion
          // ignore: cast_nullable_to_non_nullable
          : policyVersion as String,
    );
  }
}

extension $BirthdayAcceptedOnboardingConsentCopyWith
    on BirthdayAcceptedOnboardingConsent {
  /// Returns a callable class that can be used as follows: `instanceOfBirthdayAcceptedOnboardingConsent.copyWith(...)` or like so:`instanceOfBirthdayAcceptedOnboardingConsent.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BirthdayAcceptedOnboardingConsentCWProxy get copyWith =>
      _$BirthdayAcceptedOnboardingConsentCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BirthdayAcceptedOnboardingConsent _$BirthdayAcceptedOnboardingConsentFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('BirthdayAcceptedOnboardingConsent', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['decision', 'policy_version']);
  final val = BirthdayAcceptedOnboardingConsent(
    decision: $checkedConvert(
      'decision',
      (v) => $enumDecode(
        _$BirthdayAcceptedOnboardingConsentDecisionEnumEnumMap,
        v,
        unknownValue:
            BirthdayAcceptedOnboardingConsentDecisionEnum.unknownDefaultOpenApi,
      ),
    ),
    policyVersion: $checkedConvert('policy_version', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'policyVersion': 'policy_version'});

Map<String, dynamic> _$BirthdayAcceptedOnboardingConsentToJson(
  BirthdayAcceptedOnboardingConsent instance,
) => <String, dynamic>{
  'decision':
      _$BirthdayAcceptedOnboardingConsentDecisionEnumEnumMap[instance
          .decision]!,
  'policy_version': instance.policyVersion,
};

const _$BirthdayAcceptedOnboardingConsentDecisionEnumEnumMap = {
  BirthdayAcceptedOnboardingConsentDecisionEnum.accepted: 'accepted',
  BirthdayAcceptedOnboardingConsentDecisionEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
