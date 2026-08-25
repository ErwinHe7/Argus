//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'session_bootstrap_astrology_profile.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SessionBootstrapAstrologyProfile {
  /// Returns a new [SessionBootstrapAstrologyProfile] instance.
  SessionBootstrapAstrologyProfile({
    required this.algorithmVersion,

    required this.birthDate,

    required this.derivedProfileCode,

    required this.enabledAt,

    required this.version,
  });

  @JsonKey(
    name: r'algorithm_version',
    required: true,
    includeIfNull: false,
    unknownEnumValue: SessionBootstrapAstrologyProfileAlgorithmVersionEnum
        .unknownDefaultOpenApi,
  )
  final SessionBootstrapAstrologyProfileAlgorithmVersionEnum algorithmVersion;

  @JsonKey(name: r'birth_date', required: true, includeIfNull: false)
  final DateTime birthDate;

  @JsonKey(
    name: r'derived_profile_code',
    required: true,
    includeIfNull: false,
    unknownEnumValue: SessionBootstrapAstrologyProfileDerivedProfileCodeEnum
        .unknownDefaultOpenApi,
  )
  final SessionBootstrapAstrologyProfileDerivedProfileCodeEnum
  derivedProfileCode;

  @JsonKey(name: r'enabled_at', required: true, includeIfNull: false)
  final DateTime enabledAt;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionBootstrapAstrologyProfile &&
          other.algorithmVersion == algorithmVersion &&
          other.birthDate == birthDate &&
          other.derivedProfileCode == derivedProfileCode &&
          other.enabledAt == enabledAt &&
          other.version == version;

  @override
  int get hashCode =>
      algorithmVersion.hashCode +
      birthDate.hashCode +
      derivedProfileCode.hashCode +
      enabledAt.hashCode +
      version.hashCode;

  factory SessionBootstrapAstrologyProfile.fromJson(
    Map<String, dynamic> json,
  ) => _$SessionBootstrapAstrologyProfileFromJson(json);

  Map<String, dynamic> toJson() =>
      _$SessionBootstrapAstrologyProfileToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum SessionBootstrapAstrologyProfileAlgorithmVersionEnum {
  @JsonValue(r'v1')
  v1(r'v1'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const SessionBootstrapAstrologyProfileAlgorithmVersionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum SessionBootstrapAstrologyProfileDerivedProfileCodeEnum {
  @JsonValue(r'lunar_patient')
  lunarPatient(r'lunar_patient'),
  @JsonValue(r'solar_builder')
  solarBuilder(r'solar_builder'),
  @JsonValue(r'rising_explorer')
  risingExplorer(r'rising_explorer'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const SessionBootstrapAstrologyProfileDerivedProfileCodeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
