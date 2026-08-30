//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'review_admin_starpath_revision_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ReviewAdminStarpathRevisionRequest {
  /// Returns a new [ReviewAdminStarpathRevisionRequest] instance.
  ReviewAdminStarpathRevisionRequest({
    required this.decision,

    required this.discipline,

    required this.reason,
  });

  @JsonKey(
    name: r'decision',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        ReviewAdminStarpathRevisionRequestDecisionEnum.unknownDefaultOpenApi,
  )
  final ReviewAdminStarpathRevisionRequestDecisionEnum decision;

  @JsonKey(
    name: r'discipline',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        ReviewAdminStarpathRevisionRequestDisciplineEnum.unknownDefaultOpenApi,
  )
  final ReviewAdminStarpathRevisionRequestDisciplineEnum discipline;

  @JsonKey(name: r'reason', required: true, includeIfNull: false)
  final String reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReviewAdminStarpathRevisionRequest &&
          other.decision == decision &&
          other.discipline == discipline &&
          other.reason == reason;

  @override
  int get hashCode => decision.hashCode + discipline.hashCode + reason.hashCode;

  factory ReviewAdminStarpathRevisionRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$ReviewAdminStarpathRevisionRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$ReviewAdminStarpathRevisionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum ReviewAdminStarpathRevisionRequestDecisionEnum {
  @JsonValue(r'approved')
  approved(r'approved'),
  @JsonValue(r'changes_requested')
  changesRequested(r'changes_requested'),
  @JsonValue(r'rejected')
  rejected(r'rejected'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ReviewAdminStarpathRevisionRequestDecisionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum ReviewAdminStarpathRevisionRequestDisciplineEnum {
  @JsonValue(r'factual')
  factual(r'factual'),
  @JsonValue(r'compliance')
  compliance(r'compliance'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ReviewAdminStarpathRevisionRequestDisciplineEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
