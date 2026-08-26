// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finalize_onboarding_request_ritual.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FinalizeOnboardingRequestRitualCWProxy {
  FinalizeOnboardingRequestRitual familiarity(
    FinalizeOnboardingRequestRitualFamiliarityEnum familiarity,
  );

  FinalizeOnboardingRequestRitual interests(List<RitualInterest> interests);

  FinalizeOnboardingRequestRitual languagePreference(
    FinalizeOnboardingRequestRitualLanguagePreferenceEnum languagePreference,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FinalizeOnboardingRequestRitual(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FinalizeOnboardingRequestRitual(...).copyWith(id: 12, name: "My name")
  /// ````
  FinalizeOnboardingRequestRitual call({
    FinalizeOnboardingRequestRitualFamiliarityEnum familiarity,
    List<RitualInterest> interests,
    FinalizeOnboardingRequestRitualLanguagePreferenceEnum languagePreference,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfFinalizeOnboardingRequestRitual.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfFinalizeOnboardingRequestRitual.copyWith.fieldName(...)`
class _$FinalizeOnboardingRequestRitualCWProxyImpl
    implements _$FinalizeOnboardingRequestRitualCWProxy {
  const _$FinalizeOnboardingRequestRitualCWProxyImpl(this._value);

  final FinalizeOnboardingRequestRitual _value;

  @override
  FinalizeOnboardingRequestRitual familiarity(
    FinalizeOnboardingRequestRitualFamiliarityEnum familiarity,
  ) => this(familiarity: familiarity);

  @override
  FinalizeOnboardingRequestRitual interests(List<RitualInterest> interests) =>
      this(interests: interests);

  @override
  FinalizeOnboardingRequestRitual languagePreference(
    FinalizeOnboardingRequestRitualLanguagePreferenceEnum languagePreference,
  ) => this(languagePreference: languagePreference);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FinalizeOnboardingRequestRitual(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FinalizeOnboardingRequestRitual(...).copyWith(id: 12, name: "My name")
  /// ````
  FinalizeOnboardingRequestRitual call({
    Object? familiarity = const $CopyWithPlaceholder(),
    Object? interests = const $CopyWithPlaceholder(),
    Object? languagePreference = const $CopyWithPlaceholder(),
  }) {
    return FinalizeOnboardingRequestRitual(
      familiarity: familiarity == const $CopyWithPlaceholder()
          ? _value.familiarity
          // ignore: cast_nullable_to_non_nullable
          : familiarity as FinalizeOnboardingRequestRitualFamiliarityEnum,
      interests: interests == const $CopyWithPlaceholder()
          ? _value.interests
          // ignore: cast_nullable_to_non_nullable
          : interests as List<RitualInterest>,
      languagePreference: languagePreference == const $CopyWithPlaceholder()
          ? _value.languagePreference
          // ignore: cast_nullable_to_non_nullable
          : languagePreference
                as FinalizeOnboardingRequestRitualLanguagePreferenceEnum,
    );
  }
}

extension $FinalizeOnboardingRequestRitualCopyWith
    on FinalizeOnboardingRequestRitual {
  /// Returns a callable class that can be used as follows: `instanceOfFinalizeOnboardingRequestRitual.copyWith(...)` or like so:`instanceOfFinalizeOnboardingRequestRitual.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FinalizeOnboardingRequestRitualCWProxy get copyWith =>
      _$FinalizeOnboardingRequestRitualCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FinalizeOnboardingRequestRitual _$FinalizeOnboardingRequestRitualFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('FinalizeOnboardingRequestRitual', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['familiarity', 'interests', 'language_preference'],
  );
  final val = FinalizeOnboardingRequestRitual(
    familiarity: $checkedConvert(
      'familiarity',
      (v) => $enumDecode(
        _$FinalizeOnboardingRequestRitualFamiliarityEnumEnumMap,
        v,
        unknownValue: FinalizeOnboardingRequestRitualFamiliarityEnum
            .unknownDefaultOpenApi,
      ),
    ),
    interests: $checkedConvert(
      'interests',
      (v) => (v as List<dynamic>)
          .map((e) => $enumDecode(_$RitualInterestEnumMap, e))
          .toList(),
    ),
    languagePreference: $checkedConvert(
      'language_preference',
      (v) => $enumDecode(
        _$FinalizeOnboardingRequestRitualLanguagePreferenceEnumEnumMap,
        v,
        unknownValue: FinalizeOnboardingRequestRitualLanguagePreferenceEnum
            .unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
}, fieldKeyMap: const {'languagePreference': 'language_preference'});

Map<String, dynamic> _$FinalizeOnboardingRequestRitualToJson(
  FinalizeOnboardingRequestRitual instance,
) => <String, dynamic>{
  'familiarity':
      _$FinalizeOnboardingRequestRitualFamiliarityEnumEnumMap[instance
          .familiarity]!,
  'interests': instance.interests
      .map((e) => _$RitualInterestEnumMap[e]!)
      .toList(),
  'language_preference':
      _$FinalizeOnboardingRequestRitualLanguagePreferenceEnumEnumMap[instance
          .languagePreference]!,
};

const _$FinalizeOnboardingRequestRitualFamiliarityEnumEnumMap = {
  FinalizeOnboardingRequestRitualFamiliarityEnum.new_: 'new',
  FinalizeOnboardingRequestRitualFamiliarityEnum.curious: 'curious',
  FinalizeOnboardingRequestRitualFamiliarityEnum.familiar: 'familiar',
  FinalizeOnboardingRequestRitualFamiliarityEnum.practiced: 'practiced',
  FinalizeOnboardingRequestRitualFamiliarityEnum.preferNotToSay:
      'prefer_not_to_say',
  FinalizeOnboardingRequestRitualFamiliarityEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$RitualInterestEnumMap = {
  RitualInterest.practicalResearch: 'practical_research',
  RitualInterest.tarot: 'tarot',
  RitualInterest.astrology: 'astrology',
  RitualInterest.moonCycles: 'moon_cycles',
  RitualInterest.reflection: 'reflection',
  RitualInterest.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$FinalizeOnboardingRequestRitualLanguagePreferenceEnumEnumMap = {
  FinalizeOnboardingRequestRitualLanguagePreferenceEnum.practical: 'practical',
  FinalizeOnboardingRequestRitualLanguagePreferenceEnum.balanced: 'balanced',
  FinalizeOnboardingRequestRitualLanguagePreferenceEnum.mystical: 'mystical',
  FinalizeOnboardingRequestRitualLanguagePreferenceEnum.preferNotToSay:
      'prefer_not_to_say',
  FinalizeOnboardingRequestRitualLanguagePreferenceEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
