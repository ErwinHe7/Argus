// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'astrology_profile.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AstrologyProfileCWProxy {
  AstrologyProfile algorithmVersion(
    AstrologyProfileAlgorithmVersionEnum algorithmVersion,
  );

  AstrologyProfile birthDate(DateTime birthDate);

  AstrologyProfile derivedProfileCode(
    AstrologyProfileDerivedProfileCodeEnum derivedProfileCode,
  );

  AstrologyProfile enabledAt(DateTime enabledAt);

  AstrologyProfile version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AstrologyProfile(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AstrologyProfile(...).copyWith(id: 12, name: "My name")
  /// ````
  AstrologyProfile call({
    AstrologyProfileAlgorithmVersionEnum algorithmVersion,
    DateTime birthDate,
    AstrologyProfileDerivedProfileCodeEnum derivedProfileCode,
    DateTime enabledAt,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAstrologyProfile.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAstrologyProfile.copyWith.fieldName(...)`
class _$AstrologyProfileCWProxyImpl implements _$AstrologyProfileCWProxy {
  const _$AstrologyProfileCWProxyImpl(this._value);

  final AstrologyProfile _value;

  @override
  AstrologyProfile algorithmVersion(
    AstrologyProfileAlgorithmVersionEnum algorithmVersion,
  ) => this(algorithmVersion: algorithmVersion);

  @override
  AstrologyProfile birthDate(DateTime birthDate) => this(birthDate: birthDate);

  @override
  AstrologyProfile derivedProfileCode(
    AstrologyProfileDerivedProfileCodeEnum derivedProfileCode,
  ) => this(derivedProfileCode: derivedProfileCode);

  @override
  AstrologyProfile enabledAt(DateTime enabledAt) => this(enabledAt: enabledAt);

  @override
  AstrologyProfile version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AstrologyProfile(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AstrologyProfile(...).copyWith(id: 12, name: "My name")
  /// ````
  AstrologyProfile call({
    Object? algorithmVersion = const $CopyWithPlaceholder(),
    Object? birthDate = const $CopyWithPlaceholder(),
    Object? derivedProfileCode = const $CopyWithPlaceholder(),
    Object? enabledAt = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return AstrologyProfile(
      algorithmVersion: algorithmVersion == const $CopyWithPlaceholder()
          ? _value.algorithmVersion
          // ignore: cast_nullable_to_non_nullable
          : algorithmVersion as AstrologyProfileAlgorithmVersionEnum,
      birthDate: birthDate == const $CopyWithPlaceholder()
          ? _value.birthDate
          // ignore: cast_nullable_to_non_nullable
          : birthDate as DateTime,
      derivedProfileCode: derivedProfileCode == const $CopyWithPlaceholder()
          ? _value.derivedProfileCode
          // ignore: cast_nullable_to_non_nullable
          : derivedProfileCode as AstrologyProfileDerivedProfileCodeEnum,
      enabledAt: enabledAt == const $CopyWithPlaceholder()
          ? _value.enabledAt
          // ignore: cast_nullable_to_non_nullable
          : enabledAt as DateTime,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $AstrologyProfileCopyWith on AstrologyProfile {
  /// Returns a callable class that can be used as follows: `instanceOfAstrologyProfile.copyWith(...)` or like so:`instanceOfAstrologyProfile.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AstrologyProfileCWProxy get copyWith => _$AstrologyProfileCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AstrologyProfile _$AstrologyProfileFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'AstrologyProfile',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'algorithm_version',
            'birth_date',
            'derived_profile_code',
            'enabled_at',
            'version',
          ],
        );
        final val = AstrologyProfile(
          algorithmVersion: $checkedConvert(
            'algorithm_version',
            (v) => $enumDecode(
              _$AstrologyProfileAlgorithmVersionEnumEnumMap,
              v,
              unknownValue:
                  AstrologyProfileAlgorithmVersionEnum.unknownDefaultOpenApi,
            ),
          ),
          birthDate: $checkedConvert(
            'birth_date',
            (v) => DateTime.parse(v as String),
          ),
          derivedProfileCode: $checkedConvert(
            'derived_profile_code',
            (v) => $enumDecode(
              _$AstrologyProfileDerivedProfileCodeEnumEnumMap,
              v,
              unknownValue:
                  AstrologyProfileDerivedProfileCodeEnum.unknownDefaultOpenApi,
            ),
          ),
          enabledAt: $checkedConvert(
            'enabled_at',
            (v) => DateTime.parse(v as String),
          ),
          version: $checkedConvert('version', (v) => (v as num).toInt()),
        );
        return val;
      },
      fieldKeyMap: const {
        'algorithmVersion': 'algorithm_version',
        'birthDate': 'birth_date',
        'derivedProfileCode': 'derived_profile_code',
        'enabledAt': 'enabled_at',
      },
    );

Map<String, dynamic> _$AstrologyProfileToJson(
  AstrologyProfile instance,
) => <String, dynamic>{
  'algorithm_version':
      _$AstrologyProfileAlgorithmVersionEnumEnumMap[instance.algorithmVersion]!,
  'birth_date': instance.birthDate.toIso8601String(),
  'derived_profile_code':
      _$AstrologyProfileDerivedProfileCodeEnumEnumMap[instance
          .derivedProfileCode]!,
  'enabled_at': instance.enabledAt.toIso8601String(),
  'version': instance.version,
};

const _$AstrologyProfileAlgorithmVersionEnumEnumMap = {
  AstrologyProfileAlgorithmVersionEnum.v1: 'v1',
  AstrologyProfileAlgorithmVersionEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$AstrologyProfileDerivedProfileCodeEnumEnumMap = {
  AstrologyProfileDerivedProfileCodeEnum.lunarPatient: 'lunar_patient',
  AstrologyProfileDerivedProfileCodeEnum.solarBuilder: 'solar_builder',
  AstrologyProfileDerivedProfileCodeEnum.risingExplorer: 'rising_explorer',
  AstrologyProfileDerivedProfileCodeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
