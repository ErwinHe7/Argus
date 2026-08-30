// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'starpath_authority.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$StarpathAuthorityCWProxy {
  StarpathAuthority capabilityVersion(int capabilityVersion);

  StarpathAuthority environment(StarpathAuthorityEnvironmentEnum environment);

  StarpathAuthority jurisdiction(String jurisdiction);

  StarpathAuthority manifestId(String manifestId);

  StarpathAuthority manifestVersion(String manifestVersion);

  StarpathAuthority policyVersion(String policyVersion);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathAuthority(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathAuthority(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathAuthority call({
    int capabilityVersion,
    StarpathAuthorityEnvironmentEnum environment,
    String jurisdiction,
    String manifestId,
    String manifestVersion,
    String policyVersion,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfStarpathAuthority.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfStarpathAuthority.copyWith.fieldName(...)`
class _$StarpathAuthorityCWProxyImpl implements _$StarpathAuthorityCWProxy {
  const _$StarpathAuthorityCWProxyImpl(this._value);

  final StarpathAuthority _value;

  @override
  StarpathAuthority capabilityVersion(int capabilityVersion) =>
      this(capabilityVersion: capabilityVersion);

  @override
  StarpathAuthority environment(StarpathAuthorityEnvironmentEnum environment) =>
      this(environment: environment);

  @override
  StarpathAuthority jurisdiction(String jurisdiction) =>
      this(jurisdiction: jurisdiction);

  @override
  StarpathAuthority manifestId(String manifestId) =>
      this(manifestId: manifestId);

  @override
  StarpathAuthority manifestVersion(String manifestVersion) =>
      this(manifestVersion: manifestVersion);

  @override
  StarpathAuthority policyVersion(String policyVersion) =>
      this(policyVersion: policyVersion);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathAuthority(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathAuthority(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathAuthority call({
    Object? capabilityVersion = const $CopyWithPlaceholder(),
    Object? environment = const $CopyWithPlaceholder(),
    Object? jurisdiction = const $CopyWithPlaceholder(),
    Object? manifestId = const $CopyWithPlaceholder(),
    Object? manifestVersion = const $CopyWithPlaceholder(),
    Object? policyVersion = const $CopyWithPlaceholder(),
  }) {
    return StarpathAuthority(
      capabilityVersion: capabilityVersion == const $CopyWithPlaceholder()
          ? _value.capabilityVersion
          // ignore: cast_nullable_to_non_nullable
          : capabilityVersion as int,
      environment: environment == const $CopyWithPlaceholder()
          ? _value.environment
          // ignore: cast_nullable_to_non_nullable
          : environment as StarpathAuthorityEnvironmentEnum,
      jurisdiction: jurisdiction == const $CopyWithPlaceholder()
          ? _value.jurisdiction
          // ignore: cast_nullable_to_non_nullable
          : jurisdiction as String,
      manifestId: manifestId == const $CopyWithPlaceholder()
          ? _value.manifestId
          // ignore: cast_nullable_to_non_nullable
          : manifestId as String,
      manifestVersion: manifestVersion == const $CopyWithPlaceholder()
          ? _value.manifestVersion
          // ignore: cast_nullable_to_non_nullable
          : manifestVersion as String,
      policyVersion: policyVersion == const $CopyWithPlaceholder()
          ? _value.policyVersion
          // ignore: cast_nullable_to_non_nullable
          : policyVersion as String,
    );
  }
}

extension $StarpathAuthorityCopyWith on StarpathAuthority {
  /// Returns a callable class that can be used as follows: `instanceOfStarpathAuthority.copyWith(...)` or like so:`instanceOfStarpathAuthority.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$StarpathAuthorityCWProxy get copyWith =>
      _$StarpathAuthorityCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StarpathAuthority _$StarpathAuthorityFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'StarpathAuthority',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'capability_version',
        'environment',
        'jurisdiction',
        'manifest_id',
        'manifest_version',
        'policy_version',
      ],
    );
    final val = StarpathAuthority(
      capabilityVersion: $checkedConvert(
        'capability_version',
        (v) => (v as num).toInt(),
      ),
      environment: $checkedConvert(
        'environment',
        (v) => $enumDecode(
          _$StarpathAuthorityEnvironmentEnumEnumMap,
          v,
          unknownValue: StarpathAuthorityEnvironmentEnum.unknownDefaultOpenApi,
        ),
      ),
      jurisdiction: $checkedConvert('jurisdiction', (v) => v as String),
      manifestId: $checkedConvert('manifest_id', (v) => v as String),
      manifestVersion: $checkedConvert('manifest_version', (v) => v as String),
      policyVersion: $checkedConvert('policy_version', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'capabilityVersion': 'capability_version',
    'manifestId': 'manifest_id',
    'manifestVersion': 'manifest_version',
    'policyVersion': 'policy_version',
  },
);

Map<String, dynamic> _$StarpathAuthorityToJson(StarpathAuthority instance) =>
    <String, dynamic>{
      'capability_version': instance.capabilityVersion,
      'environment':
          _$StarpathAuthorityEnvironmentEnumEnumMap[instance.environment]!,
      'jurisdiction': instance.jurisdiction,
      'manifest_id': instance.manifestId,
      'manifest_version': instance.manifestVersion,
      'policy_version': instance.policyVersion,
    };

const _$StarpathAuthorityEnvironmentEnumEnumMap = {
  StarpathAuthorityEnvironmentEnum.beta: 'beta',
  StarpathAuthorityEnvironmentEnum.production: 'production',
  StarpathAuthorityEnvironmentEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
