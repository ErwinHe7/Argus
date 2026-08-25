// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finalize_onboarding_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FinalizeOnboardingRequestCWProxy {
  FinalizeOnboardingRequest astrology(
    FinalizeOnboardingRequestAstrology astrology,
  );

  FinalizeOnboardingRequest consents(
    FinalizeOnboardingRequestConsents consents,
  );

  FinalizeOnboardingRequest expectedOnboardingVersion(
    int expectedOnboardingVersion,
  );

  FinalizeOnboardingRequest investing(
    FinalizeOnboardingRequestInvesting investing,
  );

  FinalizeOnboardingRequest ritual(FinalizeOnboardingRequestRitual ritual);

  FinalizeOnboardingRequest schemaVersion(int schemaVersion);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FinalizeOnboardingRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FinalizeOnboardingRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  FinalizeOnboardingRequest call({
    FinalizeOnboardingRequestAstrology astrology,
    FinalizeOnboardingRequestConsents consents,
    int expectedOnboardingVersion,
    FinalizeOnboardingRequestInvesting investing,
    FinalizeOnboardingRequestRitual ritual,
    int schemaVersion,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfFinalizeOnboardingRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfFinalizeOnboardingRequest.copyWith.fieldName(...)`
class _$FinalizeOnboardingRequestCWProxyImpl
    implements _$FinalizeOnboardingRequestCWProxy {
  const _$FinalizeOnboardingRequestCWProxyImpl(this._value);

  final FinalizeOnboardingRequest _value;

  @override
  FinalizeOnboardingRequest astrology(
    FinalizeOnboardingRequestAstrology astrology,
  ) => this(astrology: astrology);

  @override
  FinalizeOnboardingRequest consents(
    FinalizeOnboardingRequestConsents consents,
  ) => this(consents: consents);

  @override
  FinalizeOnboardingRequest expectedOnboardingVersion(
    int expectedOnboardingVersion,
  ) => this(expectedOnboardingVersion: expectedOnboardingVersion);

  @override
  FinalizeOnboardingRequest investing(
    FinalizeOnboardingRequestInvesting investing,
  ) => this(investing: investing);

  @override
  FinalizeOnboardingRequest ritual(FinalizeOnboardingRequestRitual ritual) =>
      this(ritual: ritual);

  @override
  FinalizeOnboardingRequest schemaVersion(int schemaVersion) =>
      this(schemaVersion: schemaVersion);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FinalizeOnboardingRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FinalizeOnboardingRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  FinalizeOnboardingRequest call({
    Object? astrology = const $CopyWithPlaceholder(),
    Object? consents = const $CopyWithPlaceholder(),
    Object? expectedOnboardingVersion = const $CopyWithPlaceholder(),
    Object? investing = const $CopyWithPlaceholder(),
    Object? ritual = const $CopyWithPlaceholder(),
    Object? schemaVersion = const $CopyWithPlaceholder(),
  }) {
    return FinalizeOnboardingRequest(
      astrology: astrology == const $CopyWithPlaceholder()
          ? _value.astrology
          // ignore: cast_nullable_to_non_nullable
          : astrology as FinalizeOnboardingRequestAstrology,
      consents: consents == const $CopyWithPlaceholder()
          ? _value.consents
          // ignore: cast_nullable_to_non_nullable
          : consents as FinalizeOnboardingRequestConsents,
      expectedOnboardingVersion:
          expectedOnboardingVersion == const $CopyWithPlaceholder()
          ? _value.expectedOnboardingVersion
          // ignore: cast_nullable_to_non_nullable
          : expectedOnboardingVersion as int,
      investing: investing == const $CopyWithPlaceholder()
          ? _value.investing
          // ignore: cast_nullable_to_non_nullable
          : investing as FinalizeOnboardingRequestInvesting,
      ritual: ritual == const $CopyWithPlaceholder()
          ? _value.ritual
          // ignore: cast_nullable_to_non_nullable
          : ritual as FinalizeOnboardingRequestRitual,
      schemaVersion: schemaVersion == const $CopyWithPlaceholder()
          ? _value.schemaVersion
          // ignore: cast_nullable_to_non_nullable
          : schemaVersion as int,
    );
  }
}

extension $FinalizeOnboardingRequestCopyWith on FinalizeOnboardingRequest {
  /// Returns a callable class that can be used as follows: `instanceOfFinalizeOnboardingRequest.copyWith(...)` or like so:`instanceOfFinalizeOnboardingRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FinalizeOnboardingRequestCWProxy get copyWith =>
      _$FinalizeOnboardingRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FinalizeOnboardingRequest _$FinalizeOnboardingRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'FinalizeOnboardingRequest',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'astrology',
        'consents',
        'expected_onboarding_version',
        'investing',
        'ritual',
        'schema_version',
      ],
    );
    final val = FinalizeOnboardingRequest(
      astrology: $checkedConvert(
        'astrology',
        (v) => FinalizeOnboardingRequestAstrology.fromJson(
          v as Map<String, dynamic>,
        ),
      ),
      consents: $checkedConvert(
        'consents',
        (v) => FinalizeOnboardingRequestConsents.fromJson(
          v as Map<String, dynamic>,
        ),
      ),
      expectedOnboardingVersion: $checkedConvert(
        'expected_onboarding_version',
        (v) => (v as num).toInt(),
      ),
      investing: $checkedConvert(
        'investing',
        (v) => FinalizeOnboardingRequestInvesting.fromJson(
          v as Map<String, dynamic>,
        ),
      ),
      ritual: $checkedConvert(
        'ritual',
        (v) =>
            FinalizeOnboardingRequestRitual.fromJson(v as Map<String, dynamic>),
      ),
      schemaVersion: $checkedConvert(
        'schema_version',
        (v) => (v as num).toInt(),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'expectedOnboardingVersion': 'expected_onboarding_version',
    'schemaVersion': 'schema_version',
  },
);

Map<String, dynamic> _$FinalizeOnboardingRequestToJson(
  FinalizeOnboardingRequest instance,
) => <String, dynamic>{
  'astrology': instance.astrology.toJson(),
  'consents': instance.consents.toJson(),
  'expected_onboarding_version': instance.expectedOnboardingVersion,
  'investing': instance.investing.toJson(),
  'ritual': instance.ritual.toJson(),
  'schema_version': instance.schemaVersion,
};
