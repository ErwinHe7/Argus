//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'verify_admin_coven_qualification_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class VerifyAdminCovenQualificationRequest {
  /// Returns a new [VerifyAdminCovenQualificationRequest] instance.
  VerifyAdminCovenQualificationRequest({
    required this.decision,

    required this.effectiveAsOf,

    required this.evidenceClaimIds,

    required this.reason,
  });

  @JsonKey(
    name: r'decision',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        VerifyAdminCovenQualificationRequestDecisionEnum.unknownDefaultOpenApi,
  )
  final VerifyAdminCovenQualificationRequestDecisionEnum decision;

  @JsonKey(name: r'effective_as_of', required: true, includeIfNull: false)
  final DateTime effectiveAsOf;

  @JsonKey(name: r'evidence_claim_ids', required: true, includeIfNull: false)
  final List<String> evidenceClaimIds;

  @JsonKey(name: r'reason', required: true, includeIfNull: false)
  final String reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VerifyAdminCovenQualificationRequest &&
          other.decision == decision &&
          other.effectiveAsOf == effectiveAsOf &&
          other.evidenceClaimIds == evidenceClaimIds &&
          other.reason == reason;

  @override
  int get hashCode =>
      decision.hashCode +
      effectiveAsOf.hashCode +
      evidenceClaimIds.hashCode +
      reason.hashCode;

  factory VerifyAdminCovenQualificationRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$VerifyAdminCovenQualificationRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$VerifyAdminCovenQualificationRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum VerifyAdminCovenQualificationRequestDecisionEnum {
  @JsonValue(r'verified')
  verified(r'verified'),
  @JsonValue(r'rejected')
  rejected(r'rejected'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const VerifyAdminCovenQualificationRequestDecisionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
