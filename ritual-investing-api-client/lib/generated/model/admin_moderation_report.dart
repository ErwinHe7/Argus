//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'admin_moderation_report.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AdminModerationReport {
  /// Returns a new [AdminModerationReport] instance.
  AdminModerationReport({
    required this.createdAt,

    required this.detail,

    required this.id,

    required this.reasonCode,

    required this.status,

    required this.targetId,

    required this.targetKind,
  });

  @JsonKey(name: r'created_at', required: true, includeIfNull: false)
  final DateTime createdAt;

  @JsonKey(name: r'detail', required: true, includeIfNull: true)
  final String? detail;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'reason_code', required: true, includeIfNull: false)
  final String reasonCode;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AdminModerationReportStatusEnum.unknownDefaultOpenApi,
  )
  final AdminModerationReportStatusEnum status;

  @JsonKey(name: r'target_id', required: true, includeIfNull: false)
  final String targetId;

  @JsonKey(
    name: r'target_kind',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AdminModerationReportTargetKindEnum.unknownDefaultOpenApi,
  )
  final AdminModerationReportTargetKindEnum targetKind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminModerationReport &&
          other.createdAt == createdAt &&
          other.detail == detail &&
          other.id == id &&
          other.reasonCode == reasonCode &&
          other.status == status &&
          other.targetId == targetId &&
          other.targetKind == targetKind;

  @override
  int get hashCode =>
      createdAt.hashCode +
      (detail == null ? 0 : detail.hashCode) +
      id.hashCode +
      reasonCode.hashCode +
      status.hashCode +
      targetId.hashCode +
      targetKind.hashCode;

  factory AdminModerationReport.fromJson(Map<String, dynamic> json) =>
      _$AdminModerationReportFromJson(json);

  Map<String, dynamic> toJson() => _$AdminModerationReportToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum AdminModerationReportStatusEnum {
  @JsonValue(r'open')
  open(r'open'),
  @JsonValue(r'triaged')
  triaged(r'triaged'),
  @JsonValue(r'resolved')
  resolved(r'resolved'),
  @JsonValue(r'dismissed')
  dismissed(r'dismissed'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AdminModerationReportStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum AdminModerationReportTargetKindEnum {
  @JsonValue(r'ritual')
  ritual(r'ritual'),
  @JsonValue(r'asset_codex')
  assetCodex(r'asset_codex'),
  @JsonValue(r'coven_entry')
  covenEntry(r'coven_entry'),
  @JsonValue(r'grimoire')
  grimoire(r'grimoire'),
  @JsonValue(r'circle_template')
  circleTemplate(r'circle_template'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AdminModerationReportTargetKindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
