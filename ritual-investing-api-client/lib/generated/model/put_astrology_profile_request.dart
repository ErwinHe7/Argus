//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'put_astrology_profile_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PutAstrologyProfileRequest {
  /// Returns a new [PutAstrologyProfileRequest] instance.
  PutAstrologyProfileRequest({
    this.algorithmVersion,

    required this.birthDate,

    this.derivedProfileCode,
  });

  @JsonKey(
    name: r'algorithm_version',
    required: false,
    includeIfNull: false,
    unknownEnumValue:
        PutAstrologyProfileRequestAlgorithmVersionEnum.unknownDefaultOpenApi,
  )
  final PutAstrologyProfileRequestAlgorithmVersionEnum? algorithmVersion;

  @JsonKey(name: r'birth_date', required: true, includeIfNull: false)
  final DateTime birthDate;

  @JsonKey(
    name: r'derived_profile_code',
    required: false,
    includeIfNull: false,
    unknownEnumValue:
        PutAstrologyProfileRequestDerivedProfileCodeEnum.unknownDefaultOpenApi,
  )
  final PutAstrologyProfileRequestDerivedProfileCodeEnum? derivedProfileCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PutAstrologyProfileRequest &&
          other.algorithmVersion == algorithmVersion &&
          other.birthDate == birthDate &&
          other.derivedProfileCode == derivedProfileCode;

  @override
  int get hashCode =>
      algorithmVersion.hashCode +
      birthDate.hashCode +
      derivedProfileCode.hashCode;

  factory PutAstrologyProfileRequest.fromJson(Map<String, dynamic> json) =>
      _$PutAstrologyProfileRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PutAstrologyProfileRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum PutAstrologyProfileRequestAlgorithmVersionEnum {
  @JsonValue(r'v1')
  v1(r'v1'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PutAstrologyProfileRequestAlgorithmVersionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum PutAstrologyProfileRequestDerivedProfileCodeEnum {
  @JsonValue(r'lunar_patient')
  lunarPatient(r'lunar_patient'),
  @JsonValue(r'solar_builder')
  solarBuilder(r'solar_builder'),
  @JsonValue(r'rising_explorer')
  risingExplorer(r'rising_explorer'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PutAstrologyProfileRequestDerivedProfileCodeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
