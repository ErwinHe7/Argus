//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'reset_demo_state_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ResetDemoStateRequest {
  /// Returns a new [ResetDemoStateRequest] instance.
  ResetDemoStateRequest({
    required this.confirmation,

    required this.seedVersion,
  });

  @JsonKey(
    name: r'confirmation',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        ResetDemoStateRequestConfirmationEnum.unknownDefaultOpenApi,
  )
  final ResetDemoStateRequestConfirmationEnum confirmation;

  // minimum: 0
  @JsonKey(name: r'seed_version', required: true, includeIfNull: false)
  final int seedVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResetDemoStateRequest &&
          other.confirmation == confirmation &&
          other.seedVersion == seedVersion;

  @override
  int get hashCode => confirmation.hashCode + seedVersion.hashCode;

  factory ResetDemoStateRequest.fromJson(Map<String, dynamic> json) =>
      _$ResetDemoStateRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ResetDemoStateRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum ResetDemoStateRequestConfirmationEnum {
  @JsonValue(r'RESET_DEMO')
  RESET_DEMO(r'RESET_DEMO'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ResetDemoStateRequestConfirmationEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
