//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_admin_evidence_claim_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateAdminEvidenceClaimRequest {
  /// Returns a new [CreateAdminEvidenceClaimRequest] instance.
  CreateAdminEvidenceClaimRequest({
    required this.claimType,

    required this.observedAt,

    required this.sourceId,

    required this.status,

    required this.summary,

    required this.uncertainty,
  });

  @JsonKey(name: r'claim_type', required: true, includeIfNull: false)
  final String claimType;

  @JsonKey(name: r'observed_at', required: true, includeIfNull: true)
  final DateTime? observedAt;

  @JsonKey(name: r'source_id', required: true, includeIfNull: false)
  final String sourceId;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        CreateAdminEvidenceClaimRequestStatusEnum.unknownDefaultOpenApi,
  )
  final CreateAdminEvidenceClaimRequestStatusEnum status;

  @JsonKey(name: r'summary', required: true, includeIfNull: false)
  final String summary;

  @JsonKey(name: r'uncertainty', required: true, includeIfNull: false)
  final String uncertainty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateAdminEvidenceClaimRequest &&
          other.claimType == claimType &&
          other.observedAt == observedAt &&
          other.sourceId == sourceId &&
          other.status == status &&
          other.summary == summary &&
          other.uncertainty == uncertainty;

  @override
  int get hashCode =>
      claimType.hashCode +
      (observedAt == null ? 0 : observedAt.hashCode) +
      sourceId.hashCode +
      status.hashCode +
      summary.hashCode +
      uncertainty.hashCode;

  factory CreateAdminEvidenceClaimRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateAdminEvidenceClaimRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateAdminEvidenceClaimRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CreateAdminEvidenceClaimRequestStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'superseded')
  superseded(r'superseded'),
  @JsonValue(r'withdrawn')
  withdrawn(r'withdrawn'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateAdminEvidenceClaimRequestStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
