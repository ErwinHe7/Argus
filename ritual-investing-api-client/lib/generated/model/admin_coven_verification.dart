//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'admin_coven_verification.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AdminCovenVerification {
  /// Returns a new [AdminCovenVerification] instance.
  AdminCovenVerification({
    required this.effectiveAsOf,

    required this.evidenceClaimIds,

    required this.id,

    required this.qualificationId,

    required this.status,

    required this.supersedesId,

    required this.verifiedAt,

    required this.verifiedBy,
  });

  @JsonKey(name: r'effective_as_of', required: true, includeIfNull: false)
  final DateTime effectiveAsOf;

  @JsonKey(name: r'evidence_claim_ids', required: true, includeIfNull: false)
  final List<String> evidenceClaimIds;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'qualification_id', required: true, includeIfNull: false)
  final String qualificationId;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AdminCovenVerificationStatusEnum.unknownDefaultOpenApi,
  )
  final AdminCovenVerificationStatusEnum status;

  @JsonKey(name: r'supersedes_id', required: true, includeIfNull: true)
  final String? supersedesId;

  @JsonKey(name: r'verified_at', required: true, includeIfNull: false)
  final DateTime verifiedAt;

  @JsonKey(name: r'verified_by', required: true, includeIfNull: false)
  final String verifiedBy;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminCovenVerification &&
          other.effectiveAsOf == effectiveAsOf &&
          other.evidenceClaimIds == evidenceClaimIds &&
          other.id == id &&
          other.qualificationId == qualificationId &&
          other.status == status &&
          other.supersedesId == supersedesId &&
          other.verifiedAt == verifiedAt &&
          other.verifiedBy == verifiedBy;

  @override
  int get hashCode =>
      effectiveAsOf.hashCode +
      evidenceClaimIds.hashCode +
      id.hashCode +
      qualificationId.hashCode +
      status.hashCode +
      (supersedesId == null ? 0 : supersedesId.hashCode) +
      verifiedAt.hashCode +
      verifiedBy.hashCode;

  factory AdminCovenVerification.fromJson(Map<String, dynamic> json) =>
      _$AdminCovenVerificationFromJson(json);

  Map<String, dynamic> toJson() => _$AdminCovenVerificationToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum AdminCovenVerificationStatusEnum {
  @JsonValue(r'verified')
  verified(r'verified'),
  @JsonValue(r'rejected')
  rejected(r'rejected'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AdminCovenVerificationStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
