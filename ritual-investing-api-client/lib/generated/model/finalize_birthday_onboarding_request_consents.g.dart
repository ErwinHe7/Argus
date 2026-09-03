// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finalize_birthday_onboarding_request_consents.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FinalizeBirthdayOnboardingRequestConsentsCWProxy {
  FinalizeBirthdayOnboardingRequestConsents astrology(
    BirthdayAcceptedOnboardingConsent astrology,
  );

  FinalizeBirthdayOnboardingRequestConsents demoDisclosure(
    BirthdayAcceptedOnboardingConsent demoDisclosure,
  );

  FinalizeBirthdayOnboardingRequestConsents privacy(
    BirthdayAcceptedOnboardingConsent privacy,
  );

  FinalizeBirthdayOnboardingRequestConsents terms(
    BirthdayAcceptedOnboardingConsent terms,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FinalizeBirthdayOnboardingRequestConsents(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FinalizeBirthdayOnboardingRequestConsents(...).copyWith(id: 12, name: "My name")
  /// ````
  FinalizeBirthdayOnboardingRequestConsents call({
    BirthdayAcceptedOnboardingConsent astrology,
    BirthdayAcceptedOnboardingConsent demoDisclosure,
    BirthdayAcceptedOnboardingConsent privacy,
    BirthdayAcceptedOnboardingConsent terms,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfFinalizeBirthdayOnboardingRequestConsents.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfFinalizeBirthdayOnboardingRequestConsents.copyWith.fieldName(...)`
class _$FinalizeBirthdayOnboardingRequestConsentsCWProxyImpl
    implements _$FinalizeBirthdayOnboardingRequestConsentsCWProxy {
  const _$FinalizeBirthdayOnboardingRequestConsentsCWProxyImpl(this._value);

  final FinalizeBirthdayOnboardingRequestConsents _value;

  @override
  FinalizeBirthdayOnboardingRequestConsents astrology(
    BirthdayAcceptedOnboardingConsent astrology,
  ) => this(astrology: astrology);

  @override
  FinalizeBirthdayOnboardingRequestConsents demoDisclosure(
    BirthdayAcceptedOnboardingConsent demoDisclosure,
  ) => this(demoDisclosure: demoDisclosure);

  @override
  FinalizeBirthdayOnboardingRequestConsents privacy(
    BirthdayAcceptedOnboardingConsent privacy,
  ) => this(privacy: privacy);

  @override
  FinalizeBirthdayOnboardingRequestConsents terms(
    BirthdayAcceptedOnboardingConsent terms,
  ) => this(terms: terms);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FinalizeBirthdayOnboardingRequestConsents(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FinalizeBirthdayOnboardingRequestConsents(...).copyWith(id: 12, name: "My name")
  /// ````
  FinalizeBirthdayOnboardingRequestConsents call({
    Object? astrology = const $CopyWithPlaceholder(),
    Object? demoDisclosure = const $CopyWithPlaceholder(),
    Object? privacy = const $CopyWithPlaceholder(),
    Object? terms = const $CopyWithPlaceholder(),
  }) {
    return FinalizeBirthdayOnboardingRequestConsents(
      astrology: astrology == const $CopyWithPlaceholder()
          ? _value.astrology
          // ignore: cast_nullable_to_non_nullable
          : astrology as BirthdayAcceptedOnboardingConsent,
      demoDisclosure: demoDisclosure == const $CopyWithPlaceholder()
          ? _value.demoDisclosure
          // ignore: cast_nullable_to_non_nullable
          : demoDisclosure as BirthdayAcceptedOnboardingConsent,
      privacy: privacy == const $CopyWithPlaceholder()
          ? _value.privacy
          // ignore: cast_nullable_to_non_nullable
          : privacy as BirthdayAcceptedOnboardingConsent,
      terms: terms == const $CopyWithPlaceholder()
          ? _value.terms
          // ignore: cast_nullable_to_non_nullable
          : terms as BirthdayAcceptedOnboardingConsent,
    );
  }
}

extension $FinalizeBirthdayOnboardingRequestConsentsCopyWith
    on FinalizeBirthdayOnboardingRequestConsents {
  /// Returns a callable class that can be used as follows: `instanceOfFinalizeBirthdayOnboardingRequestConsents.copyWith(...)` or like so:`instanceOfFinalizeBirthdayOnboardingRequestConsents.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FinalizeBirthdayOnboardingRequestConsentsCWProxy get copyWith =>
      _$FinalizeBirthdayOnboardingRequestConsentsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FinalizeBirthdayOnboardingRequestConsents
_$FinalizeBirthdayOnboardingRequestConsentsFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('FinalizeBirthdayOnboardingRequestConsents', json, (
  $checkedConvert,
) {
  $checkKeys(
    json,
    requiredKeys: const ['astrology', 'demo_disclosure', 'privacy', 'terms'],
  );
  final val = FinalizeBirthdayOnboardingRequestConsents(
    astrology: $checkedConvert(
      'astrology',
      (v) =>
          BirthdayAcceptedOnboardingConsent.fromJson(v as Map<String, dynamic>),
    ),
    demoDisclosure: $checkedConvert(
      'demo_disclosure',
      (v) =>
          BirthdayAcceptedOnboardingConsent.fromJson(v as Map<String, dynamic>),
    ),
    privacy: $checkedConvert(
      'privacy',
      (v) =>
          BirthdayAcceptedOnboardingConsent.fromJson(v as Map<String, dynamic>),
    ),
    terms: $checkedConvert(
      'terms',
      (v) =>
          BirthdayAcceptedOnboardingConsent.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
}, fieldKeyMap: const {'demoDisclosure': 'demo_disclosure'});

Map<String, dynamic> _$FinalizeBirthdayOnboardingRequestConsentsToJson(
  FinalizeBirthdayOnboardingRequestConsents instance,
) => <String, dynamic>{
  'astrology': instance.astrology.toJson(),
  'demo_disclosure': instance.demoDisclosure.toJson(),
  'privacy': instance.privacy.toJson(),
  'terms': instance.terms.toJson(),
};
