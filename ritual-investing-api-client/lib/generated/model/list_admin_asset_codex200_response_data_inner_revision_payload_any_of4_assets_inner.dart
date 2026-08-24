//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_admin_asset_codex200_response_data_inner_revision_payload_any_of4_assets_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner {
  /// Returns a new [ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner] instance.
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner({
    required this.assetId,

    required this.note,

    required this.weightBps,
  });

  @JsonKey(name: r'asset_id', required: true, includeIfNull: false)
  final String assetId;

  @JsonKey(name: r'note', required: true, includeIfNull: false)
  final String note;

  // minimum: 0
  // maximum: 10000
  @JsonKey(name: r'weight_bps', required: true, includeIfNull: false)
  final int weightBps;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other
              is ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner &&
          other.assetId == assetId &&
          other.note == note &&
          other.weightBps == weightBps;

  @override
  int get hashCode => assetId.hashCode + note.hashCode + weightBps.hashCode;

  factory ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInnerFromJson(
        json,
      );

  Map<String, dynamic> toJson() =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInnerToJson(
        this,
      );

  @override
  String toString() {
    return toJson().toString();
  }
}
