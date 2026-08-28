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
  RetryAdminJobRequest({required this.stepUpReceipt});

  @JsonKey(name: r'step_up_receipt', required: true, includeIfNull: false)
  final String stepUpReceipt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RetryAdminJobRequest && other.stepUpReceipt == stepUpReceipt;

  @override
  int get hashCode => stepUpReceipt.hashCode;

  factory RetryAdminJobRequest.fromJson(Map<String, dynamic> json) =>
      _$RetryAdminJobRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RetryAdminJobRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
