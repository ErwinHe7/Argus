//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'admin_moderation_case_decisions_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AdminModerationCaseDecisionsInner {
  /// Returns a new [AdminModerationCaseDecisionsInner] instance.
  AdminModerationCaseDecisionsInner({
    required this.decidedAt,

    required this.outcome,

    required this.reason,
  });

  @JsonKey(name: r'decided_at', required: true, includeIfNull: false)
  final DateTime decidedAt;

  @JsonKey(name: r'outcome', required: true, includeIfNull: false)
  final String outcome;

  @JsonKey(name: r'reason', required: true, includeIfNull: false)
  final String reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminModerationCaseDecisionsInner &&
          other.decidedAt == decidedAt &&
          other.outcome == outcome &&
          other.reason == reason;

  @override
  int get hashCode => decidedAt.hashCode + outcome.hashCode + reason.hashCode;

  factory AdminModerationCaseDecisionsInner.fromJson(
    Map<String, dynamic> json,
  ) => _$AdminModerationCaseDecisionsInnerFromJson(json);

  Map<String, dynamic> toJson() =>
      _$AdminModerationCaseDecisionsInnerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
