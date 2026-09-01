// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finalize_birthday_onboarding_request_astrology.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FinalizeBirthdayOnboardingRequestAstrologyCWProxy {
  FinalizeBirthdayOnboardingRequestAstrology birthDate(DateTime birthDate);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FinalizeBirthdayOnboardingRequestAstrology(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FinalizeBirthdayOnboardingRequestAstrology(...).copyWith(id: 12, name: "My name")
  /// ````
  FinalizeBirthdayOnboardingRequestAstrology call({DateTime birthDate});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfFinalizeBirthdayOnboardingRequestAstrology.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfFinalizeBirthdayOnboardingRequestAstrology.copyWith.fieldName(...)`
class _$FinalizeBirthdayOnboardingRequestAstrologyCWProxyImpl
    implements _$FinalizeBirthdayOnboardingRequestAstrologyCWProxy {
  const _$FinalizeBirthdayOnboardingRequestAstrologyCWProxyImpl(this._value);

  final FinalizeBirthdayOnboardingRequestAstrology _value;

  @override
  FinalizeBirthdayOnboardingRequestAstrology birthDate(DateTime birthDate) =>
      this(birthDate: birthDate);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FinalizeBirthdayOnboardingRequestAstrology(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FinalizeBirthdayOnboardingRequestAstrology(...).copyWith(id: 12, name: "My name")
  /// ````
  FinalizeBirthdayOnboardingRequestAstrology call({
    Object? birthDate = const $CopyWithPlaceholder(),
  }) {
    return FinalizeBirthdayOnboardingRequestAstrology(
      birthDate: birthDate == const $CopyWithPlaceholder()
          ? _value.birthDate
          // ignore: cast_nullable_to_non_nullable
          : birthDate as DateTime,
    );
  }
}

extension $FinalizeBirthdayOnboardingRequestAstrologyCopyWith
    on FinalizeBirthdayOnboardingRequestAstrology {
  /// Returns a callable class that can be used as follows: `instanceOfFinalizeBirthdayOnboardingRequestAstrology.copyWith(...)` or like so:`instanceOfFinalizeBirthdayOnboardingRequestAstrology.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FinalizeBirthdayOnboardingRequestAstrologyCWProxy get copyWith =>
      _$FinalizeBirthdayOnboardingRequestAstrologyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FinalizeBirthdayOnboardingRequestAstrology
_$FinalizeBirthdayOnboardingRequestAstrologyFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('FinalizeBirthdayOnboardingRequestAstrology', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['birth_date']);
  final val = FinalizeBirthdayOnboardingRequestAstrology(
    birthDate: $checkedConvert(
      'birth_date',
      (v) => DateTime.parse(v as String),
    ),
  );
  return val;
}, fieldKeyMap: const {'birthDate': 'birth_date'});

Map<String, dynamic> _$FinalizeBirthdayOnboardingRequestAstrologyToJson(
  FinalizeBirthdayOnboardingRequestAstrology instance,
) => <String, dynamic>{'birth_date': instance.birthDate.toIso8601String()};
