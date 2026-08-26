//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of3_assets_inner.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_admin_asset_codex200_response_data_inner_revision_payload_any_of3.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3 {
  /// Returns a new [ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3] instance.
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3({
    this.artMediaId,

    required this.assets,

    required this.curatorLabel,

    required this.description,

    required this.themeCode,

    required this.title,
  });

  @JsonKey(name: r'art_media_id', required: false, includeIfNull: false)
  final String? artMediaId;

  @JsonKey(name: r'assets', required: true, includeIfNull: false)
  final List<
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner
  >
  assets;

  @JsonKey(name: r'curator_label', required: true, includeIfNull: false)
  final String curatorLabel;

  @JsonKey(name: r'description', required: true, includeIfNull: false)
  final String description;

  @JsonKey(name: r'theme_code', required: true, includeIfNull: false)
  final String themeCode;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3 &&
          other.artMediaId == artMediaId &&
          other.assets == assets &&
          other.curatorLabel == curatorLabel &&
          other.description == description &&
          other.themeCode == themeCode &&
          other.title == title;

  @override
  int get hashCode =>
      (artMediaId == null ? 0 : artMediaId.hashCode) +
      assets.hashCode +
      curatorLabel.hashCode +
      description.hashCode +
      themeCode.hashCode +
      title.hashCode;

  factory ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3.fromJson(
    Map<String, dynamic> json,
  ) => _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3FromJson(
    json,
  );

  Map<String, dynamic> toJson() =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3ToJson(
        this,
      );

  @override
  String toString() {
    return toJson().toString();
  }
}
