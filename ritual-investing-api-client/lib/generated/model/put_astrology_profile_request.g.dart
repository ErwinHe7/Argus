// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'put_astrology_profile_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PutAstrologyProfileRequestCWProxy {
  PutAstrologyProfileRequest algorithmVersion(
    PutAstrologyProfileRequestAlgorithmVersionEnum? algorithmVersion,
  );

  PutAstrologyProfileRequest birthDate(DateTime birthDate);

  PutAstrologyProfileRequest derivedProfileCode(
    PutAstrologyProfileRequestDerivedProfileCodeEnum? derivedProfileCode,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PutAstrologyProfileRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PutAstrologyProfileRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PutAstrologyProfileRequest call({
    PutAstrologyProfileRequestAlgorithmVersionEnum? algorithmVersion,
    DateTime birthDate,
    PutAstrologyProfileRequestDerivedProfileCodeEnum? derivedProfileCode,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPutAstrologyProfileRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPutAstrologyProfileRequest.copyWith.fieldName(...)`
class _$PutAstrologyProfileRequestCWProxyImpl
    implements _$PutAstrologyProfileRequestCWProxy {
  const _$PutAstrologyProfileRequestCWProxyImpl(this._value);

  final PutAstrologyProfileRequest _value;

  @override
  PutAstrologyProfileRequest algorithmVersion(
    PutAstrologyProfileRequestAlgorithmVersionEnum? algorithmVersion,
  ) => this(algorithmVersion: algorithmVersion);

  @override
  PutAstrologyProfileRequest birthDate(DateTime birthDate) =>
      this(birthDate: birthDate);

  @override
  PutAstrologyProfileRequest derivedProfileCode(
    PutAstrologyProfileRequestDerivedProfileCodeEnum? derivedProfileCode,
  ) => this(derivedProfileCode: derivedProfileCode);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PutAstrologyProfileRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PutAstrologyProfileRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PutAstrologyProfileRequest call({
    Object? algorithmVersion = const $CopyWithPlaceholder(),
    Object? birthDate = const $CopyWithPlaceholder(),
    Object? derivedProfileCode = const $CopyWithPlaceholder(),
  }) {
    return PutAstrologyProfileRequest(
      algorithmVersion: algorithmVersion == const $CopyWithPlaceholder()
          ? _value.algorithmVersion
          // ignore: cast_nullable_to_non_nullable
          : algorithmVersion as PutAstrologyProfileRequestAlgorithmVersionEnum?,
      birthDate: birthDate == const $CopyWithPlaceholder()
          ? _value.birthDate
          // ignore: cast_nullable_to_non_nullable
          : birthDate as DateTime,
      derivedProfileCode: derivedProfileCode == const $CopyWithPlaceholder()
          ? _value.derivedProfileCode
          // ignore: cast_nullable_to_non_nullable
          : derivedProfileCode
                as PutAstrologyProfileRequestDerivedProfileCodeEnum?,
    );
  }
}

extension $PutAstrologyProfileRequestCopyWith on PutAstrologyProfileRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPutAstrologyProfileRequest.copyWith(...)` or like so:`instanceOfPutAstrologyProfileRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PutAstrologyProfileRequestCWProxy get copyWith =>
      _$PutAstrologyProfileRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PutAstrologyProfileRequest _$PutAstrologyProfileRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'PutAstrologyProfileRequest',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['birth_date']);
    final val = PutAstrologyProfileRequest(
      algorithmVersion: $checkedConvert(
        'algorithm_version',
        (v) => $enumDecodeNullable(
          _$PutAstrologyProfileRequestAlgorithmVersionEnumEnumMap,
          v,
          unknownValue: PutAstrologyProfileRequestAlgorithmVersionEnum
              .unknownDefaultOpenApi,
        ),
      ),
      birthDate: $checkedConvert(
        'birth_date',
        (v) => DateTime.parse(v as String),
      ),
      derivedProfileCode: $checkedConvert(
        'derived_profile_code',
        (v) => $enumDecodeNullable(
          _$PutAstrologyProfileRequestDerivedProfileCodeEnumEnumMap,
          v,
          unknownValue: PutAstrologyProfileRequestDerivedProfileCodeEnum
              .unknownDefaultOpenApi,
        ),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'algorithmVersion': 'algorithm_version',
    'birthDate': 'birth_date',
    'derivedProfileCode': 'derived_profile_code',
  },
);

Map<String, dynamic> _$PutAstrologyProfileRequestToJson(
  PutAstrologyProfileRequest instance,
) => <String, dynamic>{
  'algorithm_version':
      ?_$PutAstrologyProfileRequestAlgorithmVersionEnumEnumMap[instance
          .algorithmVersion],
  'birth_date': instance.birthDate.toIso8601String(),
  'derived_profile_code':
      ?_$PutAstrologyProfileRequestDerivedProfileCodeEnumEnumMap[instance
          .derivedProfileCode],
};

const _$PutAstrologyProfileRequestAlgorithmVersionEnumEnumMap = {
  PutAstrologyProfileRequestAlgorithmVersionEnum.v1: 'v1',
  PutAstrologyProfileRequestAlgorithmVersionEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$PutAstrologyProfileRequestDerivedProfileCodeEnumEnumMap = {
  PutAstrologyProfileRequestDerivedProfileCodeEnum.lunarPatient:
      'lunar_patient',
  PutAstrologyProfileRequestDerivedProfileCodeEnum.solarBuilder:
      'solar_builder',
  PutAstrologyProfileRequestDerivedProfileCodeEnum.risingExplorer:
      'rising_explorer',
  PutAstrologyProfileRequestDerivedProfileCodeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
