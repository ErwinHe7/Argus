//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'health_response_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class HealthResponseData {
  /// Returns a new [HealthResponseData] instance.
  HealthResponseData({required this.buildRevision, required this.status});

  @JsonKey(name: r'build_revision', required: true, includeIfNull: false)
  final String buildRevision;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: HealthResponseDataStatusEnum.unknownDefaultOpenApi,
  )
  final HealthResponseDataStatusEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthResponseData &&
          other.buildRevision == buildRevision &&
          other.status == status;

  @override
  int get hashCode => buildRevision.hashCode + status.hashCode;

  factory HealthResponseData.fromJson(Map<String, dynamic> json) =>
      _$HealthResponseDataFromJson(json);

  Map<String, dynamic> toJson() => _$HealthResponseDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum HealthResponseDataStatusEnum {
  @JsonValue(r'ok')
  ok(r'ok'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const HealthResponseDataStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
