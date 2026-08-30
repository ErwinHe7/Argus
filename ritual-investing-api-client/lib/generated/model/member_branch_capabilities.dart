//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'member_branch_capabilities.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MemberBranchCapabilities {
  /// Returns a new [MemberBranchCapabilities] instance.
  MemberBranchCapabilities({
    required this.branches,

    required this.capabilityVersion,

    required this.environment,

    required this.evaluatedAt,

    required this.expiresAt,

    required this.schemaVersion,
  });

  @JsonKey(name: r'branches', required: true, includeIfNull: false)
  final List<String> branches;

  // minimum: 0
  @JsonKey(name: r'capability_version', required: true, includeIfNull: false)
  final int capabilityVersion;

  @JsonKey(
    name: r'environment',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        MemberBranchCapabilitiesEnvironmentEnum.unknownDefaultOpenApi,
  )
  final MemberBranchCapabilitiesEnvironmentEnum environment;

  @JsonKey(name: r'evaluated_at', required: true, includeIfNull: false)
  final DateTime evaluatedAt;

  @JsonKey(name: r'expires_at', required: true, includeIfNull: false)
  final DateTime expiresAt;

  @JsonKey(
    name: r'schema_version',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        MemberBranchCapabilitiesSchemaVersionEnum.unknownDefaultOpenApi,
  )
  final MemberBranchCapabilitiesSchemaVersionEnum schemaVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberBranchCapabilities &&
          other.branches == branches &&
          other.capabilityVersion == capabilityVersion &&
          other.environment == environment &&
          other.evaluatedAt == evaluatedAt &&
          other.expiresAt == expiresAt &&
          other.schemaVersion == schemaVersion;

  @override
  int get hashCode =>
      branches.hashCode +
      capabilityVersion.hashCode +
      environment.hashCode +
      evaluatedAt.hashCode +
      expiresAt.hashCode +
      schemaVersion.hashCode;

  factory MemberBranchCapabilities.fromJson(Map<String, dynamic> json) =>
      _$MemberBranchCapabilitiesFromJson(json);

  Map<String, dynamic> toJson() => _$MemberBranchCapabilitiesToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum MemberBranchCapabilitiesEnvironmentEnum {
  @JsonValue(r'beta')
  beta(r'beta'),
  @JsonValue(r'production')
  production(r'production'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const MemberBranchCapabilitiesEnvironmentEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum MemberBranchCapabilitiesSchemaVersionEnum {
  @JsonValue(r'member-branch-capabilities-v1')
  memberBranchCapabilitiesV1(r'member-branch-capabilities-v1'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const MemberBranchCapabilitiesSchemaVersionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
