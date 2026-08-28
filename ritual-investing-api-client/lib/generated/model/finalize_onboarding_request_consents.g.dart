// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finalize_onboarding_request_consents.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FinalizeOnboardingRequestConsentsCWProxy {
  FinalizeOnboardingRequestConsents astrology(
    FinalizeOnboardingRequestConsentsAstrology astrology,
  );

  FinalizeOnboardingRequestConsents demoDisclosure(
    FinalizeOnboardingRequestConsentsDemoDisclosure demoDisclosure,
  );

  FinalizeOnboardingRequestConsents privacy(
    FinalizeOnboardingRequestConsentsDemoDisclosure privacy,
  );

  FinalizeOnboardingRequestConsents terms(
    FinalizeOnboardingRequestConsentsDemoDisclosure terms,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FinalizeOnboardingRequestConsents(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FinalizeOnboardingRequestConsents(...).copyWith(id: 12, name: "My name")
  /// ````
  FinalizeOnboardingRequestConsents call({
    FinalizeOnboardingRequestConsentsAstrology astrology,
    FinalizeOnboardingRequestConsentsDemoDisclosure demoDisclosure,
    FinalizeOnboardingRequestConsentsDemoDisclosure privacy,
    FinalizeOnboardingRequestConsentsDemoDisclosure terms,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfFinalizeOnboardingRequestConsents.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfFinalizeOnboardingRequestConsents.copyWith.fieldName(...)`
class _$FinalizeOnboardingRequestConsentsCWProxyImpl
    implements _$FinalizeOnboardingRequestConsentsCWProxy {
  const _$FinalizeOnboardingRequestConsentsCWProxyImpl(this._value);

  final FinalizeOnboardingRequestConsents _value;

  @override
  FinalizeOnboardingRequestConsents astrology(
    FinalizeOnboardingRequestConsentsAstrology astrology,
  ) => this(astrology: astrology);

  @override
  FinalizeOnboardingRequestConsents demoDisclosure(
    FinalizeOnboardingRequestConsentsDemoDisclosure demoDisclosure,
  ) => this(demoDisclosure: demoDisclosure);

  @override
  FinalizeOnboardingRequestConsents privacy(
    FinalizeOnboardingRequestConsentsDemoDisclosure privacy,
  ) => this(privacy: privacy);

  @override
  FinalizeOnboardingRequestConsents terms(
    FinalizeOnboardingRequestConsentsDemoDisclosure terms,
  ) => this(terms: terms);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FinalizeOnboardingRequestConsents(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FinalizeOnboardingRequestConsents(...).copyWith(id: 12, name: "My name")
  /// ````
  FinalizeOnboardingRequestConsents call({
    Object? astrology = const $CopyWithPlaceholder(),
    Object? demoDisclosure = const $CopyWithPlaceholder(),
    Object? privacy = const $CopyWithPlaceholder(),
    Object? terms = const $CopyWithPlaceholder(),
  }) {
    return FinalizeOnboardingRequestConsents(
      astrology: astrology == const $CopyWithPlaceholder()
          ? _value.astrology
          // ignore: cast_nullable_to_non_nullable
          : astrology as FinalizeOnboardingRequestConsentsAstrology,
      demoDisclosure: demoDisclosure == const $CopyWithPlaceholder()
          ? _value.demoDisclosure
          // ignore: cast_nullable_to_non_nullable
          : demoDisclosure as FinalizeOnboardingRequestConsentsDemoDisclosure,
      privacy: privacy == const $CopyWithPlaceholder()
          ? _value.privacy
          // ignore: cast_nullable_to_non_nullable
          : privacy as FinalizeOnboardingRequestConsentsDemoDisclosure,
      terms: terms == const $CopyWithPlaceholder()
          ? _value.terms
          // ignore: cast_nullable_to_non_nullable
          : terms as FinalizeOnboardingRequestConsentsDemoDisclosure,
    );
  }
}

extension $FinalizeOnboardingRequestConsentsCopyWith
    on FinalizeOnboardingRequestConsents {
  /// Returns a callable class that can be used as follows: `instanceOfFinalizeOnboardingRequestConsents.copyWith(...)` or like so:`instanceOfFinalizeOnboardingRequestConsents.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FinalizeOnboardingRequestConsentsCWProxy get copyWith =>
      _$FinalizeOnboardingRequestConsentsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FinalizeOnboardingRequestConsents _$FinalizeOnboardingRequestConsentsFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('FinalizeOnboardingRequestConsents', json, (
  $checkedConvert,
) {
  $checkKeys(
    json,
    requiredKeys: const ['astrology', 'demo_disclosure', 'privacy', 'terms'],
  );
  final val = FinalizeOnboardingRequestConsents(
    astrology: $checkedConvert(
      'astrology',
      (v) => FinalizeOnboardingRequestConsentsAstrology.fromJson(
        v as Map<String, dynamic>,
      ),
    ),
    demoDisclosure: $checkedConvert(
      'demo_disclosure',
      (v) => FinalizeOnboardingRequestConsentsDemoDisclosure.fromJson(
        v as Map<String, dynamic>,
      ),
    ),
    privacy: $checkedConvert(
      'privacy',
      (v) => FinalizeOnboardingRequestConsentsDemoDisclosure.fromJson(
        v as Map<String, dynamic>,
      ),
    ),
    terms: $checkedConvert(
      'terms',
      (v) => FinalizeOnboardingRequestConsentsDemoDisclosure.fromJson(
        v as Map<String, dynamic>,
      ),
    ),
  );
  return val;
}, fieldKeyMap: const {'demoDisclosure': 'demo_disclosure'});

Map<String, dynamic> _$FinalizeOnboardingRequestConsentsToJson(
  FinalizeOnboardingRequestConsents instance,
) => <String, dynamic>{
  'astrology': instance.astrology.toJson(),
  'demo_disclosure': instance.demoDisclosure.toJson(),
  'privacy': instance.privacy.toJson(),
  'terms': instance.terms.toJson(),
};
