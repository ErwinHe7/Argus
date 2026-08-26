//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'retry_admin_job_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RetryAdminJobRequest {
  /// Returns a new [RetryAdminJobRequest] instance.
  RetryAdminJobRequest({required this.reason});

  @JsonKey(name: r'reason', required: true, includeIfNull: false)
  final String reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RetryAdminJobRequest && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  factory RetryAdminJobRequest.fromJson(Map<String, dynamic> json) =>
      _$RetryAdminJobRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RetryAdminJobRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
