//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/admin_moderation_report.dart';
import 'package:ritual_investing_api_client/generated/model/admin_moderation_case_decisions_inner.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'admin_moderation_case.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AdminModerationCase {
  /// Returns a new [AdminModerationCase] instance.
  AdminModerationCase({
    required this.assigneeId,

    required this.decisions,

    required this.etag,

    required this.id,

    required this.report,

    required this.resolutionCode,

    required this.resolvedAt,

    required this.status,

    required this.version,
  });

  @JsonKey(name: r'assignee_id', required: true, includeIfNull: true)
  final String? assigneeId;

  @JsonKey(name: r'decisions', required: true, includeIfNull: false)
  final List<AdminModerationCaseDecisionsInner> decisions;

  @JsonKey(name: r'etag', required: true, includeIfNull: false)
  final String etag;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'report', required: true, includeIfNull: false)
  final AdminModerationReport report;

  @JsonKey(name: r'resolution_code', required: true, includeIfNull: true)
  final String? resolutionCode;

  @JsonKey(name: r'resolved_at', required: true, includeIfNull: true)
  final DateTime? resolvedAt;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AdminModerationCaseStatusEnum.unknownDefaultOpenApi,
  )
  final AdminModerationCaseStatusEnum status;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminModerationCase &&
          other.assigneeId == assigneeId &&
          other.decisions == decisions &&
          other.etag == etag &&
          other.id == id &&
          other.report == report &&
          other.resolutionCode == resolutionCode &&
          other.resolvedAt == resolvedAt &&
          other.status == status &&
          other.version == version;

  @override
  int get hashCode =>
      (assigneeId == null ? 0 : assigneeId.hashCode) +
      decisions.hashCode +
      etag.hashCode +
      id.hashCode +
      report.hashCode +
      (resolutionCode == null ? 0 : resolutionCode.hashCode) +
      (resolvedAt == null ? 0 : resolvedAt.hashCode) +
      status.hashCode +
      version.hashCode;

  factory AdminModerationCase.fromJson(Map<String, dynamic> json) =>
      _$AdminModerationCaseFromJson(json);

  Map<String, dynamic> toJson() => _$AdminModerationCaseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum AdminModerationCaseStatusEnum {
  @JsonValue(r'open')
  open(r'open'),
  @JsonValue(r'investigating')
  investigating(r'investigating'),
  @JsonValue(r'resolved')
  resolved(r'resolved'),
  @JsonValue(r'dismissed')
  dismissed(r'dismissed'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AdminModerationCaseStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
