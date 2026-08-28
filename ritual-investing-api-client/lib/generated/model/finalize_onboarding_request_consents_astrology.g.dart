// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finalize_onboarding_request_consents_astrology.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FinalizeOnboardingRequestConsentsAstrologyCWProxy {
  FinalizeOnboardingRequestConsentsAstrology decision(
    FinalizeOnboardingRequestConsentsAstrologyDecisionEnum decision,
  );

  FinalizeOnboardingRequestConsentsAstrology policyVersion(
    String policyVersion,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FinalizeOnboardingRequestConsentsAstrology(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FinalizeOnboardingRequestConsentsAstrology(...).copyWith(id: 12, name: "My name")
  /// ````
  FinalizeOnboardingRequestConsentsAstrology call({
    FinalizeOnboardingRequestConsentsAstrologyDecisionEnum decision,
    String policyVersion,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfFinalizeOnboardingRequestConsentsAstrology.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfFinalizeOnboardingRequestConsentsAstrology.copyWith.fieldName(...)`
class _$FinalizeOnboardingRequestConsentsAstrologyCWProxyImpl
    implements _$FinalizeOnboardingRequestConsentsAstrologyCWProxy {
  const _$FinalizeOnboardingRequestConsentsAstrologyCWProxyImpl(this._value);

  final FinalizeOnboardingRequestConsentsAstrology _value;

  @override
  FinalizeOnboardingRequestConsentsAstrology decision(
    FinalizeOnboardingRequestConsentsAstrologyDecisionEnum decision,
  ) => this(decision: decision);

  @override
  FinalizeOnboardingRequestConsentsAstrology policyVersion(
    String policyVersion,
  ) => this(policyVersion: policyVersion);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FinalizeOnboardingRequestConsentsAstrology(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FinalizeOnboardingRequestConsentsAstrology(...).copyWith(id: 12, name: "My name")
  /// ````
  FinalizeOnboardingRequestConsentsAstrology call({
    Object? decision = const $CopyWithPlaceholder(),
    Object? policyVersion = const $CopyWithPlaceholder(),
  }) {
    return FinalizeOnboardingRequestConsentsAstrology(
      decision: decision == const $CopyWithPlaceholder()
          ? _value.decision
          // ignore: cast_nullable_to_non_nullable
          : decision as FinalizeOnboardingRequestConsentsAstrologyDecisionEnum,
      policyVersion: policyVersion == const $CopyWithPlaceholder()
          ? _value.policyVersion
          // ignore: cast_nullable_to_non_nullable
          : policyVersion as String,
    );
  }
}

extension $FinalizeOnboardingRequestConsentsAstrologyCopyWith
    on FinalizeOnboardingRequestConsentsAstrology {
  /// Returns a callable class that can be used as follows: `instanceOfFinalizeOnboardingRequestConsentsAstrology.copyWith(...)` or like so:`instanceOfFinalizeOnboardingRequestConsentsAstrology.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FinalizeOnboardingRequestConsentsAstrologyCWProxy get copyWith =>
      _$FinalizeOnboardingRequestConsentsAstrologyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FinalizeOnboardingRequestConsentsAstrology
_$FinalizeOnboardingRequestConsentsAstrologyFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('FinalizeOnboardingRequestConsentsAstrology', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['decision', 'policy_version']);
  final val = FinalizeOnboardingRequestConsentsAstrology(
    decision: $checkedConvert(
      'decision',
      (v) => $enumDecode(
        _$FinalizeOnboardingRequestConsentsAstrologyDecisionEnumEnumMap,
        v,
        unknownValue: FinalizeOnboardingRequestConsentsAstrologyDecisionEnum
            .unknownDefaultOpenApi,
      ),
    ),
    policyVersion: $checkedConvert('policy_version', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'policyVersion': 'policy_version'});

Map<String, dynamic> _$FinalizeOnboardingRequestConsentsAstrologyToJson(
  FinalizeOnboardingRequestConsentsAstrology instance,
) => <String, dynamic>{
  'decision':
      _$FinalizeOnboardingRequestConsentsAstrologyDecisionEnumEnumMap[instance
          .decision]!,
  'policy_version': instance.policyVersion,
};

const _$FinalizeOnboardingRequestConsentsAstrologyDecisionEnumEnumMap = {
  FinalizeOnboardingRequestConsentsAstrologyDecisionEnum.accepted: 'accepted',
  FinalizeOnboardingRequestConsentsAstrologyDecisionEnum.declined: 'declined',
  FinalizeOnboardingRequestConsentsAstrologyDecisionEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
