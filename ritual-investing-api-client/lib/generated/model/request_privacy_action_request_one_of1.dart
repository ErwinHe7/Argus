//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'request_privacy_action_request_one_of1.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RequestPrivacyActionRequestOneOf1 {
  /// Returns a new [RequestPrivacyActionRequestOneOf1] instance.
  RequestPrivacyActionRequestOneOf1({
    required this.requestType,

    required this.stepUpReceipt,
  });

  @JsonKey(
    name: r'requestType',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        RequestPrivacyActionRequestOneOf1RequestTypeEnum.unknownDefaultOpenApi,
  )
  final RequestPrivacyActionRequestOneOf1RequestTypeEnum requestType;

  @JsonKey(name: r'step_up_receipt', required: true, includeIfNull: false)
  final String stepUpReceipt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequestPrivacyActionRequestOneOf1 &&
          other.requestType == requestType &&
          other.stepUpReceipt == stepUpReceipt;

  @override
  int get hashCode => requestType.hashCode + stepUpReceipt.hashCode;

  factory RequestPrivacyActionRequestOneOf1.fromJson(
    Map<String, dynamic> json,
  ) => _$RequestPrivacyActionRequestOneOf1FromJson(json);

  Map<String, dynamic> toJson() =>
      _$RequestPrivacyActionRequestOneOf1ToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum RequestPrivacyActionRequestOneOf1RequestTypeEnum {
  @JsonValue(r'deletion')
  deletion(r'deletion'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RequestPrivacyActionRequestOneOf1RequestTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
