// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_bootstrap_astrology_profile.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SessionBootstrapAstrologyProfileCWProxy {
  SessionBootstrapAstrologyProfile algorithmVersion(
    SessionBootstrapAstrologyProfileAlgorithmVersionEnum algorithmVersion,
  );

  SessionBootstrapAstrologyProfile birthDate(DateTime birthDate);

  SessionBootstrapAstrologyProfile derivedProfileCode(
    SessionBootstrapAstrologyProfileDerivedProfileCodeEnum derivedProfileCode,
  );

  SessionBootstrapAstrologyProfile enabledAt(DateTime enabledAt);

  SessionBootstrapAstrologyProfile version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionBootstrapAstrologyProfile(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionBootstrapAstrologyProfile(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionBootstrapAstrologyProfile call({
    SessionBootstrapAstrologyProfileAlgorithmVersionEnum algorithmVersion,
    DateTime birthDate,
    SessionBootstrapAstrologyProfileDerivedProfileCodeEnum derivedProfileCode,
    DateTime enabledAt,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSessionBootstrapAstrologyProfile.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSessionBootstrapAstrologyProfile.copyWith.fieldName(...)`
class _$SessionBootstrapAstrologyProfileCWProxyImpl
    implements _$SessionBootstrapAstrologyProfileCWProxy {
  const _$SessionBootstrapAstrologyProfileCWProxyImpl(this._value);

  final SessionBootstrapAstrologyProfile _value;

  @override
  SessionBootstrapAstrologyProfile algorithmVersion(
    SessionBootstrapAstrologyProfileAlgorithmVersionEnum algorithmVersion,
  ) => this(algorithmVersion: algorithmVersion);

  @override
  SessionBootstrapAstrologyProfile birthDate(DateTime birthDate) =>
      this(birthDate: birthDate);

  @override
  SessionBootstrapAstrologyProfile derivedProfileCode(
    SessionBootstrapAstrologyProfileDerivedProfileCodeEnum derivedProfileCode,
  ) => this(derivedProfileCode: derivedProfileCode);

  @override
  SessionBootstrapAstrologyProfile enabledAt(DateTime enabledAt) =>
      this(enabledAt: enabledAt);

  @override
  SessionBootstrapAstrologyProfile version(int version) =>
      this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionBootstrapAstrologyProfile(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionBootstrapAstrologyProfile(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionBootstrapAstrologyProfile call({
    Object? algorithmVersion = const $CopyWithPlaceholder(),
    Object? birthDate = const $CopyWithPlaceholder(),
    Object? derivedProfileCode = const $CopyWithPlaceholder(),
    Object? enabledAt = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return SessionBootstrapAstrologyProfile(
      algorithmVersion: algorithmVersion == const $CopyWithPlaceholder()
          ? _value.algorithmVersion
          // ignore: cast_nullable_to_non_nullable
          : algorithmVersion
                as SessionBootstrapAstrologyProfileAlgorithmVersionEnum,
      birthDate: birthDate == const $CopyWithPlaceholder()
          ? _value.birthDate
          // ignore: cast_nullable_to_non_nullable
          : birthDate as DateTime,
      derivedProfileCode: derivedProfileCode == const $CopyWithPlaceholder()
          ? _value.derivedProfileCode
          // ignore: cast_nullable_to_non_nullable
          : derivedProfileCode
                as SessionBootstrapAstrologyProfileDerivedProfileCodeEnum,
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

extension $SessionBootstrapAstrologyProfileCopyWith
    on SessionBootstrapAstrologyProfile {
  /// Returns a callable class that can be used as follows: `instanceOfSessionBootstrapAstrologyProfile.copyWith(...)` or like so:`instanceOfSessionBootstrapAstrologyProfile.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SessionBootstrapAstrologyProfileCWProxy get copyWith =>
      _$SessionBootstrapAstrologyProfileCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionBootstrapAstrologyProfile _$SessionBootstrapAstrologyProfileFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'SessionBootstrapAstrologyProfile',
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
    final val = SessionBootstrapAstrologyProfile(
      algorithmVersion: $checkedConvert(
        'algorithm_version',
        (v) => $enumDecode(
          _$SessionBootstrapAstrologyProfileAlgorithmVersionEnumEnumMap,
          v,
          unknownValue: SessionBootstrapAstrologyProfileAlgorithmVersionEnum
              .unknownDefaultOpenApi,
        ),
      ),
      birthDate: $checkedConvert(
        'birth_date',
        (v) => DateTime.parse(v as String),
      ),
      derivedProfileCode: $checkedConvert(
        'derived_profile_code',
        (v) => $enumDecode(
          _$SessionBootstrapAstrologyProfileDerivedProfileCodeEnumEnumMap,
          v,
          unknownValue: SessionBootstrapAstrologyProfileDerivedProfileCodeEnum
              .unknownDefaultOpenApi,
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

Map<String, dynamic> _$SessionBootstrapAstrologyProfileToJson(
  SessionBootstrapAstrologyProfile instance,
) => <String, dynamic>{
  'algorithm_version':
      _$SessionBootstrapAstrologyProfileAlgorithmVersionEnumEnumMap[instance
          .algorithmVersion]!,
  'birth_date': instance.birthDate.toIso8601String(),
  'derived_profile_code':
      _$SessionBootstrapAstrologyProfileDerivedProfileCodeEnumEnumMap[instance
          .derivedProfileCode]!,
  'enabled_at': instance.enabledAt.toIso8601String(),
  'version': instance.version,
};

const _$SessionBootstrapAstrologyProfileAlgorithmVersionEnumEnumMap = {
  SessionBootstrapAstrologyProfileAlgorithmVersionEnum.v1: 'v1',
  SessionBootstrapAstrologyProfileAlgorithmVersionEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$SessionBootstrapAstrologyProfileDerivedProfileCodeEnumEnumMap = {
  SessionBootstrapAstrologyProfileDerivedProfileCodeEnum.lunarPatient:
      'lunar_patient',
  SessionBootstrapAstrologyProfileDerivedProfileCodeEnum.solarBuilder:
      'solar_builder',
  SessionBootstrapAstrologyProfileDerivedProfileCodeEnum.risingExplorer:
      'rising_explorer',
  SessionBootstrapAstrologyProfileDerivedProfileCodeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
