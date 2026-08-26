//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_admin_asset_codex200_response_data_inner_revision_payload_any_of_evidence_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner {
  /// Returns a new [ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner] instance.
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner({
    required this.claimId,

    required this.factorLabel,
  });

  @JsonKey(name: r'claim_id', required: true, includeIfNull: false)
  final String claimId;

  @JsonKey(name: r'factor_label', required: true, includeIfNull: false)
  final String factorLabel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other
              is ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner &&
          other.claimId == claimId &&
          other.factorLabel == factorLabel;

  @override
  int get hashCode => claimId.hashCode + factorLabel.hashCode;

  factory ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInnerFromJson(
        json,
      );

  Map<String, dynamic> toJson() =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInnerToJson(
        this,
      );

  @override
  String toString() {
    return toJson().toString();
  }
}
