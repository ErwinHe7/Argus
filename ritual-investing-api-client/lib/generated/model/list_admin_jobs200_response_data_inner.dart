//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_admin_jobs200_response_data_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListAdminJobs200ResponseDataInner {
  /// Returns a new [ListAdminJobs200ResponseDataInner] instance.
  ListAdminJobs200ResponseDataInner({
    required this.attempt,

    required this.completedAt,

    required this.consumer,

    required this.correlationId,

    required this.createdAt,

    required this.failureCode,

    required this.id,

    required this.outboxId,

    required this.status,
  });

  // minimum: 0
  @JsonKey(name: r'attempt', required: true, includeIfNull: false)
  final int attempt;

  @JsonKey(name: r'completed_at', required: true, includeIfNull: true)
  final DateTime? completedAt;

  @JsonKey(name: r'consumer', required: true, includeIfNull: false)
  final String consumer;

  @JsonKey(name: r'correlation_id', required: true, includeIfNull: false)
  final String correlationId;

  @JsonKey(name: r'created_at', required: true, includeIfNull: false)
  final DateTime createdAt;

  @JsonKey(name: r'failure_code', required: true, includeIfNull: true)
  final String? failureCode;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'outbox_id', required: true, includeIfNull: false)
  final String outboxId;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        ListAdminJobs200ResponseDataInnerStatusEnum.unknownDefaultOpenApi,
  )
  final ListAdminJobs200ResponseDataInnerStatusEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListAdminJobs200ResponseDataInner &&
          other.attempt == attempt &&
          other.completedAt == completedAt &&
          other.consumer == consumer &&
          other.correlationId == correlationId &&
          other.createdAt == createdAt &&
          other.failureCode == failureCode &&
          other.id == id &&
          other.outboxId == outboxId &&
          other.status == status;

  @override
  int get hashCode =>
      attempt.hashCode +
      (completedAt == null ? 0 : completedAt.hashCode) +
      consumer.hashCode +
      correlationId.hashCode +
      createdAt.hashCode +
      (failureCode == null ? 0 : failureCode.hashCode) +
      id.hashCode +
      outboxId.hashCode +
      status.hashCode;

  factory ListAdminJobs200ResponseDataInner.fromJson(
    Map<String, dynamic> json,
  ) => _$ListAdminJobs200ResponseDataInnerFromJson(json);

  Map<String, dynamic> toJson() =>
      _$ListAdminJobs200ResponseDataInnerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum ListAdminJobs200ResponseDataInnerStatusEnum {
  @JsonValue(r'leased')
  leased(r'leased'),
  @JsonValue(r'completed')
  completed(r'completed'),
  @JsonValue(r'retry')
  retry(r'retry'),
  @JsonValue(r'dead_letter')
  deadLetter(r'dead_letter'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ListAdminJobs200ResponseDataInnerStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
