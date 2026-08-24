//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_admin_asset_codex200_response_data_inner_revision_payload_any_of2.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2 {
  /// Returns a new [ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2] instance.
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2({
    required this.companyId,

    required this.inclusionRationale,

    required this.limitations,

    required this.summary,
  });

  @JsonKey(name: r'company_id', required: true, includeIfNull: false)
  final String companyId;

  @JsonKey(name: r'inclusion_rationale', required: true, includeIfNull: false)
  final String inclusionRationale;

  @JsonKey(name: r'limitations', required: true, includeIfNull: false)
  final String limitations;

  @JsonKey(name: r'summary', required: true, includeIfNull: false)
  final String summary;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2 &&
          other.companyId == companyId &&
          other.inclusionRationale == inclusionRationale &&
          other.limitations == limitations &&
          other.summary == summary;

  @override
  int get hashCode =>
      companyId.hashCode +
      inclusionRationale.hashCode +
      limitations.hashCode +
      summary.hashCode;

  factory ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2.fromJson(
    Map<String, dynamic> json,
  ) => _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2FromJson(
    json,
  );

  Map<String, dynamic> toJson() =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2ToJson(
        this,
      );

  @override
  String toString() {
    return toJson().toString();
  }
}
