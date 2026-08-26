//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'recurring_plan_recent_runs_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RecurringPlanRecentRunsInner {
  /// Returns a new [RecurringPlanRecentRunsInner] instance.
  RecurringPlanRecentRunsInner({
    required this.id,

    required this.scheduledFor,

    required this.status,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'scheduled_for', required: true, includeIfNull: false)
  final DateTime scheduledFor;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        RecurringPlanRecentRunsInnerStatusEnum.unknownDefaultOpenApi,
  )
  final RecurringPlanRecentRunsInnerStatusEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringPlanRecentRunsInner &&
          other.id == id &&
          other.scheduledFor == scheduledFor &&
          other.status == status;

  @override
  int get hashCode => id.hashCode + scheduledFor.hashCode + status.hashCode;

  factory RecurringPlanRecentRunsInner.fromJson(Map<String, dynamic> json) =>
      _$RecurringPlanRecentRunsInnerFromJson(json);

  Map<String, dynamic> toJson() => _$RecurringPlanRecentRunsInnerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum RecurringPlanRecentRunsInnerStatusEnum {
  @JsonValue(r'due')
  due(r'due'),
  @JsonValue(r'running')
  running(r'running'),
  @JsonValue(r'completed')
  completed(r'completed'),
  @JsonValue(r'rejected')
  rejected(r'rejected'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RecurringPlanRecentRunsInnerStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
