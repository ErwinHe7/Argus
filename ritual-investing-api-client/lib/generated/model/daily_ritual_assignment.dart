//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'daily_ritual_assignment.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DailyRitualAssignment {
  /// Returns a new [DailyRitualAssignment] instance.
  DailyRitualAssignment({
    required this.allowedTokens,

    required this.bodyTemplate,

    required this.completedAt,

    required this.deletionEpoch,

    required this.id,

    required this.localDate,

    required this.mode,

    required this.payload,

    required this.revealedAt,

    required this.revisionId,

    required this.riskFooter,

    required this.rowanRevisionId,

    required this.scheduleId,

    required this.serverEvaluatedAt,

    required this.state,

    required this.userId,

    required this.validUntil,

    required this.version,
  });

  @JsonKey(name: r'allowed_tokens', required: true, includeIfNull: true)
  final List<String>? allowedTokens;

  @JsonKey(name: r'body_template', required: true, includeIfNull: true)
  final String? bodyTemplate;

  @JsonKey(name: r'completed_at', required: true, includeIfNull: true)
  final DateTime? completedAt;

  // minimum: 0
  @JsonKey(name: r'deletion_epoch', required: true, includeIfNull: true)
  final int? deletionEpoch;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'local_date', required: true, includeIfNull: false)
  final DateTime localDate;

  @JsonKey(
    name: r'mode',
    required: true,
    includeIfNull: false,
    unknownEnumValue: DailyRitualAssignmentModeEnum.unknownDefaultOpenApi,
  )
  final DailyRitualAssignmentModeEnum mode;

  @JsonKey(name: r'payload', required: true, includeIfNull: false)
  final Map<String, Object?> payload;

  @JsonKey(name: r'revealed_at', required: true, includeIfNull: true)
  final DateTime? revealedAt;

  @JsonKey(name: r'revision_id', required: true, includeIfNull: false)
  final String revisionId;

  @JsonKey(name: r'risk_footer', required: true, includeIfNull: true)
  final String? riskFooter;

  @JsonKey(name: r'rowan_revision_id', required: true, includeIfNull: true)
  final String? rowanRevisionId;

  @JsonKey(name: r'schedule_id', required: true, includeIfNull: false)
  final String scheduleId;

  @JsonKey(name: r'server_evaluated_at', required: true, includeIfNull: false)
  final DateTime serverEvaluatedAt;

  @JsonKey(
    name: r'state',
    required: true,
    includeIfNull: false,
    unknownEnumValue: DailyRitualAssignmentStateEnum.unknownDefaultOpenApi,
  )
  final DailyRitualAssignmentStateEnum state;

  @JsonKey(name: r'user_id', required: true, includeIfNull: false)
  final String userId;

  @JsonKey(name: r'valid_until', required: true, includeIfNull: false)
  final DateTime validUntil;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyRitualAssignment &&
          other.allowedTokens == allowedTokens &&
          other.bodyTemplate == bodyTemplate &&
          other.completedAt == completedAt &&
          other.deletionEpoch == deletionEpoch &&
          other.id == id &&
          other.localDate == localDate &&
          other.mode == mode &&
          other.payload == payload &&
          other.revealedAt == revealedAt &&
          other.revisionId == revisionId &&
          other.riskFooter == riskFooter &&
          other.rowanRevisionId == rowanRevisionId &&
          other.scheduleId == scheduleId &&
          other.serverEvaluatedAt == serverEvaluatedAt &&
          other.state == state &&
          other.userId == userId &&
          other.validUntil == validUntil &&
          other.version == version;

  @override
  int get hashCode =>
      (allowedTokens == null ? 0 : allowedTokens.hashCode) +
      (bodyTemplate == null ? 0 : bodyTemplate.hashCode) +
      (completedAt == null ? 0 : completedAt.hashCode) +
      (deletionEpoch == null ? 0 : deletionEpoch.hashCode) +
      id.hashCode +
      localDate.hashCode +
      mode.hashCode +
      payload.hashCode +
      (revealedAt == null ? 0 : revealedAt.hashCode) +
      revisionId.hashCode +
      (riskFooter == null ? 0 : riskFooter.hashCode) +
      (rowanRevisionId == null ? 0 : rowanRevisionId.hashCode) +
      scheduleId.hashCode +
      serverEvaluatedAt.hashCode +
      state.hashCode +
      userId.hashCode +
      validUntil.hashCode +
      version.hashCode;

  factory DailyRitualAssignment.fromJson(Map<String, dynamic> json) =>
      _$DailyRitualAssignmentFromJson(json);

  Map<String, dynamic> toJson() => _$DailyRitualAssignmentToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum DailyRitualAssignmentModeEnum {
  @JsonValue(r'tarot')
  tarot(r'tarot'),
  @JsonValue(r'astrology')
  astrology(r'astrology'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DailyRitualAssignmentModeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum DailyRitualAssignmentStateEnum {
  @JsonValue(r'assigned')
  assigned(r'assigned'),
  @JsonValue(r'revealed')
  revealed(r'revealed'),
  @JsonValue(r'completed')
  completed(r'completed'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DailyRitualAssignmentStateEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
