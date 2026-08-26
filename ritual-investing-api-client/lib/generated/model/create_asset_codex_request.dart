//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of1_risks_inner.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_asset_codex_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateAssetCodexRequest {
  /// Returns a new [CreateAssetCodexRequest] instance.
  CreateAssetCodexRequest({
    required this.appearanceReason,

    required this.assetId,

    required this.evidenceClaimIds,

    required this.limitations,

    required this.metricsAsOf,

    required this.risks,

    required this.slug,

    required this.thesis,
  });

  @JsonKey(name: r'appearance_reason', required: true, includeIfNull: false)
  final String appearanceReason;

  @JsonKey(name: r'asset_id', required: true, includeIfNull: false)
  final String assetId;

  @JsonKey(name: r'evidence_claim_ids', required: true, includeIfNull: false)
  final List<String> evidenceClaimIds;

  @JsonKey(name: r'limitations', required: true, includeIfNull: false)
  final String limitations;

  @JsonKey(name: r'metrics_as_of', required: true, includeIfNull: false)
  final DateTime metricsAsOf;

  @JsonKey(name: r'risks', required: true, includeIfNull: false)
  final List<
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner
  >
  risks;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(name: r'thesis', required: true, includeIfNull: false)
  final String thesis;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateAssetCodexRequest &&
          other.appearanceReason == appearanceReason &&
          other.assetId == assetId &&
          other.evidenceClaimIds == evidenceClaimIds &&
          other.limitations == limitations &&
          other.metricsAsOf == metricsAsOf &&
          other.risks == risks &&
          other.slug == slug &&
          other.thesis == thesis;

  @override
  int get hashCode =>
      appearanceReason.hashCode +
      assetId.hashCode +
      evidenceClaimIds.hashCode +
      limitations.hashCode +
      metricsAsOf.hashCode +
      risks.hashCode +
      slug.hashCode +
      thesis.hashCode;

  factory CreateAssetCodexRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateAssetCodexRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateAssetCodexRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
