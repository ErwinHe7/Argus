//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'issue_admin_step_up_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class IssueAdminStepUpRequest {
  /// Returns a new [IssueAdminStepUpRequest] instance.
  IssueAdminStepUpRequest({required this.action, required this.targetId});

  @JsonKey(
    name: r'action',
    required: true,
    includeIfNull: false,
    unknownEnumValue: IssueAdminStepUpRequestActionEnum.unknownDefaultOpenApi,
  )
  final IssueAdminStepUpRequestActionEnum action;

  @JsonKey(name: r'target_id', required: true, includeIfNull: false)
  final String targetId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IssueAdminStepUpRequest &&
          other.action == action &&
          other.targetId == targetId;

  @override
  int get hashCode => action.hashCode + targetId.hashCode;

  factory IssueAdminStepUpRequest.fromJson(Map<String, dynamic> json) =>
      _$IssueAdminStepUpRequestFromJson(json);

  Map<String, dynamic> toJson() => _$IssueAdminStepUpRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum IssueAdminStepUpRequestActionEnum {
  @JsonValue(r'admin_job_retry')
  adminJobRetry(r'admin_job_retry'),
  @JsonValue(r'admin_privacy_retry')
  adminPrivacyRetry(r'admin_privacy_retry'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const IssueAdminStepUpRequestActionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
