//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_admin_moderation_case_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateAdminModerationCaseRequest {
  /// Returns a new [CreateAdminModerationCaseRequest] instance.
  CreateAdminModerationCaseRequest({this.assigneeId, required this.note});

  @JsonKey(name: r'assignee_id', required: false, includeIfNull: false)
  final String? assigneeId;

  @JsonKey(name: r'note', required: true, includeIfNull: false)
  final String note;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateAdminModerationCaseRequest &&
          other.assigneeId == assigneeId &&
          other.note == note;

  @override
  int get hashCode =>
      (assigneeId == null ? 0 : assigneeId.hashCode) + note.hashCode;

  factory CreateAdminModerationCaseRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$CreateAdminModerationCaseRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateAdminModerationCaseRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
