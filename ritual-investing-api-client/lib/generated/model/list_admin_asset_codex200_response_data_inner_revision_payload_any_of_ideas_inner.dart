//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_admin_asset_codex200_response_data_inner_revision_payload_any_of_ideas_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner {
  /// Returns a new [ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner] instance.
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner({
    required this.appearanceReason,

    required this.assetId,

    required this.riskSummary,
  });

  @JsonKey(name: r'appearance_reason', required: true, includeIfNull: false)
  final String appearanceReason;

  @JsonKey(name: r'asset_id', required: true, includeIfNull: false)
  final String assetId;

  @JsonKey(name: r'risk_summary', required: true, includeIfNull: false)
  final String riskSummary;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner &&
          other.appearanceReason == appearanceReason &&
          other.assetId == assetId &&
          other.riskSummary == riskSummary;

  @override
  int get hashCode =>
      appearanceReason.hashCode + assetId.hashCode + riskSummary.hashCode;

  factory ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInnerFromJson(
        json,
      );

  Map<String, dynamic> toJson() =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInnerToJson(
        this,
      );

  @override
  String toString() {
    return toJson().toString();
  }
}
