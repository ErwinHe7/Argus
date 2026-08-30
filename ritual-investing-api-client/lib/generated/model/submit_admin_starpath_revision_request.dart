//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'submit_admin_starpath_revision_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SubmitAdminStarpathRevisionRequest {
  /// Returns a new [SubmitAdminStarpathRevisionRequest] instance.
  SubmitAdminStarpathRevisionRequest({required this.policyVersion});

  @JsonKey(name: r'policy_version', required: true, includeIfNull: false)
  final String policyVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubmitAdminStarpathRevisionRequest &&
          other.policyVersion == policyVersion;

  @override
  int get hashCode => policyVersion.hashCode;

  factory SubmitAdminStarpathRevisionRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$SubmitAdminStarpathRevisionRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$SubmitAdminStarpathRevisionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
