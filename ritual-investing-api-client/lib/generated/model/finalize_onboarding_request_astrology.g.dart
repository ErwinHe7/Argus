// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finalize_onboarding_request_astrology.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FinalizeOnboardingRequestAstrologyCWProxy {
  FinalizeOnboardingRequestAstrology birthDate(DateTime? birthDate);

  FinalizeOnboardingRequestAstrology enabled(bool enabled);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FinalizeOnboardingRequestAstrology(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FinalizeOnboardingRequestAstrology(...).copyWith(id: 12, name: "My name")
  /// ````
  FinalizeOnboardingRequestAstrology call({DateTime? birthDate, bool enabled});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfFinalizeOnboardingRequestAstrology.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfFinalizeOnboardingRequestAstrology.copyWith.fieldName(...)`
class _$FinalizeOnboardingRequestAstrologyCWProxyImpl
    implements _$FinalizeOnboardingRequestAstrologyCWProxy {
  const _$FinalizeOnboardingRequestAstrologyCWProxyImpl(this._value);

  final FinalizeOnboardingRequestAstrology _value;

  @override
  FinalizeOnboardingRequestAstrology birthDate(DateTime? birthDate) =>
      this(birthDate: birthDate);

  @override
  FinalizeOnboardingRequestAstrology enabled(bool enabled) =>
      this(enabled: enabled);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FinalizeOnboardingRequestAstrology(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FinalizeOnboardingRequestAstrology(...).copyWith(id: 12, name: "My name")
  /// ````
  FinalizeOnboardingRequestAstrology call({
    Object? birthDate = const $CopyWithPlaceholder(),
    Object? enabled = const $CopyWithPlaceholder(),
  }) {
    return FinalizeOnboardingRequestAstrology(
      birthDate: birthDate == const $CopyWithPlaceholder()
          ? _value.birthDate
          // ignore: cast_nullable_to_non_nullable
          : birthDate as DateTime?,
      enabled: enabled == const $CopyWithPlaceholder()
          ? _value.enabled
          // ignore: cast_nullable_to_non_nullable
          : enabled as bool,
    );
  }
}

extension $FinalizeOnboardingRequestAstrologyCopyWith
    on FinalizeOnboardingRequestAstrology {
  /// Returns a callable class that can be used as follows: `instanceOfFinalizeOnboardingRequestAstrology.copyWith(...)` or like so:`instanceOfFinalizeOnboardingRequestAstrology.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FinalizeOnboardingRequestAstrologyCWProxy get copyWith =>
      _$FinalizeOnboardingRequestAstrologyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FinalizeOnboardingRequestAstrology _$FinalizeOnboardingRequestAstrologyFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('FinalizeOnboardingRequestAstrology', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['enabled']);
  final val = FinalizeOnboardingRequestAstrology(
    birthDate: $checkedConvert(
      'birth_date',
      (v) => v == null ? null : DateTime.parse(v as String),
    ),
    enabled: $checkedConvert('enabled', (v) => v as bool),
  );
  return val;
}, fieldKeyMap: const {'birthDate': 'birth_date'});

Map<String, dynamic> _$FinalizeOnboardingRequestAstrologyToJson(
  FinalizeOnboardingRequestAstrology instance,
) => <String, dynamic>{
  'birth_date': ?instance.birthDate?.toIso8601String(),
  'enabled': instance.enabled,
};
