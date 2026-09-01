// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finalize_birthday_onboarding_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FinalizeBirthdayOnboardingRequestCWProxy {
  FinalizeBirthdayOnboardingRequest astrology(
    FinalizeBirthdayOnboardingRequestAstrology astrology,
  );

  FinalizeBirthdayOnboardingRequest consents(
    FinalizeBirthdayOnboardingRequestConsents consents,
  );

  FinalizeBirthdayOnboardingRequest expectedOnboardingVersion(
    int expectedOnboardingVersion,
  );

  FinalizeBirthdayOnboardingRequest schemaVersion(int schemaVersion);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FinalizeBirthdayOnboardingRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FinalizeBirthdayOnboardingRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  FinalizeBirthdayOnboardingRequest call({
    FinalizeBirthdayOnboardingRequestAstrology astrology,
    FinalizeBirthdayOnboardingRequestConsents consents,
    int expectedOnboardingVersion,
    int schemaVersion,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfFinalizeBirthdayOnboardingRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfFinalizeBirthdayOnboardingRequest.copyWith.fieldName(...)`
class _$FinalizeBirthdayOnboardingRequestCWProxyImpl
    implements _$FinalizeBirthdayOnboardingRequestCWProxy {
  const _$FinalizeBirthdayOnboardingRequestCWProxyImpl(this._value);

  final FinalizeBirthdayOnboardingRequest _value;

  @override
  FinalizeBirthdayOnboardingRequest astrology(
    FinalizeBirthdayOnboardingRequestAstrology astrology,
  ) => this(astrology: astrology);

  @override
  FinalizeBirthdayOnboardingRequest consents(
    FinalizeBirthdayOnboardingRequestConsents consents,
  ) => this(consents: consents);

  @override
  FinalizeBirthdayOnboardingRequest expectedOnboardingVersion(
    int expectedOnboardingVersion,
  ) => this(expectedOnboardingVersion: expectedOnboardingVersion);

  @override
  FinalizeBirthdayOnboardingRequest schemaVersion(int schemaVersion) =>
      this(schemaVersion: schemaVersion);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FinalizeBirthdayOnboardingRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FinalizeBirthdayOnboardingRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  FinalizeBirthdayOnboardingRequest call({
    Object? astrology = const $CopyWithPlaceholder(),
    Object? consents = const $CopyWithPlaceholder(),
    Object? expectedOnboardingVersion = const $CopyWithPlaceholder(),
    Object? schemaVersion = const $CopyWithPlaceholder(),
  }) {
    return FinalizeBirthdayOnboardingRequest(
      astrology: astrology == const $CopyWithPlaceholder()
          ? _value.astrology
          // ignore: cast_nullable_to_non_nullable
          : astrology as FinalizeBirthdayOnboardingRequestAstrology,
      consents: consents == const $CopyWithPlaceholder()
          ? _value.consents
          // ignore: cast_nullable_to_non_nullable
          : consents as FinalizeBirthdayOnboardingRequestConsents,
      expectedOnboardingVersion:
          expectedOnboardingVersion == const $CopyWithPlaceholder()
          ? _value.expectedOnboardingVersion
          // ignore: cast_nullable_to_non_nullable
          : expectedOnboardingVersion as int,
      schemaVersion: schemaVersion == const $CopyWithPlaceholder()
          ? _value.schemaVersion
          // ignore: cast_nullable_to_non_nullable
          : schemaVersion as int,
    );
  }
}

extension $FinalizeBirthdayOnboardingRequestCopyWith
    on FinalizeBirthdayOnboardingRequest {
  /// Returns a callable class that can be used as follows: `instanceOfFinalizeBirthdayOnboardingRequest.copyWith(...)` or like so:`instanceOfFinalizeBirthdayOnboardingRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FinalizeBirthdayOnboardingRequestCWProxy get copyWith =>
      _$FinalizeBirthdayOnboardingRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FinalizeBirthdayOnboardingRequest _$FinalizeBirthdayOnboardingRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'FinalizeBirthdayOnboardingRequest',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'astrology',
        'consents',
        'expected_onboarding_version',
        'schema_version',
      ],
    );
    final val = FinalizeBirthdayOnboardingRequest(
      astrology: $checkedConvert(
        'astrology',
        (v) => FinalizeBirthdayOnboardingRequestAstrology.fromJson(
          v as Map<String, dynamic>,
        ),
      ),
      consents: $checkedConvert(
        'consents',
        (v) => FinalizeBirthdayOnboardingRequestConsents.fromJson(
          v as Map<String, dynamic>,
        ),
      ),
      expectedOnboardingVersion: $checkedConvert(
        'expected_onboarding_version',
        (v) => (v as num).toInt(),
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

Map<String, dynamic> _$FinalizeBirthdayOnboardingRequestToJson(
  FinalizeBirthdayOnboardingRequest instance,
) => <String, dynamic>{
  'astrology': instance.astrology.toJson(),
  'consents': instance.consents.toJson(),
  'expected_onboarding_version': instance.expectedOnboardingVersion,
  'schema_version': instance.schemaVersion,
};
