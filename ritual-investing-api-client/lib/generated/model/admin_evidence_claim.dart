//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'admin_evidence_claim.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AdminEvidenceClaim {
  /// Returns a new [AdminEvidenceClaim] instance.
  AdminEvidenceClaim({
    required this.claimType,

    required this.id,

    required this.observedAt,

    required this.sourceId,

    required this.status,

    required this.summary,

    required this.uncertainty,
  });

  @JsonKey(name: r'claim_type', required: true, includeIfNull: false)
  final String claimType;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'observed_at', required: true, includeIfNull: true)
  final DateTime? observedAt;

  @JsonKey(name: r'source_id', required: true, includeIfNull: false)
  final String sourceId;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AdminEvidenceClaimStatusEnum.unknownDefaultOpenApi,
  )
  final AdminEvidenceClaimStatusEnum status;

  @JsonKey(name: r'summary', required: true, includeIfNull: false)
  final String summary;

  @JsonKey(name: r'uncertainty', required: true, includeIfNull: false)
  final String uncertainty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminEvidenceClaim &&
          other.claimType == claimType &&
          other.id == id &&
          other.observedAt == observedAt &&
          other.sourceId == sourceId &&
          other.status == status &&
          other.summary == summary &&
          other.uncertainty == uncertainty;

  @override
  int get hashCode =>
      claimType.hashCode +
      id.hashCode +
      (observedAt == null ? 0 : observedAt.hashCode) +
      sourceId.hashCode +
      status.hashCode +
      summary.hashCode +
      uncertainty.hashCode;

  factory AdminEvidenceClaim.fromJson(Map<String, dynamic> json) =>
      _$AdminEvidenceClaimFromJson(json);

  Map<String, dynamic> toJson() => _$AdminEvidenceClaimToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum AdminEvidenceClaimStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'superseded')
  superseded(r'superseded'),
  @JsonValue(r'withdrawn')
  withdrawn(r'withdrawn'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AdminEvidenceClaimStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
