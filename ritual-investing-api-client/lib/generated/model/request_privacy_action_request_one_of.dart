//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'request_privacy_action_request_one_of.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RequestPrivacyActionRequestOneOf {
  /// Returns a new [RequestPrivacyActionRequestOneOf] instance.
  RequestPrivacyActionRequestOneOf({required this.requestType});

  @JsonKey(
    name: r'requestType',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        RequestPrivacyActionRequestOneOfRequestTypeEnum.unknownDefaultOpenApi,
  )
  final RequestPrivacyActionRequestOneOfRequestTypeEnum requestType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequestPrivacyActionRequestOneOf &&
          other.requestType == requestType;

  @override
  int get hashCode => requestType.hashCode;

  factory RequestPrivacyActionRequestOneOf.fromJson(
    Map<String, dynamic> json,
  ) => _$RequestPrivacyActionRequestOneOfFromJson(json);

  Map<String, dynamic> toJson() =>
      _$RequestPrivacyActionRequestOneOfToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum RequestPrivacyActionRequestOneOfRequestTypeEnum {
  @JsonValue(r'export')
  export_(r'export'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RequestPrivacyActionRequestOneOfRequestTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
