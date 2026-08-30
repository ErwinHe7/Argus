//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'starpath_authority.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StarpathAuthority {
  /// Returns a new [StarpathAuthority] instance.
  StarpathAuthority({
    required this.capabilityVersion,

    required this.environment,

    required this.jurisdiction,

    required this.manifestId,

    required this.manifestVersion,

    required this.policyVersion,
  });

  // minimum: 0
  @JsonKey(name: r'capability_version', required: true, includeIfNull: false)
  final int capabilityVersion;

  @JsonKey(
    name: r'environment',
    required: true,
    includeIfNull: false,
    unknownEnumValue: StarpathAuthorityEnvironmentEnum.unknownDefaultOpenApi,
  )
  final StarpathAuthorityEnvironmentEnum environment;

  @JsonKey(name: r'jurisdiction', required: true, includeIfNull: false)
  final String jurisdiction;

  @JsonKey(name: r'manifest_id', required: true, includeIfNull: false)
  final String manifestId;

  @JsonKey(name: r'manifest_version', required: true, includeIfNull: false)
  final String manifestVersion;

  @JsonKey(name: r'policy_version', required: true, includeIfNull: false)
  final String policyVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StarpathAuthority &&
          other.capabilityVersion == capabilityVersion &&
          other.environment == environment &&
          other.jurisdiction == jurisdiction &&
          other.manifestId == manifestId &&
          other.manifestVersion == manifestVersion &&
          other.policyVersion == policyVersion;

  @override
  int get hashCode =>
      capabilityVersion.hashCode +
      environment.hashCode +
      jurisdiction.hashCode +
      manifestId.hashCode +
      manifestVersion.hashCode +
      policyVersion.hashCode;

  factory StarpathAuthority.fromJson(Map<String, dynamic> json) =>
      _$StarpathAuthorityFromJson(json);

  Map<String, dynamic> toJson() => _$StarpathAuthorityToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum StarpathAuthorityEnvironmentEnum {
  @JsonValue(r'beta')
  beta(r'beta'),
  @JsonValue(r'production')
  production(r'production'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const StarpathAuthorityEnvironmentEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
