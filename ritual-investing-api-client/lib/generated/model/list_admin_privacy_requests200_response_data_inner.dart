//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_admin_privacy_requests200_response_data_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListAdminPrivacyRequests200ResponseDataInner {
  /// Returns a new [ListAdminPrivacyRequests200ResponseDataInner] instance.
  ListAdminPrivacyRequests200ResponseDataInner({
    required this.completedAt,

    required this.failureCode,

    required this.id,

    required this.purgeGeneration,

    required this.queuedAt,

    required this.requestType,

    required this.snapshotAt,

    required this.status,

    required this.tenantId,
  });

  @JsonKey(name: r'completed_at', required: true, includeIfNull: true)
  final DateTime? completedAt;

  @JsonKey(name: r'failure_code', required: true, includeIfNull: true)
  final String? failureCode;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  // minimum: 0
  @JsonKey(name: r'purge_generation', required: true, includeIfNull: true)
  final int? purgeGeneration;

  @JsonKey(name: r'queued_at', required: true, includeIfNull: true)
  final DateTime? queuedAt;

  @JsonKey(
    name: r'request_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        ListAdminPrivacyRequests200ResponseDataInnerRequestTypeEnum
            .unknownDefaultOpenApi,
  )
  final ListAdminPrivacyRequests200ResponseDataInnerRequestTypeEnum requestType;

  @JsonKey(name: r'snapshot_at', required: true, includeIfNull: true)
  final DateTime? snapshotAt;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: ListAdminPrivacyRequests200ResponseDataInnerStatusEnum
        .unknownDefaultOpenApi,
  )
  final ListAdminPrivacyRequests200ResponseDataInnerStatusEnum status;

  @JsonKey(name: r'tenant_id', required: true, includeIfNull: false)
  final String tenantId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListAdminPrivacyRequests200ResponseDataInner &&
          other.completedAt == completedAt &&
          other.failureCode == failureCode &&
          other.id == id &&
          other.purgeGeneration == purgeGeneration &&
          other.queuedAt == queuedAt &&
          other.requestType == requestType &&
          other.snapshotAt == snapshotAt &&
          other.status == status &&
          other.tenantId == tenantId;

  @override
  int get hashCode =>
      (completedAt == null ? 0 : completedAt.hashCode) +
      (failureCode == null ? 0 : failureCode.hashCode) +
      id.hashCode +
      (purgeGeneration == null ? 0 : purgeGeneration.hashCode) +
      (queuedAt == null ? 0 : queuedAt.hashCode) +
      requestType.hashCode +
      (snapshotAt == null ? 0 : snapshotAt.hashCode) +
      status.hashCode +
      tenantId.hashCode;

  factory ListAdminPrivacyRequests200ResponseDataInner.fromJson(
    Map<String, dynamic> json,
  ) => _$ListAdminPrivacyRequests200ResponseDataInnerFromJson(json);

  Map<String, dynamic> toJson() =>
      _$ListAdminPrivacyRequests200ResponseDataInnerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum ListAdminPrivacyRequests200ResponseDataInnerRequestTypeEnum {
  @JsonValue(r'export')
  export_(r'export'),
  @JsonValue(r'delete')
  delete(r'delete'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ListAdminPrivacyRequests200ResponseDataInnerRequestTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum ListAdminPrivacyRequests200ResponseDataInnerStatusEnum {
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

  const ListAdminPrivacyRequests200ResponseDataInnerStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
