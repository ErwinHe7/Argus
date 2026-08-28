//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'request_privacy_action_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RequestPrivacyActionRequest {
  /// Returns a new [RequestPrivacyActionRequest] instance.
  RequestPrivacyActionRequest({required this.requestType});

  @JsonKey(
    name: r'requestType',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        RequestPrivacyActionRequestRequestTypeEnum.unknownDefaultOpenApi,
  )
  final RequestPrivacyActionRequestRequestTypeEnum requestType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequestPrivacyActionRequest && other.requestType == requestType;

  @override
  int get hashCode => requestType.hashCode;

  factory RequestPrivacyActionRequest.fromJson(Map<String, dynamic> json) =>
      _$RequestPrivacyActionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RequestPrivacyActionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum RequestPrivacyActionRequestRequestTypeEnum {
  @JsonValue(r'export')
  export_(r'export'),
  @JsonValue(r'deletion')
  deletion(r'deletion'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RequestPrivacyActionRequestRequestTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
