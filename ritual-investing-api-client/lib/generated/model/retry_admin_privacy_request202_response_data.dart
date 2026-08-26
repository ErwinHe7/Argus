//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'retry_admin_privacy_request202_response_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RetryAdminPrivacyRequest202ResponseData {
  /// Returns a new [RetryAdminPrivacyRequest202ResponseData] instance.
  RetryAdminPrivacyRequest202ResponseData({required this.outboxId});

  @JsonKey(name: r'outbox_id', required: true, includeIfNull: false)
  final String outboxId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RetryAdminPrivacyRequest202ResponseData &&
          other.outboxId == outboxId;

  @override
  int get hashCode => outboxId.hashCode;

  factory RetryAdminPrivacyRequest202ResponseData.fromJson(
    Map<String, dynamic> json,
  ) => _$RetryAdminPrivacyRequest202ResponseDataFromJson(json);

  Map<String, dynamic> toJson() =>
      _$RetryAdminPrivacyRequest202ResponseDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
