// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_branch_capabilities.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemberBranchCapabilitiesCWProxy {
  MemberBranchCapabilities branches(List<String> branches);

  MemberBranchCapabilities capabilityVersion(int capabilityVersion);

  MemberBranchCapabilities environment(
    MemberBranchCapabilitiesEnvironmentEnum environment,
  );

  MemberBranchCapabilities evaluatedAt(DateTime evaluatedAt);

  MemberBranchCapabilities expiresAt(DateTime expiresAt);

  MemberBranchCapabilities schemaVersion(
    MemberBranchCapabilitiesSchemaVersionEnum schemaVersion,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberBranchCapabilities(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberBranchCapabilities(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberBranchCapabilities call({
    List<String> branches,
    int capabilityVersion,
    MemberBranchCapabilitiesEnvironmentEnum environment,
    DateTime evaluatedAt,
    DateTime expiresAt,
    MemberBranchCapabilitiesSchemaVersionEnum schemaVersion,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemberBranchCapabilities.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemberBranchCapabilities.copyWith.fieldName(...)`
class _$MemberBranchCapabilitiesCWProxyImpl
    implements _$MemberBranchCapabilitiesCWProxy {
  const _$MemberBranchCapabilitiesCWProxyImpl(this._value);

  final MemberBranchCapabilities _value;

  @override
  MemberBranchCapabilities branches(List<String> branches) =>
      this(branches: branches);

  @override
  MemberBranchCapabilities capabilityVersion(int capabilityVersion) =>
      this(capabilityVersion: capabilityVersion);

  @override
  MemberBranchCapabilities environment(
    MemberBranchCapabilitiesEnvironmentEnum environment,
  ) => this(environment: environment);

  @override
  MemberBranchCapabilities evaluatedAt(DateTime evaluatedAt) =>
      this(evaluatedAt: evaluatedAt);

  @override
  MemberBranchCapabilities expiresAt(DateTime expiresAt) =>
      this(expiresAt: expiresAt);

  @override
  MemberBranchCapabilities schemaVersion(
    MemberBranchCapabilitiesSchemaVersionEnum schemaVersion,
  ) => this(schemaVersion: schemaVersion);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberBranchCapabilities(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberBranchCapabilities(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberBranchCapabilities call({
    Object? branches = const $CopyWithPlaceholder(),
    Object? capabilityVersion = const $CopyWithPlaceholder(),
    Object? environment = const $CopyWithPlaceholder(),
    Object? evaluatedAt = const $CopyWithPlaceholder(),
    Object? expiresAt = const $CopyWithPlaceholder(),
    Object? schemaVersion = const $CopyWithPlaceholder(),
  }) {
    return MemberBranchCapabilities(
      branches: branches == const $CopyWithPlaceholder()
          ? _value.branches
          // ignore: cast_nullable_to_non_nullable
          : branches as List<String>,
      capabilityVersion: capabilityVersion == const $CopyWithPlaceholder()
          ? _value.capabilityVersion
          // ignore: cast_nullable_to_non_nullable
          : capabilityVersion as int,
      environment: environment == const $CopyWithPlaceholder()
          ? _value.environment
          // ignore: cast_nullable_to_non_nullable
          : environment as MemberBranchCapabilitiesEnvironmentEnum,
      evaluatedAt: evaluatedAt == const $CopyWithPlaceholder()
          ? _value.evaluatedAt
          // ignore: cast_nullable_to_non_nullable
          : evaluatedAt as DateTime,
      expiresAt: expiresAt == const $CopyWithPlaceholder()
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime,
      schemaVersion: schemaVersion == const $CopyWithPlaceholder()
          ? _value.schemaVersion
          // ignore: cast_nullable_to_non_nullable
          : schemaVersion as MemberBranchCapabilitiesSchemaVersionEnum,
    );
  }
}

extension $MemberBranchCapabilitiesCopyWith on MemberBranchCapabilities {
  /// Returns a callable class that can be used as follows: `instanceOfMemberBranchCapabilities.copyWith(...)` or like so:`instanceOfMemberBranchCapabilities.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MemberBranchCapabilitiesCWProxy get copyWith =>
      _$MemberBranchCapabilitiesCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemberBranchCapabilities _$MemberBranchCapabilitiesFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'MemberBranchCapabilities',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'branches',
        'capability_version',
        'environment',
        'evaluated_at',
        'expires_at',
        'schema_version',
      ],
    );
    final val = MemberBranchCapabilities(
      branches: $checkedConvert(
        'branches',
        (v) => (v as List<dynamic>).map((e) => e as String).toList(),
      ),
      capabilityVersion: $checkedConvert(
        'capability_version',
        (v) => (v as num).toInt(),
      ),
      environment: $checkedConvert(
        'environment',
        (v) => $enumDecode(
          _$MemberBranchCapabilitiesEnvironmentEnumEnumMap,
          v,
          unknownValue:
              MemberBranchCapabilitiesEnvironmentEnum.unknownDefaultOpenApi,
        ),
      ),
      evaluatedAt: $checkedConvert(
        'evaluated_at',
        (v) => DateTime.parse(v as String),
      ),
      expiresAt: $checkedConvert(
        'expires_at',
        (v) => DateTime.parse(v as String),
      ),
      schemaVersion: $checkedConvert(
        'schema_version',
        (v) => $enumDecode(
          _$MemberBranchCapabilitiesSchemaVersionEnumEnumMap,
          v,
          unknownValue:
              MemberBranchCapabilitiesSchemaVersionEnum.unknownDefaultOpenApi,
        ),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'capabilityVersion': 'capability_version',
    'evaluatedAt': 'evaluated_at',
    'expiresAt': 'expires_at',
    'schemaVersion': 'schema_version',
  },
);

Map<String, dynamic> _$MemberBranchCapabilitiesToJson(
  MemberBranchCapabilities instance,
) => <String, dynamic>{
  'branches': instance.branches,
  'capability_version': instance.capabilityVersion,
  'environment':
      _$MemberBranchCapabilitiesEnvironmentEnumEnumMap[instance.environment]!,
  'evaluated_at': instance.evaluatedAt.toIso8601String(),
  'expires_at': instance.expiresAt.toIso8601String(),
  'schema_version':
      _$MemberBranchCapabilitiesSchemaVersionEnumEnumMap[instance
          .schemaVersion]!,
};

const _$MemberBranchCapabilitiesEnvironmentEnumEnumMap = {
  MemberBranchCapabilitiesEnvironmentEnum.beta: 'beta',
  MemberBranchCapabilitiesEnvironmentEnum.production: 'production',
  MemberBranchCapabilitiesEnvironmentEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$MemberBranchCapabilitiesSchemaVersionEnumEnumMap = {
  MemberBranchCapabilitiesSchemaVersionEnum.memberBranchCapabilitiesV1:
      'member-branch-capabilities-v1',
  MemberBranchCapabilitiesSchemaVersionEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
