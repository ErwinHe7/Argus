//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'decide_admin_asset_codex_review_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DecideAdminAssetCodexReviewRequest {
  /// Returns a new [DecideAdminAssetCodexReviewRequest] instance.
  DecideAdminAssetCodexReviewRequest({
    required this.decision,

    required this.reason,
  });

  @JsonKey(
    name: r'decision',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        DecideAdminAssetCodexReviewRequestDecisionEnum.unknownDefaultOpenApi,
  )
  final DecideAdminAssetCodexReviewRequestDecisionEnum decision;

  @JsonKey(name: r'reason', required: true, includeIfNull: false)
  final String reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DecideAdminAssetCodexReviewRequest &&
          other.decision == decision &&
          other.reason == reason;

  @override
  int get hashCode => decision.hashCode + reason.hashCode;

  factory DecideAdminAssetCodexReviewRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$DecideAdminAssetCodexReviewRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$DecideAdminAssetCodexReviewRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum DecideAdminAssetCodexReviewRequestDecisionEnum {
  @JsonValue(r'approved')
  approved(r'approved'),
  @JsonValue(r'changes_requested')
  changesRequested(r'changes_requested'),
  @JsonValue(r'rejected')
  rejected(r'rejected'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DecideAdminAssetCodexReviewRequestDecisionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
