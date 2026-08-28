//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'issue_member_step_up_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class IssueMemberStepUpRequest {
  /// Returns a new [IssueMemberStepUpRequest] instance.
  IssueMemberStepUpRequest({required this.action});

  @JsonKey(
    name: r'action',
    required: true,
    includeIfNull: false,
    unknownEnumValue: IssueMemberStepUpRequestActionEnum.unknownDefaultOpenApi,
  )
  final IssueMemberStepUpRequestActionEnum action;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IssueMemberStepUpRequest && other.action == action;

  @override
  int get hashCode => action.hashCode;

  factory IssueMemberStepUpRequest.fromJson(Map<String, dynamic> json) =>
      _$IssueMemberStepUpRequestFromJson(json);

  Map<String, dynamic> toJson() => _$IssueMemberStepUpRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum IssueMemberStepUpRequestActionEnum {
  @JsonValue(r'webull_disconnect')
  webullDisconnect(r'webull_disconnect'),
  @JsonValue(r'argus_delete')
  argusDelete(r'argus_delete'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const IssueMemberStepUpRequestActionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
