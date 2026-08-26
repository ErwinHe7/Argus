//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_admin_asset_codex200_response_data_inner_revision_payload_any_of3_assets_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner {
  /// Returns a new [ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner] instance.
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner({
    required this.assetId,

    required this.note,
  });

  @JsonKey(name: r'asset_id', required: true, includeIfNull: false)
  final String assetId;

  @JsonKey(name: r'note', required: true, includeIfNull: false)
  final String note;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other
              is ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner &&
          other.assetId == assetId &&
          other.note == note;

  @override
  int get hashCode => assetId.hashCode + note.hashCode;

  factory ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInnerFromJson(
        json,
      );

  Map<String, dynamic> toJson() =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInnerToJson(
        this,
      );

  @override
  String toString() {
    return toJson().toString();
  }
}
