//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'admin_audit_event.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AdminAuditEvent {
  /// Returns a new [AdminAuditEvent] instance.
  AdminAuditEvent({
    required this.action,

    required this.actorStaffId,

    required this.afterHash,

    required this.beforeHash,

    required this.createdAt,

    required this.id,

    required this.outcome,

    required this.reason,

    required this.requestId,

    required this.targetId,

    required this.targetKind,
  });

  @JsonKey(name: r'action', required: true, includeIfNull: false)
  final String action;

  @JsonKey(name: r'actor_staff_id', required: true, includeIfNull: false)
  final String actorStaffId;

  @JsonKey(name: r'after_hash', required: true, includeIfNull: true)
  final String? afterHash;

  @JsonKey(name: r'before_hash', required: true, includeIfNull: true)
  final String? beforeHash;

  @JsonKey(name: r'created_at', required: true, includeIfNull: false)
  final DateTime createdAt;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(
    name: r'outcome',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AdminAuditEventOutcomeEnum.unknownDefaultOpenApi,
  )
  final AdminAuditEventOutcomeEnum outcome;

  @JsonKey(name: r'reason', required: true, includeIfNull: false)
  final String reason;

  @JsonKey(name: r'request_id', required: true, includeIfNull: false)
  final String requestId;

  @JsonKey(name: r'target_id', required: true, includeIfNull: true)
  final String? targetId;

  @JsonKey(name: r'target_kind', required: true, includeIfNull: false)
  final String targetKind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminAuditEvent &&
          other.action == action &&
          other.actorStaffId == actorStaffId &&
          other.afterHash == afterHash &&
          other.beforeHash == beforeHash &&
          other.createdAt == createdAt &&
          other.id == id &&
          other.outcome == outcome &&
          other.reason == reason &&
          other.requestId == requestId &&
          other.targetId == targetId &&
          other.targetKind == targetKind;

  @override
  int get hashCode =>
      action.hashCode +
      actorStaffId.hashCode +
      (afterHash == null ? 0 : afterHash.hashCode) +
      (beforeHash == null ? 0 : beforeHash.hashCode) +
      createdAt.hashCode +
      id.hashCode +
      outcome.hashCode +
      reason.hashCode +
      requestId.hashCode +
      (targetId == null ? 0 : targetId.hashCode) +
      targetKind.hashCode;

  factory AdminAuditEvent.fromJson(Map<String, dynamic> json) =>
      _$AdminAuditEventFromJson(json);

  Map<String, dynamic> toJson() => _$AdminAuditEventToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum AdminAuditEventOutcomeEnum {
  @JsonValue(r'allowed')
  allowed(r'allowed'),
  @JsonValue(r'denied')
  denied(r'denied'),
  @JsonValue(r'failed')
  failed(r'failed'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AdminAuditEventOutcomeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
