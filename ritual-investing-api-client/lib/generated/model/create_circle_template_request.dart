//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of4_assets_inner.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_circle_template_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateCircleTemplateRequest {
  /// Returns a new [CreateCircleTemplateRequest] instance.
  CreateCircleTemplateRequest({
    this.artMediaId,

    required this.assets,

    required this.creatorId,

    required this.description,

    required this.slug,

    required this.themeCode,

    required this.title,
  });

  @JsonKey(name: r'art_media_id', required: false, includeIfNull: false)
  final String? artMediaId;

  @JsonKey(name: r'assets', required: true, includeIfNull: false)
  final List<
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner
  >
  assets;

  @JsonKey(name: r'creator_id', required: true, includeIfNull: false)
  final String creatorId;

  @JsonKey(name: r'description', required: true, includeIfNull: false)
  final String description;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(name: r'theme_code', required: true, includeIfNull: false)
  final String themeCode;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateCircleTemplateRequest &&
          other.artMediaId == artMediaId &&
          other.assets == assets &&
          other.creatorId == creatorId &&
          other.description == description &&
          other.slug == slug &&
          other.themeCode == themeCode &&
          other.title == title;

  @override
  int get hashCode =>
      (artMediaId == null ? 0 : artMediaId.hashCode) +
      assets.hashCode +
      creatorId.hashCode +
      description.hashCode +
      slug.hashCode +
      themeCode.hashCode +
      title.hashCode;

  factory CreateCircleTemplateRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateCircleTemplateRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateCircleTemplateRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
