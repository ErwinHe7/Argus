//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'privacy_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PrivacyRequest {
  /// Returns a new [PrivacyRequest] instance.
  PrivacyRequest({
    required this.completedAt,

    required this.deletionEpoch,

    required this.failureCode,

    required this.id,

    required this.requestType,

    required this.requestedAt,

    required this.status,

    required this.userId,
  });

  @JsonKey(name: r'completed_at', required: true, includeIfNull: true)
  final DateTime? completedAt;

  // minimum: 0
  @JsonKey(name: r'deletion_epoch', required: true, includeIfNull: true)
  final int? deletionEpoch;

  @JsonKey(name: r'failure_code', required: true, includeIfNull: true)
  final String? failureCode;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(
    name: r'request_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: PrivacyRequestRequestTypeEnum.unknownDefaultOpenApi,
  )
  final PrivacyRequestRequestTypeEnum requestType;

  @JsonKey(name: r'requested_at', required: true, includeIfNull: false)
  final DateTime requestedAt;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: PrivacyRequestStatusEnum.unknownDefaultOpenApi,
  )
  final PrivacyRequestStatusEnum status;

  @JsonKey(name: r'user_id', required: true, includeIfNull: false)
  final String userId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivacyRequest &&
          other.completedAt == completedAt &&
          other.deletionEpoch == deletionEpoch &&
          other.failureCode == failureCode &&
          other.id == id &&
          other.requestType == requestType &&
          other.requestedAt == requestedAt &&
          other.status == status &&
          other.userId == userId;

  @override
  int get hashCode =>
      (completedAt == null ? 0 : completedAt.hashCode) +
      (deletionEpoch == null ? 0 : deletionEpoch.hashCode) +
      (failureCode == null ? 0 : failureCode.hashCode) +
      id.hashCode +
      requestType.hashCode +
      requestedAt.hashCode +
      status.hashCode +
      userId.hashCode;

  factory PrivacyRequest.fromJson(Map<String, dynamic> json) =>
      _$PrivacyRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PrivacyRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum PrivacyRequestRequestTypeEnum {
  @JsonValue(r'export')
  export_(r'export'),
  @JsonValue(r'deletion')
  deletion(r'deletion'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PrivacyRequestRequestTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum PrivacyRequestStatusEnum {
  @JsonValue(r'requested')
  requested(r'requested'),
  @JsonValue(r'verified')
  verified(r'verified'),
  @JsonValue(r'queued')
  queued(r'queued'),
  @JsonValue(r'processing')
  processing(r'processing'),
  @JsonValue(r'completed')
  completed(r'completed'),
  @JsonValue(r'failed')
  failed(r'failed'),
  @JsonValue(r'cancelled')
  cancelled(r'cancelled'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PrivacyRequestStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
